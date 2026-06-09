using EmergencyPushApi.Data;
using Microsoft.EntityFrameworkCore;

namespace EmergencyPushApi.Services;

/// <summary>
/// 주기적으로(기본 60초) 마지막 수신 후 일정 시간(기본 10분) 변화가 없는
/// device_sync_configs 의 count 를 0 으로 초기화한다(스펙 규칙 3).
/// (메시지 수신 경로에서도 초기화하지만, 메시지가 더 안 오는 경우를 위해 별도 보장.)
/// </summary>
public class CountResetHostedService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<CountResetHostedService> _logger;

    public CountResetHostedService(IServiceScopeFactory scopeFactory, ILogger<CountResetHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                var settings = scope.ServiceProvider.GetRequiredService<SettingsService>();

                var resetMin = await settings.GetIntAsync(SettingKeys.CountResetMinutes, SettingKeys.DefaultResetMinutes);
                var cutoff = DateTime.UtcNow.AddMinutes(-resetMin);

                var stale = await db.DeviceSyncConfigs
                    .Where(c => c.Count != 0 && c.LastMessageAt != null && c.LastMessageAt < cutoff)
                    .ToListAsync(stoppingToken);

                foreach (var c in stale)
                {
                    c.Count = 0;
                    c.WindowStartAt = null;
                }
                if (stale.Count > 0)
                {
                    await db.SaveChangesAsync(stoppingToken);
                    _logger.LogDebug("count 초기화 {Count}건", stale.Count);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "count 초기화 작업 오류");
            }

            try { await Task.Delay(TimeSpan.FromSeconds(60), stoppingToken); }
            catch (TaskCanceledException) { break; }
        }
    }
}
