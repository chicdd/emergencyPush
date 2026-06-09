using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EmergencyPushApi.Models;

[Table("receive_message_log")]
public class ReceiveMessageLog
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    /// <summary>보낸사람 (발신 SMS 번호)</summary>
    [Column("send_id")]
    public string? SendId { get; set; }

    /// <summary>받은사람 (모니터링 단말 회선 번호)</summary>
    [Column("receive_id")]
    public string ReceiveId { get; set; } = string.Empty;

    [Column("message")]
    public string? Message { get; set; }

    [Column("date")]
    public DateTime Date { get; set; }
}
