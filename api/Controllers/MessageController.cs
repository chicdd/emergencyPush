using EmergencyPushApi.Models;
using EmergencyPushApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace EmergencyPushApi.Controllers;

[ApiController]
[Route("api/message")]
public class MessageController : ControllerBase
{
    private readonly EmergencyService _emergency;

    public MessageController(EmergencyService emergency) => _emergency = emergency;

    /// <summary>
    /// 안드로이드 SMS 포워딩용. 모니터링 단말이 메시지를 받으면 발신번호/본문과 함께 호출.
    /// is_master 회선이면 로그 기록 + 카운트 + 트리거 판정을 수행한다.
    /// </summary>
    [HttpPost("incoming")]
    public async Task<IActionResult> Incoming([FromBody] IncomingMessageRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.ReceiveId))
            return BadRequest(new { message = "receiveId(모니터링 회선)가 필요합니다." });

        var result = await _emergency.RegisterIncomingAsync(
            req.ReceiveId, req.SendId, req.Message, markMaster: false);

        return Ok(result);
    }
}
