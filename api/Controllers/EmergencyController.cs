using EmergencyPushApi.Models;
using EmergencyPushApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace EmergencyPushApi.Controllers;

[ApiController]
[Route("api/emergency")]
public class EmergencyController : ControllerBase
{
    private readonly EmergencyService _emergency;

    public EmergencyController(EmergencyService emergency) => _emergency = emergency;

    /// <summary>현재 비상 상태 조회.</summary>
    [HttpGet("status")]
    public async Task<IActionResult> Status()
        => Ok(await _emergency.GetStatusAsync());

    /// <summary>
    /// 상황 해제. 앱의 "상황 해제" 버튼에서 호출.
    /// 서버측 푸시 발송이 즉시 멈춘다.
    /// </summary>
    [HttpPost("resolve")]
    public async Task<IActionResult> Resolve([FromBody] ResolveRequest? req)
    {
        var count = await _emergency.ResolveAllAsync(req?.Phone);
        return Ok(new { message = "상황 해제됨", resolved = count });
    }

    /// <summary>
    /// 상황 확인(=해제). 푸시가 지속되던 모든 사용자의 푸시를 멈춘다.
    /// </summary>
    [HttpPost("acknowledge")]
    public async Task<IActionResult> Acknowledge([FromBody] ResolveRequest? req)
    {
        var count = await _emergency.ResolveAllAsync(req?.Phone);
        return Ok(new { message = "상황 확인됨", resolved = count });
    }
}
