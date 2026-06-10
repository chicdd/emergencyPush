using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;

namespace EmergencyPushApi.Services;

/// <summary>
/// Firebase Admin SDK 기반 FCM 발송.
/// 서비스 계정 키(JSON) 경로를 appsettings 의 Firebase:ServiceAccountPath 로 받는다.
/// (Firebase Console → 프로젝트 설정 → 서비스 계정 → 새 비공개 키 생성)
/// 키가 없으면 Available=false 가 되고 발송은 건너뛴다(로그만 남김).
/// </summary>
public class FcmService
{
    private readonly ILogger<FcmService> _logger;
    public bool Available { get; }

    public FcmService(IConfiguration config, ILogger<FcmService> logger)
    {
        _logger = logger;
        var configured = config["Firebase:ServiceAccountPath"];
        var candidates = BuildCandidatePaths(configured);
        var path = candidates.FirstOrDefault(File.Exists);

        try
        {
            if (path != null)
            {
                if (FirebaseApp.DefaultInstance == null)
                {
                    using var stream = File.OpenRead(path);
#pragma warning disable CS0618 // FromStream 은 사용 중단 예고 상태이나 현재 정상 동작하며 가장 단순함
                    var credential = GoogleCredential.FromStream(stream);
#pragma warning restore CS0618
                    FirebaseApp.Create(new AppOptions { Credential = credential });
                }
                Available = true;
                _logger.LogInformation("FCM 초기화 완료. 서비스 계정: {Path}", path);
            }
            else
            {
                Available = false;
                _logger.LogWarning(
                    "FCM 서비스 계정 키를 찾을 수 없습니다. 시도한 경로: {Paths}. 푸시는 발송되지 않습니다.",
                    string.Join(" | ", candidates));
            }
        }
        catch (Exception ex)
        {
            Available = false;
            _logger.LogError(ex, "FCM 초기화 실패");
        }
    }

    /// <summary>
    /// 서비스 계정 키 탐색 후보 경로.
    ///  1) 설정값이 절대경로면 그대로, 상대경로면 앱 실행 폴더 기준으로 결합.
    ///  2) 앱 실행 폴더의 기본 파일명(firebase-service-account.json).
    /// → 배포 서버가 바뀌어도 앱 폴더에 키 파일만 있으면 자동으로 찾는다.
    /// </summary>
    private static List<string> BuildCandidatePaths(string? configured)
    {
        var baseDir = AppContext.BaseDirectory;
        var list = new List<string>();

        if (!string.IsNullOrWhiteSpace(configured))
        {
            list.Add(Path.IsPathRooted(configured)
                ? configured
                : Path.Combine(baseDir, configured));
        }

        var fallback = Path.Combine(baseDir, "firebase-service-account.json");
        if (!list.Contains(fallback)) list.Add(fallback);

        return list;
    }

    /// <summary>
    /// 여러 토큰으로 멀티캐스트 발송. (토큰, 성공여부) 목록을 반환해 호출측이 로그를 남기게 한다.
    /// </summary>
    public async Task<IReadOnlyList<(string Token, bool Success, string? Error)>> SendMulticastAsync(
        IReadOnlyList<string> tokens, string title, string body,
        string dataType = "emergency", CancellationToken ct = default)
    {
        var results = new List<(string, bool, string?)>(tokens.Count);
        if (!Available)
        {
            _logger.LogWarning("FCM 미초기화(서비스 계정 키 미로드) — 발송 건너뜀. 토큰 {Count}개", tokens.Count);
            foreach (var t in tokens) results.Add((t, false, "FcmNotInitialized"));
            return results;
        }
        if (tokens.Count == 0) return results;

        // FCM 멀티캐스트는 1회 최대 500개. 청크로 분할.
        const int chunkSize = 500;
        for (var i = 0; i < tokens.Count; i += chunkSize)
        {
            var chunk = tokens.Skip(i).Take(chunkSize).ToList();
            var msg = new MulticastMessage
            {
                Tokens = chunk,
                Notification = new Notification { Title = title, Body = body },
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        Sound = "default",                 // 소리 재생
                        DefaultSound = true,
                        ChannelId = "emergency_channel",   // 앱이 만든 고중요도(소리) 채널
                        Priority = NotificationPriority.MAX,
                        DefaultVibrateTimings = true,
                    }
                },
                Apns = new ApnsConfig
                {
                    // content-available(무음 백그라운드) 제거 — 알림 사운드가 울리도록.
                    Aps = new Aps { Sound = "default" },
                    Headers = new Dictionary<string, string> { ["apns-priority"] = "10" }
                },
                Data = new Dictionary<string, string> { ["type"] = dataType }
            };

            try
            {
                var resp = await FirebaseMessaging.DefaultInstance.SendEachForMulticastAsync(msg, ct);
                for (var j = 0; j < chunk.Count; j++)
                {
                    var r = resp.Responses[j];
                    var error = r.IsSuccess
                        ? null
                        : (r.Exception?.MessagingErrorCode?.ToString()
                           ?? r.Exception?.ErrorCode.ToString() ?? "Unknown");
                    results.Add((chunk[j], r.IsSuccess, error));
                }

                // 실패 사유(에러 코드)를 집계해 로깅 — 토큰 무효/프로젝트 불일치 등 원인 파악용.
                if (resp.FailureCount > 0)
                {
                    var codes = resp.Responses
                        .Where(r => !r.IsSuccess)
                        .Select(r => r.Exception?.MessagingErrorCode?.ToString()
                                     ?? r.Exception?.ErrorCode.ToString() ?? "Unknown")
                        .GroupBy(c => c)
                        .Select(g => $"{g.Key}×{g.Count()}");
                    _logger.LogWarning("FCM 발송 실패 {Fail}/{Total}. 사유: {Codes}",
                        resp.FailureCount, chunk.Count, string.Join(", ", codes));
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "FCM 멀티캐스트 발송 실패(예외)");
                foreach (var t in chunk) results.Add((t, false, "Exception: " + ex.Message));
            }
        }
        return results;
    }
}
