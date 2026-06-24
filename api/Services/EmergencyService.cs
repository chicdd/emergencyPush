using EmergencyPushApi.Data;
using EmergencyPushApi.Models;
using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json.Linq;

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
        string? receiveId, string? sendId, string? message, bool markMaster)
    {
        var now = KoreaTime.Now;

        var threshold = await _settings.GetIntAsync(SettingKeys.TriggerThreshold, SettingKeys.DefaultThreshold);
        var windowSec = await _settings.GetIntAsync(SettingKeys.TriggerWindowSec, SettingKeys.DefaultWindowSec);
        var resetMin = await _settings.GetIntAsync(SettingKeys.CountResetMinutes, SettingKeys.DefaultResetMinutes);
        var 상황확인여부 =  await _settings.GetIntAsync(SettingKeys.상황확인여부, SettingKeys.Default상황확인여부);
       

        // 1) 모니터링 설정(config) 로드/생성
        var config = await _db._기기동기화설정.FirstOrDefaultAsync(c => c.Id == receiveId);
        if (config == null)
        {
            config = new 기기동기화설정 { Id = NormalizePhoneNumber(receiveId), 메인여부 = markMaster, 메시지큐 = 0 };
            _db._기기동기화설정.Add(config);
        }
        else if (markMaster && !config.메인여부)
        {
            config.메인여부 = true;
        }


        // is_master 가 아니면 로그만 남기고 트리거 판정은 하지 않는다(스펙: master 회선만 감지).
        // 단, 수신 사실은 항상 기록.
        _db._수신메시지내역.Add(new 수신메시지내역
        {
            발신휴대폰번호 = sendId ?? "알수없는 발신자",
            수신휴대폰번호 = receiveId ?? "알수없는 수신자",
            메시지내용 = message,
            수신시각 = now
        });



        if (!config.메인여부 || 상황확인여부 == 1)
        {
            await _db.SaveChangesAsync();
            return new MessageResult(config.메시지큐, false, await IsEmergencyActiveAsync());
        }

        // 2) 10분간 무수신이면 누적 count 초기화 (규칙 3)
        if (config.최종메시지시각.HasValue && (now - config.최종메시지시각.Value).TotalMinutes > resetMin)
        {
            config.메시지큐 = 0;
            config.큐시작시각 = null;
        }

        // 3) 표시용 누적 count: 1분 윈도우 단위로 증가
        if (config.큐시작시각 == null || (now - config.큐시작시각.Value).TotalSeconds > windowSec)
        {
            config.큐시작시각 = now;
            config.메시지큐 = 1;
        }
        else
        {
            config.메시지큐 += 1;
        }
        config.최종메시지시각 = now;

        await _db.SaveChangesAsync(); // 방금 로그가 윈도우 집계에 포함되도록 먼저 저장

        // 4) 권위 있는 트리거 판정: 슬라이딩 1분 윈도우, (회선, 발신자)별 집계
        var windowStart = now.AddSeconds(-windowSec);
        var q = _db._수신메시지내역.AsNoTracking()
            .Where(l => l.수신휴대폰번호 == receiveId && l.수신시각 >= windowStart);
        if (!string.IsNullOrEmpty(sendId))
            q = q.Where(l => l.발신휴대폰번호 == sendId);

        var windowCount = await q.CountAsync();

        bool triggered = false;
        if (windowCount >= threshold)
        {
            triggered = await StartEmergencyIfNeededAsync(sendId ?? receiveId, message, now);
        }

        return new MessageResult(config.메시지큐, triggered, await IsEmergencyActiveAsync());
    }

    /// <summary>활성 비상이 없으면 새로 시작. 이미 활성이면 false.</summary>
    private async Task<bool> StartEmergencyIfNeededAsync(string 최초휴대폰번호, string? 메시지내용, DateTime now)
    {
        var 상황여부 = await _db._비상발생내역.AnyAsync(e => e.상황여부);
        if (상황여부) return false;

        var 푸시메시지 = await _settings.GetStringAsync(SettingKeys.PushMessage, SettingKeys.DefaultPushMessage);
        var 최종메시지 = string.IsNullOrWhiteSpace(메시지내용) ? 푸시메시지 : 메시지내용;

        _db._비상발생내역.Add(new 비상발생내역
        {
            상황여부 = true,
            최초휴대폰번호 = 최초휴대폰번호,
            메시지내용 = 최종메시지,
            발생시각 = now
        });
        await _db.SaveChangesAsync();

        // 폴링 없이 푸시 루프를 즉시 깨운다.
        _signal.Activate(최종메시지, 최초휴대폰번호);

        _logger.LogWarning("비상 상황 발생. 트리거: {최초휴대폰번호}", 최초휴대폰번호);
        return true;
    }

    //비상상황 활성 여부
    private Task<bool> IsEmergencyActiveAsync() => _db._비상발생내역.AnyAsync(e => e.상황여부);

    /// <summary>
    /// 모든 활성 비상을 해제한다(상황 확인/상황 해제). 푸시 루프가 즉시 멈춘다.
    /// 동시에 [환경설정].상황확인여부 를 1로 세워, 재무장(<see cref="ArmAsync"/>) 전까지
    /// RegisterIncomingAsync 가 새 비상을 재트리거하지 않도록 잠근다.
    /// </summary>
    public async Task<int> ResolveAllAsync(string? resolvedBy)
    {
        var now = KoreaTime.Now;
        var actives = await _db._비상발생내역.Where(e => e.상황여부).ToListAsync();
        foreach (var e in actives)
        {
            e.상황여부 = false;
            e.해제시각 = now;
            e.해제휴대폰번호 = resolvedBy;
        }

        if (actives.Count > 0)
        {
            await SetAcknowledgedAsync(true);
            await _db.SaveChangesAsync();
            _signal.Deactivate(); // 푸시 루프 즉시 정지
            _logger.LogInformation("비상 상황 {Count}건 해제. 해제자: {By}", actives.Count, resolvedBy ?? "(미상)");
        }
        return actives.Count;
    }
    


    /// <summary>
    /// 재무장. [환경설정].상황확인여부 를 0으로 되돌려, 다음 비상을 다시 감지할 수 있게 한다.
    /// </summary>
    public async Task ArmAsync(string? armedBy)
    {
        await SetAcknowledgedAsync(false);
        await _db.SaveChangesAsync();
        _logger.LogInformation("비상 감지 재무장(Arm). 처리자: {By}", armedBy ?? "(미상)");
    }

    


    /// <summary>[환경설정].상황확인여부 값을 세팅(행이 없으면 생성). SaveChanges 는 호출자가 한다.</summary>
    private async Task SetAcknowledgedAsync(bool acknowledged)
    {
        var setting = await _db._환경설정.FirstOrDefaultAsync(e => e.키 == SettingKeys.상황확인여부);
        if (setting == null)
        {
            setting = new 환경설정 { 키 = SettingKeys.상황확인여부 };
            _db._환경설정.Add(setting);
        }
        setting.값 = acknowledged ? "1" : "0";
    }

    public async Task<EmergencyStatusResponse> GetStatusAsync()
    {
        var active = await _db._비상발생내역.AsNoTracking()
            .Where(e => e.상황여부)
            .OrderByDescending(e => e.발생시각)
            .FirstOrDefaultAsync();

        var acknowledged = await _settings.GetIntAsync(SettingKeys.상황확인여부, SettingKeys.Default상황확인여부) == 1;

        if (active != null)
            return new EmergencyStatusResponse(true, active.최초휴대폰번호, active.메시지내용, active.발생시각, acknowledged);

        return new EmergencyStatusResponse(false, null, null, null, acknowledged);
    }


    // 전화번호 정규화 유틸리티 메서드 ( +8210 으로 들어와도 010 으로 변환, 특수문자 제거 )
    private string NormalizePhoneNumber(string phone)
    {
        if (string.IsNullOrWhiteSpace(phone))
            return phone;

        // 1. 숫자와 '+' 기호만 남기고 모든 특수문자(공백, 하이픈 등) 제거
        var cleaned = new string(phone.Where(c => char.IsDigit(c) || c == '+').ToArray());

        // 2. 국가번호(+82)를 국내 식별번호(0)로 변환
        if (cleaned.StartsWith("+82"))
        {
            cleaned = "0" + cleaned.Substring(3);
        }
        // (옵션) '+' 없이 '8210'으로 들어오는 예외 케이스 처리
        else if (cleaned.StartsWith("8210"))
        {
            cleaned = "0" + cleaned.Substring(2);
        }

        return cleaned;
    }
}
