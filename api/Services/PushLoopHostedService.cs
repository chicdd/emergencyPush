using EmergencyPushApi.Data;
using EmergencyPushApi.Models;
using Microsoft.EntityFrameworkCore;

namespace EmergencyPushApi.Services;

/// <summary>
/// 비상 상황이 활성인 동안 1초에 1번씩 모든 사용자에게 푸시를 발송하고
/// send_push_log 에 기록한다. 상황 해제 시 즉시 멈춘다(스펙 규칙 4·5).
/// </summary>
public class PushLoopHostedService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly FcmService _fcm;
    private readonly ILogger<PushLoopHostedService> _logger;

    public PushLoopHostedService(
        IServiceScopeFactory scopeFactory, FcmService fcm, ILogger<PushLoopHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _fcm = fcm;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("푸시 루프 시작 (FCM 사용 가능: {Available})", _fcm.Available);

        while (!stoppingToken.IsCancellationRequested)
        {
            var intervalMs = SettingKeys.DefaultPushIntervalMs;
            try
            {
                intervalMs = await TickAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "푸시 루프 처리 중 오류");
            }

            try
            {
                await Task.Delay(intervalMs, stoppingToken);
            }
            catch (TaskCanceledException) { break; }
        }
    }

    /// <summary>한 틱: 활성 비상이 있으면 1회 발송. 다음 간격(ms)을 반환.</summary>
    private async Task<int> TickAsync(CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var settings = scope.ServiceProvider.GetRequiredService<SettingsService>();

        var intervalMs = await settings.GetIntAsync(SettingKeys.PushIntervalMs, SettingKeys.DefaultPushIntervalMs);

        var active = await db.EmergencyStates.AsNoTracking()
            .Where(e => e.IsActive)
            .OrderByDescending(e => e.StartedAt)
            .FirstOrDefaultAsync(ct);

        if (active == null) return intervalMs; // 비상 아님 → 발송 없음

        var message = string.IsNullOrWhiteSpace(active.Message)
            ? await settings.GetStringAsync(SettingKeys.PushMessage, SettingKeys.DefaultPushMessage)
            : active.Message;
        message ??= SettingKeys.DefaultPushMessage;

        // 토큰 보유 사용자 조회
        var users = await db.Users.AsNoTracking()
            .Where(u => u.FirebaseToken != null && u.FirebaseToken != "")
            .Select(u => new { u.Id, Token = u.FirebaseToken! })
            .ToListAsync(ct);

        if (users.Count == 0) return intervalMs;

        var tokens = users.Select(u => u.Token).ToList();
        var sendResults = await _fcm.SendMulticastAsync(tokens, "비상 상황", message, ct);
        var successByToken = sendResults.ToDictionary(r => r.Token, r => r.Success);

        var now = DateTime.UtcNow;
        foreach (var u in users)
        {
            db.SendPushLogs.Add(new SendPushLog
            {
                UserId = u.Id,
                Message = message,
                ReceiveId = active.TriggeredBy,
                Date = now
            });
        }
        await db.SaveChangesAsync(ct);

        var ok = successByToken.Count(kv => kv.Value);
        _logger.LogDebug("비상 푸시 발송: {Ok}/{Total}", ok, users.Count);

        return intervalMs;
    }
}
