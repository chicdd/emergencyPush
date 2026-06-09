using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EmergencyPushApi.Models;

[Table("send_push_log")]
public class SendPushLog
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    /// <summary>푸시를 받은 사용자 휴대폰번호</summary>
    [Column("user_id")]
    public string? UserId { get; set; }

    [Column("message")]
    public string? Message { get; set; }

    /// <summary>비상 트리거가 된 모니터링 회선 번호</summary>
    [Column("receive_id")]
    public string? ReceiveId { get; set; }

    [Column("date")]
    public DateTime Date { get; set; }
}
