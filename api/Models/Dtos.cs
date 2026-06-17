namespace EmergencyPushApi.Models;

public record RegisterRequest(string Phone, string? FirebaseToken);

public record MasterRequest(string Id);

public record PingRequest(string? Message);

public record IncomingMessageRequest(string ReceiveId, string? SendId, string? Message);

public record ResolveRequest(string? Phone);

/// <summary>메시지 등록 결과.</summary>
public record MessageResult(
    int CurrentCount,
    bool Triggered,
    bool EmergencyActive);

public record EmergencyStatusResponse(
    bool Active,
    string? TriggeredBy,
    string? Message,
    DateTime? StartedAt);
