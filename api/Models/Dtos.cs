namespace EmergencyPushApi.Models;

public record RegisterRequest(string Phone, string? FirebaseToken);

public record DeleteAccountRequest(string Phone);

public record MasterRequest(string Id);

public record PingRequest(string? SendId, string? ReceiveId, string? Message);

public record IncomingMessageRequest(string ReceiveId, string? SendId, string? Message);

public record ResolveRequest(string? Phone);
public record ArmRequest(string? value);

/// <summary>메시지 등록 결과.</summary>
public record MessageResult(
    int CurrentCount,
    bool Triggered,
    bool EmergencyActive);

public record EmergencyStatusResponse(
    bool Active,
    string? 최초휴대폰번호,
    string? Message,
    DateTime? StartedAt,
    bool Acknowledged);
