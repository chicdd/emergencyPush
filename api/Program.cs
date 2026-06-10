using EmergencyPushApi.Data;
using EmergencyPushApi.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// ── 데이터베이스 (MSSQL) ─────────────────────────────────
var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? throw new InvalidOperationException(
        "ConnectionStrings:Default 가 설정되지 않았습니다. appsettings.json 을 확인하세요.");

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connectionString));

// ── 서비스 등록 ─────────────────────────────────────────
builder.Services.AddScoped<SettingsService>();
builder.Services.AddScoped<EmergencyService>();
builder.Services.AddSingleton<FcmService>();
builder.Services.AddSingleton<EmergencySignal>();

// 백그라운드: 비상 시 1초마다 푸시 / 무수신 시 count 초기화
builder.Services.AddHostedService<PushLoopHostedService>();
builder.Services.AddHostedService<CountResetHostedService>();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();

// 앱에서 호출하므로 CORS 허용(개발 편의)
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors();
app.UseAuthorization();
app.MapControllers();

// FCM 초기화 상태를 부팅 시 한 번 확인/로깅
app.Services.GetRequiredService<FcmService>();

app.Run();
