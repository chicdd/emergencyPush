using EmergencyPushApi.Models;
using Microsoft.EntityFrameworkCore;

namespace EmergencyPushApi.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<사용자> _사용자 => Set<사용자>();
    public DbSet<기기동기화설정> _기기동기화설정 => Set<기기동기화설정>();
    public DbSet<수신메시지내역> _수신메시지내역 => Set<수신메시지내역>();
    public DbSet<발송푸시내역> _발송푸시내역 => Set<발송푸시내역>();
    public DbSet<비상발생내역> _비상발생내역 => Set<비상발생내역>();
    public DbSet<환경설정> _환경설정 => Set<환경설정>();
}
