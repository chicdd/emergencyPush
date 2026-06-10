using EmergencyPushApi.Data;
using EmergencyPushApi.Models;
using Microsoft.EntityFrameworkCore;

namespace EmergencyPushApi.Services;

/// <summary>
/// 메시지 수신 등록 + 비상 트리거 판정.
///
/// [다중 발신자 처리 설계]
/// 단순히 device_sync_configs.count 하나만 쓰면, 서로 다른 발신번호에서 온
/// 메시지가 한 카운터에 섞여 오탐/누락이 생긴다. 그래서 실제 트리거 판정은
/// receive_message_log 의 타임스탬프로 "(모니터링 회선, 발신번호) 쌍" 별
/// 슬라이딩 1분 윈도우 카운트를 계산한다.
///   - 발신번호(send_id)를 아는 경우(안드로이드 SMS 포워딩): 발신자별로 독립 집계.
///     → A 발신자가 쌓이는 도중 B 발신자가 와도 서로 영향 없음. 각자 1분 내 10건
///       도달 시 트리거.
///   - 발신번호를 모르는 경우(iOS 단축어 ping): 해당 회선 전체를 한 묶음으로 집계.
/// device_sync_configs.count 는 표시/단순집계용 누적값으로 함께 유지하며,
/// 10분간 메시지가 없으면 0으로 초기화된다(스펙 규칙 3).
/// </summary>
public class EmergencyService
{
    private readonly AppDbContext _db;
    private readonly SettingsService _settings;
    private readonly EmergencySignal _signal;
    private readonly ILogger<EmergencyService> _logger;

    public EmergencyService(
        AppDbContext db, SettingsService settings, EmergencySignal signal, ILogger<EmergencyService> logger)
    {
        _db = db;
        _settings = settings;
        _signal = signal;
        _logger = logger;
    }

    /// <summary>
    /// 메시지 수신을 등록하고 비상 트리거를 판정한다.
    /// </summary>
    /// <param name="receiveId">모니터링 단말(받은사람) 회선 번호</param>
    /// <param name="sendId">발신번호. iOS ping 등 모르면 null</param>
    /// <param name="message">메시지 본문(있으면)</param>
    /// <param name="markMaster">이 회선을 master 로 표시할지(iOS ping 설정 시 true)</param>
    public async Task<MessageResult> RegisterIncomingAsync(
        string receiveId, string? sendId, string? message, bool markMaster)
    {
        var now = KoreaTime.Now;

        var threshold = await _settings.GetIntAsync(SettingKeys.TriggerThreshold, SettingKeys.DefaultThreshold);
        var windowSec = await _settings.GetIntAsync(SettingKeys.TriggerWindowSec, SettingKeys.DefaultWindowSec);
        var resetMin = await _settings.GetIntAsync(SettingKeys.CountResetMinutes, SettingKeys.DefaultResetMinutes);

        // 1) 모니터링 설정(config) 로드/생성
        var config = await _db.DeviceSyncConfigs.FirstOrDefaultAsync(c => c.Id == receiveId);
        if (config == null)
        {
            config = new DeviceSyncConfig { Id = receiveId, IsMaster = markMaster, Count = 0 };
            _db.DeviceSyncConfigs.Add(config);
        }
        else if (markMaster && !config.IsMaster)
        {
            config.IsMaster = true;
        }

        // is_master 가 아니면 로그만 남기고 트리거 판정은 하지 않는다(스펙: master 회선만 감지).
        // 단, 수신 사실은 항상 기록.
        _db.ReceiveMessageLogs.Add(new ReceiveMessageLog
        {
            SendId = sendId ?? receiveId,
            ReceiveId = receiveId,
            Message = message,
            Date = now
        });

        if (!config.IsMaster)
        {
            await _db.SaveChangesAsync();
            return new MessageResult(config.Count, false, await IsEmergencyActiveAsync());
        }

        // 2) 10분간 무수신이면 누적 count 초기화 (규칙 3)
        if (config.LastMessageAt.HasValue && (now - config.LastMessageAt.Value).TotalMinutes > resetMin)
        {
            config.Count = 0;
            config.WindowStartAt = null;
        }

        // 3) 표시용 누적 count: 1분 윈도우 단위로 증가
        if (config.WindowStartAt == null || (now - config.WindowStartAt.Value).TotalSeconds > windowSec)
        {
            config.WindowStartAt = now;
            config.Count = 1;
        }
        else
        {
            config.Count += 1;
        }
        config.LastMessageAt = now;

        await _db.SaveChangesAsync(); // 방금 로그가 윈도우 집계에 포함되도록 먼저 저장

        // 4) 권위 있는 트리거 판정: 슬라이딩 1분 윈도우, (회선, 발신자)별 집계
        var windowStart = now.AddSeconds(-windowSec);
        var q = _db.ReceiveMessageLogs.AsNoTracking()
            .Where(l => l.ReceiveId == receiveId && l.Date >= windowStart);
        if (!string.IsNullOrEmpty(sendId))
            q = q.Where(l => l.SendId == sendId);

        var windowCount = await q.CountAsync();

        bool triggered = false;
        if (windowCount >= threshold)
        {
            triggered = await StartEmergencyIfNeededAsync(sendId ?? receiveId, message, now);
        }

        return new MessageResult(config.Count, triggered, await IsEmergencyActiveAsync());
    }

    /// <summary>활성 비상이 없으면 새로 시작. 이미 활성이면 false.</summary>
    private async Task<bool> StartEmergencyIfNeededAsync(string triggeredBy, string? message, DateTime now)
    {
        var alreadyActive = await _db.EmergencyStates.AnyAsync(e => e.IsActive);
        if (alreadyActive) return false;

        var pushMessage = await _settings.GetStringAsync(SettingKeys.PushMessage, SettingKeys.DefaultPushMessage);
        var finalMessage = string.IsNullOrWhiteSpace(message) ? pushMessage : message;

        _db.EmergencyStates.Add(new EmergencyState
        {
            IsActive = true,
            TriggeredBy = triggeredBy,
            Message = finalMessage,
            StartedAt = now
        });
        await _db.SaveChangesAsync();

        // 폴링 없이 푸시 루프를 즉시 깨운다.
        _signal.Activate(finalMessage, triggeredBy);

        _logger.LogWarning("비상 상황 발생. 트리거: {TriggeredBy}", triggeredBy);
        return true;
    }

    private Task<bool> IsEmergencyActiveAsync() => _db.EmergencyStates.AnyAsync(e => e.IsActive);

    /// <summary>모든 활성 비상을 해제한다(상황 확인/상황 해제). 푸시 루프가 즉시 멈춘다.</summary>
    public async Task<int> ResolveAllAsync(string? resolvedBy)
    {
        var now = KoreaTime.Now;
        var actives = await _db.EmergencyStates.Where(e => e.IsActive).ToListAsync();
        foreach (var e in actives)
        {
            e.IsActive = false;
            e.ResolvedAt = now;
            e.ResolvedBy = resolvedBy;
        }
        if (actives.Count > 0)
        {
            await _db.SaveChangesAsync();
            _signal.Deactivate(); // 푸시 루프 즉시 정지
            _logger.LogInformation("비상 상황 {Count}건 해제. 해제자: {By}", actives.Count, resolvedBy ?? "(미상)");
        }
        return actives.Count;
    }

    public async Task<EmergencyStatusResponse> GetStatusAsync()
    {
        var active = await _db.EmergencyStates.AsNoTracking()
            .Where(e => e.IsActive)
            .OrderByDescending(e => e.StartedAt)
            .FirstOrDefaultAsync();

        if (active != null)
            return new EmergencyStatusResponse(true, active.TriggeredBy, active.Message, active.StartedAt);

        return new EmergencyStatusResponse(false, null, null, null);
    }
}
