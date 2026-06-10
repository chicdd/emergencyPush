using EmergencyPushApi.Data;
using Microsoft.EntityFrameworkCore;

namespace EmergencyPushApi.Services;

/// <summary>
/// 마지막 수신 후 일정 시간(기본 10분) 변화가 없는 device_sync_configs 의 count 를
/// 0 으로 초기화한다(스펙 규칙 3). 메시지 수신 경로에서도 초기화하지만, 메시지가
/// 더 안 오는 경우를 위해 별도 보장.
///
/// [부하 최적화]
///  - 주기를 5분으로(트리거 판정은 로그 기반 슬라이딩 윈도우라 count 는 표시용이므로 느려도 무방).
///  - 행을 메모리로 로드하지 않고 set-based UPDATE(ExecuteUpdate) 한 번으로 처리.
/// </summary>
public class CountResetHostedService : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(5);

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
                var cutoff = KoreaTime.Now.AddMinutes(-resetMin);

                // 행 로드 없이 한 번의 UPDATE 로 초기화.
                var affected = await db.DeviceSyncConfigs
                    .Where(c => c.Count != 0 && c.LastMessageAt != null && c.LastMessageAt < cutoff)
                    .ExecuteUpdateAsync(s => s
                        .SetProperty(c => c.Count, 0)
                        .SetProperty(c => c.WindowStartAt, (DateTime?)null), stoppingToken);

                if (affected > 0)
                    _logger.LogDebug("count 초기화 {Count}건", affected);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "count 초기화 작업 오류");
            }

            try { await Task.Delay(Interval, stoppingToken); }
            catch (TaskCanceledException) { break; }
        }
    }
}
