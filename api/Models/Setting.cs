using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EmergencyPushApi.Models;

[Table("setting")]
public class Setting
{
    [Key]
    [Column("key")]
    public string Key { get; set; } = string.Empty;

    [Column("value")]
    public string? Value { get; set; }
}
