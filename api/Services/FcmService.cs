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
        var path = config["Firebase:ServiceAccountPath"];

        try
        {
            if (!string.IsNullOrWhiteSpace(path) && File.Exists(path))
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
                    "FCM 서비스 계정 키가 없습니다(Firebase:ServiceAccountPath={Path}). 푸시는 발송되지 않습니다.",
                    path ?? "(미설정)");
            }
        }
        catch (Exception ex)
        {
            Available = false;
            _logger.LogError(ex, "FCM 초기화 실패");
        }
    }

    /// <summary>
    /// 여러 토큰으로 멀티캐스트 발송. (토큰, 성공여부) 목록을 반환해 호출측이 로그를 남기게 한다.
    /// </summary>
    public async Task<IReadOnlyList<(string Token, bool Success)>> SendMulticastAsync(
        IReadOnlyList<string> tokens, string title, string body, CancellationToken ct = default)
    {
        var results = new List<(string, bool)>(tokens.Count);
        if (!Available || tokens.Count == 0)
        {
            foreach (var t in tokens) results.Add((t, false));
            return results;
        }

        // FCM 멀티캐스트는 1회 최대 500개. 청크로 분할.
        const int chunkSize = 500;
        for (var i = 0; i < tokens.Count; i += chunkSize)
        {
            var chunk = tokens.Skip(i).Take(chunkSize).ToList();
            var msg = new MulticastMessage
            {
                Tokens = chunk,
                Notification = new Notification { Title = title, Body = body },
                Android = new AndroidConfig { Priority = Priority.High },
                Apns = new ApnsConfig
                {
                    Headers = new Dictionary<string, string>
                    {
                        ["apns-priority"] = "10",       // 즉시 전달 (기본값 5는 지연/무음 처리 가능)
                        ["apns-push-type"] = "alert",   // 알림 배너+소리 명시
                    },
                    Aps = new Aps { Sound = "default" }
                },
                Data = new Dictionary<string, string> { ["type"] = "emergency" }
            };

            try
            {
                var resp = await FirebaseMessaging.DefaultInstance.SendEachForMulticastAsync(msg, ct);
                for (var j = 0; j < chunk.Count; j++)
                    results.Add((chunk[j], resp.Responses[j].IsSuccess));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "FCM 멀티캐스트 발송 실패");
                foreach (var t in chunk) results.Add((t, false));
            }
        }
        return results;
    }
}
