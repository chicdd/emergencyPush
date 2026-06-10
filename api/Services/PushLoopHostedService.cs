using EmergencyPushApi.Data;
using EmergencyPushApi.Models;
using Microsoft.EntityFrameworkCore;

namespace EmergencyPushApi.Services;

/// <summary>
/// 비상 상황이 활성인 동안에만 1초에 1번씩 모든 사용자에게 푸시를 발송하고
/// send_push_log 에 기록한다(스펙 규칙 4·5).
///
/// [부하 최적화] 평상시에는 DB 를 폴링하지 않는다. EmergencySignal 에서 신호가
/// 올 때까지 잠들어 있다가(=DB 호출 0), 비상 시작 시 깨어나 발송 루프를 돈다.
/// 설정값(발송 간격/메시지)은 비상 시작 시 1회만 읽어 캐시한다.
/// 상황 해제(IsActive=false) 시 즉시 멈춘다.
/// </summary>
public class PushLoopHostedService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly FcmService _fcm;
    private readonly EmergencySignal _signal;
    private readonly ILogger<PushLoopHostedService> _logger;

    public PushLoopHostedService(
        IServiceScopeFactory scopeFactory,
        FcmService fcm,
        EmergencySignal signal,
        ILogger<PushLoopHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _fcm = fcm;
        _signal = signal;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("푸시 루프 시작 (FCM 사용 가능: {Available})", _fcm.Available);

        // 프로세스 재시작(IIS 재활용 등) 대비: 시작 시 딱 1번만 DB 에서 활성 비상 복구.
        await RecoverActiveEmergencyAsync(stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            // 평상시: 여기서 잠듦. 비상 신호가 올 때까지 DB 를 전혀 호출하지 않는다.
            await _signal.WaitUntilActiveAsync(stoppingToken);
            if (stoppingToken.IsCancellationRequested) break;

            // 비상 시작: 설정값을 1회만 읽어 캐시.
            var (intervalMs, fallbackMessage) = await LoadIntervalAndMessageAsync(stoppingToken);

            // 활성인 동안 발송 반복. 해제되면 루프를 빠져나가 다시 잠든다.
            while (_signal.IsActive && !stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await SendOnceAsync(_signal.Message ?? fallbackMessage, _signal.TriggeredBy, stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "비상 푸시 발송 중 오류");
                }

                try { await Task.Delay(intervalMs, stoppingToken); }
                catch (TaskCanceledException) { break; }
            }
        }
    }

    private async Task RecoverActiveEmergencyAsync(CancellationToken ct)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var active = await db.EmergencyStates.AsNoTracking()
                .Where(e => e.IsActive)
                .OrderByDescending(e => e.StartedAt)
                .FirstOrDefaultAsync(ct);
            if (active != null)
            {
                _signal.Activate(active.Message, active.TriggeredBy);
                _logger.LogWarning("재시작 후 활성 비상 복구. 트리거: {By}", active.TriggeredBy);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "활성 비상 복구 확인 실패");
        }
    }

    private async Task<(int intervalMs, string message)> LoadIntervalAndMessageAsync(CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var settings = scope.ServiceProvider.GetRequiredService<SettingsService>();
        var intervalMs = await settings.GetIntAsync(SettingKeys.PushIntervalMs, SettingKeys.DefaultPushIntervalMs);
        var message = await settings.GetStringAsync(SettingKeys.PushMessage, SettingKeys.DefaultPushMessage)
                      ?? SettingKeys.DefaultPushMessage;
        return (intervalMs, message);
    }

    /// <summary>한 번 발송: 토큰 보유 사용자 전원에게 푸시 + send_push_log 기록.</summary>
    private async Task SendOnceAsync(string message, string? triggeredBy, CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var users = await db.Users.AsNoTracking()
            .Where(u => u.FirebaseToken != null && u.FirebaseToken != "")
            .Select(u => new { u.Id, Token = u.FirebaseToken! })
            .ToListAsync(ct);

        if (users.Count == 0) return;

        var tokens = users.Select(u => u.Token).ToList();
        await _fcm.SendMulticastAsync(tokens, "비상 상황", message, ct);

        var now = KoreaTime.Now;
        foreach (var u in users)
        {
            db.SendPushLogs.Add(new SendPushLog
            {
                UserId = u.Id,
                Message = message,
                ReceiveId = triggeredBy,
                Date = now
            });
        }
        await db.SaveChangesAsync(ct);

        _logger.LogDebug("비상 푸시 발송: {Total}명", users.Count);
    }
}
