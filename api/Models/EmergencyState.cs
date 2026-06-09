using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EmergencyPushApi.Models;

[Table("emergency_state")]
public class EmergencyState
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; }

    /// <summary>트리거가 된 회선/발신 번호</summary>
    [Column("triggered_by")]
    public string? TriggeredBy { get; set; }

    [Column("message")]
    public string? Message { get; set; }

    [Column("started_at")]
    public DateTime StartedAt { get; set; }

    [Column("resolved_at")]
    public DateTime? ResolvedAt { get; set; }

    /// <summary>상황 해제한 사용자 휴대폰번호</summary>
    [Column("resolved_by")]
    public string? ResolvedBy { get; set; }
}
