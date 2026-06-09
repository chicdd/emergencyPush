using EmergencyPushApi.Models;
using Microsoft.EntityFrameworkCore;

namespace EmergencyPushApi.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<DeviceSyncConfig> DeviceSyncConfigs => Set<DeviceSyncConfig>();
    public DbSet<ReceiveMessageLog> ReceiveMessageLogs => Set<ReceiveMessageLog>();
    public DbSet<SendPushLog> SendPushLogs => Set<SendPushLog>();
    public DbSet<EmergencyState> EmergencyStates => Set<EmergencyState>();
    public DbSet<Setting> Settings => Set<Setting>();
}
