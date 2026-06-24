using EmergencyPushApi.Data;
using EmergencyPushApi.Models;
using EmergencyPushApi.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.EntityFrameworkCore;

namespace EmergencyPushApi.Controllers;

[ApiController]
[Route("api/device")]
public class DeviceController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly EmergencyService _emergency;

    public DeviceController(AppDbContext db, EmergencyService emergency)
    {
        _db = db;
        _emergency = emergency;
    }

    /// <summary>
    /// iOS 단축어/모니터링 hook 용 ping(POST). 메시지 수신 시 이 URL 을 호출한다.
    /// 해당 회선을 master 로 표시하고 count 를 증가시키며 트리거를 판정한다.
    /// 회선 식별은 경로 파라미터로, 메시지는 JSON 본문({"message":"..."})으로 받는다.
    /// (공백·'/' 등 특수문자가 URL 에서 끊기지 않도록 본문으로 받는다.)
    /// 본문이 없으면 메시지 없이 카운트만 증가한다. message 는 ReceiveMessageLog.Message 컬럼에 저장된다.
    /// </summary>
    [HttpPost("ping")]
    public async Task<IActionResult> Ping(

        [FromBody(EmptyBodyBehavior = EmptyBodyBehavior.Allow)] PingRequest? body = null)
    {
        var result = await _emergency.RegisterIncomingAsync(sendId: body?.SendId, receiveId: body?.ReceiveId, message: body?.Message, markMaster: true);
        // 단축어 친화적 평문 응답
        return Content($"OK count={result.CurrentCount} triggered={result.Triggered}", "text/plain");
    }

    /// <summary>등록된 모니터링 회선 id 목록(안드로이드 화면에서 불러오기용).</summary>
    [HttpGet("configs")]
    public async Task<IActionResult> GetConfigs()
    {
        var ids = await _db._기기동기화설정.AsNoTracking()
            .OrderBy(c => c.Id)
            .Select(c => new { c.Id, c.메인여부, c.메시지큐 })
            .ToListAsync();
        return Ok(ids);
    }

    /// <summary>특정 회선 설정 조회.</summary>
    [HttpGet("config/{id}")]
    public async Task<IActionResult> GetConfig(string id)
    {
        var c = await _db._기기동기화설정.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id);
        if (c == null) return NotFound();
        return Ok(new { c.Id, c.메인여부, c.메시지큐 });
    }

    /// <summary>
    /// 안드로이드 "메시지 파싱 대상" 저장. 해당 회선 config 를 만들고 is_master=true 로 설정.
    /// </summary>
    [HttpPost("master")]
    public async Task<IActionResult> SetMaster([FromBody] MasterRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Id))
            return BadRequest(new { message = "id(휴대폰번호)가 필요합니다." });

        var c = await _db._기기동기화설정.FirstOrDefaultAsync(x => x.Id == req.Id);
        if (c == null)
        {
            c = new 기기동기화설정 { Id = req.Id, 메인여부 = true, 메시지큐 = 0 };
            _db._기기동기화설정.Add(c);
        }
        else
        {
            c.메인여부 = true;
        }
        await _db.SaveChangesAsync();
        return Ok(new { message = "저장 완료", id = c.Id, isMaster = c.메인여부 });
    }
}
