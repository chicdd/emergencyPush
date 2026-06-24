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


    // 5분마다 루프가 돌므로, 12번째 도는 순간(5분 * 12 = 60분)이 1시간이 됩니다.
    private const int PushCheckTicks = 12;

    public CountResetHostedService(IServiceScopeFactory scopeFactory, ILogger<CountResetHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        int loopCount = 0;
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
                var affected = await db._기기동기화설정
                    .Where(c => c.메시지큐 != 0 && c.최종메시지시각 != null && c.최종메시지시각 < cutoff)
                    .ExecuteUpdateAsync(s => s
                        .SetProperty(c => c.메시지큐, 0)
                        .SetProperty(c => c.큐시작시각, (DateTime?)null), stoppingToken);

                if (affected > 0)
                    _logger.LogDebug("count 초기화 {Count}건", affected);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "count 초기화 작업 오류");
            }

            // --- 2. [이식된 로직] 1시간마다 상황 확인 체크 후 푸시 발송 ---
            loopCount++;
            if (loopCount >= PushCheckTicks)
            {
                loopCount = 0; // 1시간이 되었으므로 카운터 초기화

                try
                {
                    using var scope = _scopeFactory.CreateScope();
                    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                    var fcm = scope.ServiceProvider.GetRequiredService<FcmService>(); // 프로젝트의 실제 FCM 서비스 클래스명 확인 필요

                    // 1. 환경설정에서 상황확인여부 조회
                    var setting = await db._환경설정.FirstOrDefaultAsync(e => e.키 == SettingKeys.상황확인여부, stoppingToken);

                    // 2. 상황확인여부가 "1"인 경우에만 푸시 발송 프로세스 진행
                    if (setting != null && setting.값 == "1")
                    {
                        // FirebaseToken이 유효한 사용자 목록 조회
                        var users = await db._사용자.AsNoTracking()
                            .Where(u => u.FirebaseToken != null && u.FirebaseToken != "")
                            .Select(u => new { Token = u.FirebaseToken! })
                            .ToListAsync(stoppingToken);

                        var tokens = users.Select(u => u.Token).ToList();

                        if (tokens.Count > 0)
                        {
                            // 대상자들에게 일괄 푸시 발송
                            await fcm.SendMulticastAsync(
                                tokens,
                                "상황 복구 요청",
                                "경계가 아직 되지 않았습니다. 실행화면의 상황복구 버튼을 눌러주세요",
                                dataType: "test",
                                ct: stoppingToken
                            );
                            _logger.LogInformation("경계 상태 미복구 감지: 사용자 {Count}명에게 복구 요청 푸시를 발송했습니다.", tokens.Count);
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "1시간 주기 상황 확인 및 푸시 발송 중 오류 발생");
                }
            }

            // 다음 5분 대기
            try { await Task.Delay(Interval, stoppingToken); }
            catch (TaskCanceledException) { break; }
        }
    }

}
