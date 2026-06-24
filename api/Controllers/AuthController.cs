using EmergencyPushApi.Data;
using EmergencyPushApi.Models;
using EmergencyPushApi.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EmergencyPushApi.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _db;

    public AuthController(AppDbContext db) => _db = db;

    /// <summary>
    /// 인증 화면에서 호출. 휴대폰번호 + FCM 토큰을 user 테이블에 upsert 한다.
    /// (비밀번호 01579# 검증은 앱 클라이언트에서 수행)
    /// </summary>
    [HttpPost("register")]
    public async Task<IActionResult> 유저등록([FromBody] RegisterRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Phone))
            return BadRequest(new { message = "휴대폰번호가 필요합니다." });

        var now = KoreaTime.Now;
        var user = await _db._사용자.FirstOrDefaultAsync(u => u.휴대폰번호 == req.Phone);
        if (user == null)
        {
            user = new 사용자
            {
                휴대폰번호 = req.Phone,
                FirebaseToken = req.FirebaseToken,
                최근접속시각 = now,
                등록시각 = now
            };
            _db._사용자.Add(user);
        }
        else
        {
            if (!string.IsNullOrWhiteSpace(req.FirebaseToken))
                user.FirebaseToken = req.FirebaseToken;
            user.최근접속시각 = now;
        }

        await _db.SaveChangesAsync();
        return Ok(new { message = "등록 완료", phone = user.휴대폰번호 });
    }

    /// <summary>
    /// 계정 삭제. 휴대폰번호로 식별되는 사용자 레코드를 영구 삭제한다.
    /// (App Store 가이드라인 5.1.1(v) 계정 삭제 요구사항)
    /// </summary>
    [HttpPost("delete")]
    public async Task<IActionResult> Delete([FromBody] DeleteAccountRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Phone))
            return BadRequest(new { message = "휴대폰번호가 필요합니다." });

        var users = await _db._사용자.Where(u => u.휴대폰번호 == req.Phone).ToListAsync();
        if (users.Count == 0)
            return NotFound(new { message = "해당 사용자를 찾을 수 없습니다." });

        _db._사용자.RemoveRange(users);
        await _db.SaveChangesAsync();
        return Ok(new { message = "계정이 삭제되었습니다.", phone = req.Phone });
    }
}
