using EmergencyPushApi.Data;
using Microsoft.EntityFrameworkCore;

namespace EmergencyPushApi.Services;

/// <summary>setting 테이블 기반 런타임 설정 조회 (없으면 기본값).</summary>
public class SettingsService
{
    private readonly AppDbContext _db;

    public SettingsService(AppDbContext db) => _db = db;

    public async Task<string?> GetStringAsync(string key, string? fallback = null)
    {
        var s = await _db.Settings.AsNoTracking().FirstOrDefaultAsync(x => x.Key == key);
        return s?.Value ?? fallback;
    }

    public async Task<int> GetIntAsync(string key, int fallback)
    {
        var v = await GetStringAsync(key);
        return int.TryParse(v, out var n) ? n : fallback;
    }
}

/// <summary>설정 키 상수 + 기본값.</summary>
public static class SettingKeys
{
    public const string TriggerThreshold = "trigger_threshold";   // 기본 10
    public const string TriggerWindowSec = "trigger_window_sec";  // 기본 60
    public const string CountResetMinutes = "count_reset_minutes"; // 기본 10
    public const string PushIntervalMs = "push_interval_ms";      // 기본 1000
    public const string PushMessage = "push_message";

    public const int DefaultThreshold = 10;
    public const int DefaultWindowSec = 60;
    public const int DefaultResetMinutes = 10;
    public const int DefaultPushIntervalMs = 1000;
    public const string DefaultPushMessage = "[비상] 캡스 보라매 신호 미상승 상황이 감지되었습니다. 즉시 확인하세요.";
}
