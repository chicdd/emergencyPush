-- ============================================================
-- 캡스 보라매 비상상황 푸시 시스템 - MSSQL 스키마
-- 대상: SQL Server 2019+ (DATETIME2, SEQUENCE, BIT)
-- 사용법: 대상 DB를 선택한 뒤 이 스크립트를 실행하세요.
-- ============================================================

-- ------------------------------------------------------------
-- user : 앱 사용자(푸시 수신 대상)
--   seq               관리 id (자동 증가)
--   id                휴대폰번호 (로그인 식별자, 유니크)
--   firebase_token    FCM 등록 토큰
--   recent_date       최근 인증/접속 시각
--   registration_date 최초 등록 시각
-- ------------------------------------------------------------
IF OBJECT_ID(N'dbo.[user]', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.[user]
    (
        seq               INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        id                NVARCHAR(20)      NOT NULL,
        firebase_token    NVARCHAR(512)     NULL,
        recent_date       DATETIME2(0)      NULL,
        registration_date DATETIME2(0)      NOT NULL CONSTRAINT DF_user_regdate DEFAULT (SYSUTCDATETIME())
    );
    CREATE UNIQUE INDEX UX_user_id ON dbo.[user](id);
END
GO

-- ------------------------------------------------------------
-- device_sync_configs : 메시지 파싱 대상(모니터링 단말) 설정
--   id              휴대폰번호(모니터링 대상 회선)
--   is_master       이 회선을 비상 감지 대상으로 사용할지 여부
--   count           현재 누적 카운트(표시/단순집계용)
--   window_start_at 현재 1분 카운팅 윈도우 시작 시각(UTC)
--   last_message_at 마지막 메시지 수신 시각(UTC) - 10분 미수신 시 초기화 판단
-- ------------------------------------------------------------
IF OBJECT_ID(N'dbo.device_sync_configs', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.device_sync_configs
    (
        id              NVARCHAR(20) NOT NULL PRIMARY KEY,
        is_master       BIT          NOT NULL CONSTRAINT DF_dsc_master DEFAULT (0),
        [count]         INT          NOT NULL CONSTRAINT DF_dsc_count  DEFAULT (0),
        window_start_at DATETIME2(3) NULL,
        last_message_at DATETIME2(3) NULL
    );
END
GO

-- ------------------------------------------------------------
-- receive_message_log : 모니터링 단말이 수신한 메시지 로그
--   id         자동 증가
--   send_id    보낸사람(발신 SMS 번호)
--   receive_id 받은사람(모니터링 단말 회선 번호)
--   message    메시지 내용
--   date       수신 시각(UTC)
-- ------------------------------------------------------------
IF OBJECT_ID(N'dbo.receive_message_log', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.receive_message_log
    (
        id         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        send_id    NVARCHAR(20)      NULL,
        receive_id NVARCHAR(20)      NOT NULL,
        message    NVARCHAR(MAX)     NULL,
        [date]     DATETIME2(3)      NOT NULL CONSTRAINT DF_rml_date DEFAULT (SYSUTCDATETIME())
    );
    -- 슬라이딩 윈도우 카운트 조회 최적화 (회선 + 발신자 + 시각)
    CREATE INDEX IX_rml_window ON dbo.receive_message_log(receive_id, send_id, [date]);
END
GO

-- ------------------------------------------------------------
-- send_push_log : 발송된 푸시 로그
--   id         자동 증가
--   user_id    푸시를 받은 사용자 휴대폰번호
--   message    푸시 메시지
--   receive_id 비상 트리거가 된 모니터링 회선 번호(참고)
--   date       발송 시각(UTC)
-- ------------------------------------------------------------
IF OBJECT_ID(N'dbo.send_push_log', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.send_push_log
    (
        id         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        user_id    NVARCHAR(20)      NULL,
        message    NVARCHAR(MAX)     NULL,
        receive_id NVARCHAR(20)      NULL,
        [date]     DATETIME2(3)      NOT NULL CONSTRAINT DF_spl_date DEFAULT (SYSUTCDATETIME())
    );
END
GO

-- ------------------------------------------------------------
-- emergency_state : 비상 상황 상태(푸시 루프 제어)
--   id           자동 증가
--   is_active    현재 활성 여부 (1=푸시 지속 발송 중)
--   triggered_by 트리거가 된 회선/발신 번호
--   message      비상 메시지(샘플 메시지)
--   started_at   비상 시작 시각(UTC)
--   resolved_at  상황 해제 시각(UTC)
--   resolved_by  해제한 사용자 휴대폰번호
-- ------------------------------------------------------------
IF OBJECT_ID(N'dbo.emergency_state', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.emergency_state
    (
        id           INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        is_active    BIT          NOT NULL CONSTRAINT DF_es_active DEFAULT (0),
        triggered_by NVARCHAR(20) NULL,
        message      NVARCHAR(MAX) NULL,
        started_at   DATETIME2(0) NOT NULL CONSTRAINT DF_es_start DEFAULT (SYSUTCDATETIME()),
        resolved_at  DATETIME2(0) NULL,
        resolved_by  NVARCHAR(20) NULL
    );
    CREATE INDEX IX_es_active ON dbo.emergency_state(is_active);
END
GO

-- ------------------------------------------------------------
-- setting : 시스템 설정(key/value). 임계값 등 런타임 조정용.
-- ------------------------------------------------------------
IF OBJECT_ID(N'dbo.setting', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.setting
    (
        [key]   NVARCHAR(100) NOT NULL PRIMARY KEY,
        [value] NVARCHAR(MAX) NULL
    );

    INSERT INTO dbo.setting([key], [value]) VALUES
        (N'trigger_threshold',     N'10'),   -- 1분 내 도달 시 비상 발생 (건수)
        (N'trigger_window_sec',    N'60'),   -- 카운팅 윈도우 (초)
        (N'count_reset_minutes',   N'10'),   -- 무수신 시 count 초기화 (분)
        (N'push_interval_ms',      N'1000'), -- 비상 시 푸시 발송 간격 (ms)
        (N'push_message',          N'[비상] 캡스 보라매 신호 미상승 상황이 감지되었습니다. 즉시 확인하세요.');
END
GO

PRINT '스키마 생성 완료.';
GO
