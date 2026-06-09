using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EmergencyPushApi.Models;

[Table("device_sync_configs")]
public class DeviceSyncConfig
{
    /// <summary>휴대폰번호 (모니터링 대상 회선)</summary>
    [Key]
    [Column("id")]
    public string Id { get; set; } = string.Empty;

    [Column("is_master")]
    public bool IsMaster { get; set; }

    [Column("count")]
    public int Count { get; set; }

    /// <summary>현재 1분 카운팅 윈도우 시작 시각 (UTC)</summary>
    [Column("window_start_at")]
    public DateTime? WindowStartAt { get; set; }

    /// <summary>마지막 메시지 수신 시각 (UTC)</summary>
    [Column("last_message_at")]
    public DateTime? LastMessageAt { get; set; }
}
