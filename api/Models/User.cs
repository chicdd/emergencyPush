using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EmergencyPushApi.Models;

[Table("user")]
public class User
{
    [Key]
    [Column("seq")]
    public int Seq { get; set; }

    /// <summary>휴대폰번호 (로그인 식별자)</summary>
    [Column("id")]
    public string Id { get; set; } = string.Empty;

    [Column("firebase_token")]
    public string? FirebaseToken { get; set; }

    [Column("recent_date")]
    public DateTime? RecentDate { get; set; }

    [Column("registration_date")]
    public DateTime RegistrationDate { get; set; }
}
