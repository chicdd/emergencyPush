# 비상상황 푸시 시스템 (캡스 보라매 신호 미상승 대응)

캡스 보라매 비상상황(보안 신호가 정상적으로 올라오지 않는 상황)에 대응하는 알림 시스템.
모니터링 대상 휴대전화 회선으로 **특정 발신번호의 메시지가 1분 내 10건** 연속 도달하면,
앱 사용자 **전원에게 1초에 1번씩 푸시**를 지속 발송한다. 누군가 **상황 해제**를 누르면
서버측 발송이 즉시 중지된다.

---

## 목차
1. [기술 스택 & 버전](#1-기술-스택--버전)
2. [시스템 아키텍처](#2-시스템-아키텍처)
3. [프로젝트 구조](#3-프로젝트-구조)
4. [데이터베이스](#4-데이터베이스)
5. [비상 감지 로직](#5-비상-감지-로직)
6. [앱 화면 흐름](#6-앱-화면-흐름)
7. [API 엔드포인트](#7-api-엔드포인트)
8. [실행 방법 (개발)](#8-실행-방법-개발)
9. [서버 배포 (IIS)](#9-서버-배포-iis)
10. [Firebase 설정](#10-firebase-설정)
11. [트러블슈팅](#11-트러블슈팅)

---

## 1. 기술 스택 & 버전

| 구분 | 기술 | 버전 |
|---|---|---|
| **프론트엔드** | Flutter | 3.41.9 (stable) |
| | Dart | 3.11.5 |
| | 대상 플랫폼 | Android / iOS |
| **백엔드** | .NET | 10.0 (SDK 10.0.202) |
| | ASP.NET Core Web API | net10.0 |
| | Entity Framework Core (SqlServer) | 10.0.8 |
| | FirebaseAdmin (서버 FCM) | 3.5.0 |
| | Microsoft.AspNetCore.OpenApi | 10.0.6 |
| **DB** | Microsoft SQL Server | 2019+ |
| **푸시** | Firebase Cloud Messaging (HTTP v1) | 프로젝트 `fcm-project-af3ae` |
| **웹서버** | IIS (ASP.NET Core Module v2, in-process) | + .NET 10 Hosting Bundle |

### Flutter 패키지 (`pubspec.yaml`)

| 패키지 | 버전 | 용도 |
|---|---|---|
| `firebase_core` | ^4.10.0 | Firebase 초기화 |
| `firebase_messaging` | ^16.3.0 | FCM 토큰/메시지 수신 |
| `flutter_local_notifications` | ^22.0.0 | 알림 채널 생성 + 포그라운드 알림 표시 |
| `flutter_ringtone_player` | ^4.0.0 | 비상 시 알람음 재생 |
| `http` | ^1.6.0 | API 호출 |
| `shared_preferences` | ^2.5.5 | 로그인 세션(휴대폰번호) 저장 |
| `cupertino_icons` | ^1.0.8 | 아이콘 |

### Android 빌드 설정 (`android/app/build.gradle.kts`)
- `applicationId` / `namespace` : `com.neo.emergencypush`
- `minSdk` : **23** (Firebase Messaging 요구)
- `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.4` (flutter_local_notifications 요구)
- Gradle 플러그인 : AGP `8.11.1`, Kotlin `2.2.20`, `com.google.gms.google-services` `4.4.2`

---

## 2. 시스템 아키텍처

```
 [모니터링 단말]                 [.NET 10 Web API / IIS]              [MSSQL]
  iOS 단축어 ──GET ping──▶  ┌──────────────────────────┐  ◀──EF Core──▶  user
  Android SMS ─POST incoming▶│ DeviceController         │             device_sync_configs
                            │ MessageController         │             receive_message_log
                            │  └ EmergencyService(트리거)│             send_push_log
                            │ EmergencySignal(메모리 신호)│             emergency_state
                            │  └ PushLoopHostedService ──┼──FCM HTTP v1──┐  setting
                            └──────────────────────────┘               │
                                                                       ▼
 [앱 사용자들] ◀──────────── Firebase Cloud Messaging ◀─────────────────┘
   Flutter (정상/비상 화면, 알람음, 상황 해제)
```

- **수신 경로 2가지**: iOS는 단축어가 `POST /api/device/ping/{회선번호}` 호출, Android는 앱이 SMS를 `POST /api/message/incoming`으로 포워딩.
- **트리거 판정**은 서버 `EmergencyService`가 수행, 발송은 `PushLoopHostedService`(백그라운드)가 담당.
- 비상 상태는 **메모리 신호(`EmergencySignal`)** 로 공유 → 평상시 DB 폴링 0.

---

## 3. 프로젝트 구조

```
emergencypush/
├─ lib/                              # Flutter 앱
│  ├─ main.dart                      # 진입점: Firebase/알림 초기화, 라우팅, 전역 비상 표시
│  ├─ config.dart                    # 접속 대상(production/device/emulator) + 인증 비밀번호
│  ├─ theme.dart                     # 다크 미래지향 테마(AppColors)
│  ├─ screens/
│  │  ├─ auth_screen.dart            # 인증(휴대폰번호 + 비밀번호 01579#)
│  │  ├─ home_screen.dart            # '정상' + 호흡 애니메이션 + 서버 헬스체크 배너
│  │  ├─ settings_screen.dart        # iOS/Android 분기 + 테스트푸시/상황해제 버튼
│  │  └─ emergency_screen.dart       # 회전 사이렌 + 명암 펄스 + 상황 해제
│  └─ services/
│     ├─ api_service.dart            # API 호출 래퍼
│     ├─ fcm_service.dart            # FCM 토큰/수신 처리, 비상 알람음
│     ├─ local_notifications.dart    # 알림 채널(emergency_channel) + 표시
│     └─ session.dart               # 휴대폰번호 영구 저장(SharedPreferences)
│
├─ android/  ios/                    # google-services.json / GoogleService-Info.plist 배치
│
└─ api/                              # .NET 10 Web API
   ├─ Program.cs                     # DI 등록, EF Core, 백그라운드 서비스, CORS
   ├─ appsettings.json               # 연결문자열 + Firebase 키 경로 (.gitignore)
   ├─ Controllers/
   │  ├─ AuthController.cs           # POST /api/auth/register
   │  ├─ DeviceController.cs         # ping / master / configs
   │  ├─ MessageController.cs        # POST /api/message/incoming
   │  ├─ EmergencyController.cs      # status / resolve / acknowledge
   │  └─ PushController.cs           # POST /api/push/test (진단용 테스트 푸시)
   ├─ Services/
   │  ├─ EmergencyService.cs         # 카운팅 + 트리거 판정 (핵심)
   │  ├─ EmergencySignal.cs          # 비상 상태 메모리 공유 + 루프 깨우기(폴링 제거)
   │  ├─ PushLoopHostedService.cs    # 비상 시 1초 간격 푸시 발송 + 로그
   │  ├─ CountResetHostedService.cs  # 10분 무수신 count 초기화(5분 주기 set-based)
   │  ├─ FcmService.cs               # FirebaseAdmin 기반 발송 + 실패 사유 집계
   │  ├─ SettingsService.cs          # setting 테이블 런타임 설정 조회
   │  └─ KoreaTime.cs                # 모든 시각을 KST(UTC+9)로 저장
   ├─ Models/                        # User, DeviceSyncConfig, ReceiveMessageLog,
   │                                 #   SendPushLog, EmergencyState, Setting, Dtos
   └─ Data/AppDbContext.cs           # EF Core DbContext
```

---

## 4. 데이터베이스

**MSSQL** (DB명: `Emergencypush`). 모든 시각 컬럼은 **KST(UTC+9)** 로 저장된다(`KoreaTime`).

### 테이블 요약

| 테이블 | 용도 | 주요 컬럼 |
|---|---|---|
| `user` | 앱 사용자(푸시 수신 대상) | seq(PK,auto), id(휴대폰번호,UQ), firebase_token, recent_date, registration_date |
| `device_sync_configs` | 모니터링 회선 설정 | id(PK,휴대폰번호), is_master, count, window_start_at, last_message_at |
| `receive_message_log` | 수신 메시지 로그 | id(PK,auto), send_id(발신), receive_id(모니터링회선), message, date |
| `send_push_log` | 발송 푸시 로그 | id(PK,auto), user_id, message, receive_id, date |
| `emergency_state` | 비상 상태(푸시 루프 제어) | id(PK,auto), is_active, triggered_by, message, started_at, resolved_at, resolved_by |
| `setting` | 런타임 임계값(key/value) | key(PK), value |

### 생성 스크립트 (DDL)

```sql
-- user : 앱 사용자
IF OBJECT_ID(N'dbo.[user]', N'U') IS NULL
CREATE TABLE dbo.[user] (
    seq               INT IDENTITY(1,1) PRIMARY KEY,
    id                NVARCHAR(20)  NOT NULL,
    firebase_token    NVARCHAR(512) NULL,
    recent_date       DATETIME2(0)  NULL,
    registration_date DATETIME2(0)  NOT NULL DEFAULT (DATEADD(HOUR,9,SYSUTCDATETIME()))
);
CREATE UNIQUE INDEX UX_user_id ON dbo.[user](id);

-- device_sync_configs : 모니터링 회선
IF OBJECT_ID(N'dbo.device_sync_configs', N'U') IS NULL
CREATE TABLE dbo.device_sync_configs (
    id              NVARCHAR(20) PRIMARY KEY,
    is_master       BIT          NOT NULL DEFAULT (0),
    [count]         INT          NOT NULL DEFAULT (0),
    window_start_at DATETIME2(3) NULL,
    last_message_at DATETIME2(3) NULL
);

-- receive_message_log : 수신 로그
IF OBJECT_ID(N'dbo.receive_message_log', N'U') IS NULL
CREATE TABLE dbo.receive_message_log (
    id         INT IDENTITY(1,1) PRIMARY KEY,
    send_id    NVARCHAR(20)  NULL,
    receive_id NVARCHAR(20)  NOT NULL,
    message    NVARCHAR(MAX) NULL,
    [date]     DATETIME2(3)  NOT NULL DEFAULT (DATEADD(HOUR,9,SYSUTCDATETIME()))
);
CREATE INDEX IX_rml_window ON dbo.receive_message_log(receive_id, send_id, [date]);

-- send_push_log : 발송 로그
IF OBJECT_ID(N'dbo.send_push_log', N'U') IS NULL
CREATE TABLE dbo.send_push_log (
    id         INT IDENTITY(1,1) PRIMARY KEY,
    user_id    NVARCHAR(20)  NULL,
    message    NVARCHAR(MAX) NULL,
    receive_id NVARCHAR(20)  NULL,
    [date]     DATETIME2(3)  NOT NULL DEFAULT (DATEADD(HOUR,9,SYSUTCDATETIME()))
);

-- emergency_state : 비상 상태
IF OBJECT_ID(N'dbo.emergency_state', N'U') IS NULL
CREATE TABLE dbo.emergency_state (
    id           INT IDENTITY(1,1) PRIMARY KEY,
    is_active    BIT          NOT NULL DEFAULT (0),
    triggered_by NVARCHAR(20) NULL,
    message      NVARCHAR(MAX) NULL,
    started_at   DATETIME2(0) NOT NULL DEFAULT (DATEADD(HOUR,9,SYSUTCDATETIME())),
    resolved_at  DATETIME2(0) NULL,
    resolved_by  NVARCHAR(20) NULL
);
CREATE INDEX IX_es_active ON dbo.emergency_state(is_active);

-- setting : 런타임 설정
IF OBJECT_ID(N'dbo.setting', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.setting ([key] NVARCHAR(100) PRIMARY KEY, [value] NVARCHAR(MAX) NULL);
    INSERT INTO dbo.setting([key],[value]) VALUES
        (N'trigger_threshold',   N'10'),    -- 1분 내 도달 건수
        (N'trigger_window_sec',  N'60'),    -- 카운팅 윈도우(초)
        (N'count_reset_minutes', N'10'),    -- 무수신 시 count 초기화(분)
        (N'push_interval_ms',    N'1000'),  -- 비상 시 발송 간격(ms)
        (N'push_message',        N'[비상] 캡스 보라매 신호 미상승 상황이 감지되었습니다. 즉시 확인하세요.');
END
```

> 임계값(10건/1분/10분/1초)은 코드 재배포 없이 `setting` 테이블 값만 바꿔 조정할 수 있다.

---

## 5. 비상 감지 로직

`is_master = true` 인 회선에 메시지가 오면(`EmergencyService.RegisterIncomingAsync`):

1. `receive_message_log` 에 로그 기록
2. `device_sync_configs.count` +1 (표시/단순집계용, 1분 윈도우 단위)
3. 마지막 수신 후 **10분** 변화 없으면 count 를 0 으로 초기화 (수신 경로 + `CountResetHostedService` 이중 보장)
4. **1분 내 10건** 도달 시 비상 시작 → 토큰 보유자 전원에게 1초 간격 푸시
5. 발송 푸시는 모두 `send_push_log` 에 기록

### 다중 발신자 처리
단일 카운터만 쓰면 서로 다른 발신번호가 섞여 오탐/누락이 생긴다. 그래서 **실제 트리거 판정은
`receive_message_log` 타임스탬프 기반 `(모니터링 회선, 발신번호)` 쌍별 슬라이딩 1분 윈도우 카운트**로 한다.
- 발신번호를 아는 Android 경로: 발신자별 독립 집계 → A가 쌓이는 중 B가 와도 서로 무관, 각자 1분/10건 도달 시 트리거.
- 발신번호를 모르는 iOS ping: 해당 회선 전체를 한 묶음으로 집계.

### 이벤트 기반 발송(부하 최소화)
평상시 `PushLoopHostedService`는 **`EmergencySignal`이 깨울 때까지 잠들어 DB를 호출하지 않는다.**
- 비상 시작(API 요청 처리 중) → `Activate()` → 루프가 즉시 깨어나 1초마다 발송
- 상황 해제 → `Deactivate()` → 루프 즉시 정지
- 프로세스 재시작 대비: 시작 시 **1회만** DB에서 활성 비상 복구
- 단일 서버 인스턴스 기준(메모리 신호). 스케일아웃 시 분산 신호로 교체 필요.

---

## 6. 앱 화면 흐름

1. **인증** (`auth_screen`) — 휴대폰번호 + 비밀번호. `01579#` 입력 시 홈으로(틀리면 빨간 "인증 실패").
   인증 시 휴대폰번호 + FCM 토큰을 `POST /api/auth/register`로 전송 → `user` 저장.
2. **홈** (`home_screen`) — "정상" + 초록↔파랑 호흡 애니메이션. 30초마다 서버 헬스체크(실패 시 상단 빨간 배너). 우상단 설정 아이콘.
3. **설정** (`settings_screen`)
   - **iOS**: 단축어/자동화 사용방법 + `ping` URL + 복사하기 버튼.
   - **Android**: "메시지 파싱 대상" 입력 + 저장(→ `is_master=true`).
   - **공통(하단)**: **테스트 푸시 보내기**(진단), **상황 해제(서버 푸시 중지)**.
4. **비상** (`emergency_screen`) — `data.type=='emergency'` 푸시 수신 시 진입. 회전 사이렌 + 1초 명/1초 암 펄스 + 알람음. "상황 해제" → 푸시 중지.

> 알림 소리: Android는 고중요도 채널 `emergency_channel`로 표시, 포그라운드 비상은 `flutter_ringtone_player`로 알람음 재생. 테스트 푸시(`type=test`)는 비상 화면/알람을 발동하지 않는다.

---

## 7. API 엔드포인트

| Method | Path | 설명 |
|---|---|---|
| POST | `/api/auth/register` | 휴대폰번호 + FCM 토큰 등록(upsert) |
| POST | `/api/device/ping/{id}` | iOS 단축어/모니터링 hook (메시지 수신 보고, 해당 회선 master 표시). `message` 는 JSON 본문(`{"message":"..."}`) |
| POST | `/api/device/master` | Android "메시지 파싱 대상" 저장 (`is_master=true`) |
| GET  | `/api/device/configs` | 등록된 모니터링 회선 목록 |
| GET  | `/api/device/config/{id}` | 특정 회선 설정 조회 |
| POST | `/api/message/incoming` | Android SMS 포워딩 (`receiveId`, `sendId`, `message`) |
| GET  | `/api/emergency/status` | 현재 비상 상태 (앱 헬스체크에도 사용) |
| POST | `/api/emergency/resolve` | 상황 해제 (푸시 중지) |
| POST | `/api/emergency/acknowledge` | 상황 확인 (= 해제) |
| POST | `/api/push/test` | 테스트 푸시 1회 발송 + 진단 결과(성공/실패/사유) 반환 |

---

## 8. 실행 방법 (개발)

### 사전 준비
- Flutter 3.41+, .NET 10 SDK, MSSQL 접근
- `api/appsettings.json`에 연결문자열 + Firebase 키 경로 설정 (아래 [10. Firebase 설정](#10-firebase-설정))
- 위 [4. 데이터베이스](#4-데이터베이스) DDL로 테이블 생성

### API 실행
```powershell
cd api
dotnet run                                   # http://localhost:5048
# 실기기/외부 접속 테스트 시:
dotnet run --urls "http://0.0.0.0:5048"
```

### 앱 실행
```powershell
flutter pub get
flutter run
```

### 접속 대상 전환 (`lib/config.dart`)
`AppConfig.target` 한 줄만 바꾼다.
```dart
static const AppTarget target = AppTarget.production; // 배포 서버(HTTPS)
//                              AppTarget.device;     // 실기기 → PC LAN IP(testBaseUrl)
//                              AppTarget.emulator;   // 에뮬레이터(Android 10.0.2.2)
```
- 운영: `productionBaseUrl = https://emergencypush.neoworker.co.kr`
- 실기기: `testBaseUrl = http://<PC LAN IP>:5048` (휴대폰과 같은 와이파이, 방화벽 5048 인바운드, Android는 `network_security_config.xml`에 해당 IP 추가됨)

---

## 9. 서버 배포 (IIS)

1. **.NET 10 Hosting Bundle 설치** (필수: 런타임 + ASP.NET Core 모듈) → `net stop was /y; net start w3svc`
2. **게시**: `dotnet publish -c Release -o D:\publish\emergencypush-api` → 폴더 전체를 서버로 복사 (예: `C:\inetpub\EmergencyPush`)
3. **App Pool**: `.NET CLR = 관리 코드 없음`, **시작 모드 AlwaysRunning**, **유휴 제한 0**, **정기 재활용 0** (백그라운드 푸시 루프 유지를 위해)
4. **사이트 물리 경로** = 게시 폴더(반드시 `web.config` 포함)
5. **appsettings.json**: 연결문자열 확인 + `Firebase:ServiceAccountPath`는 `firebase-service-account.json`(상대경로, 앱 폴더 기준 자동 탐색)
6. **권한**: App Pool 신원에 폴더/키 파일 읽기 권한 부여
7. **방화벽/HTTPS**: 도메인 바인딩에 유효 인증서, 인바운드 포트 개방
8. 확인: `https://emergencypush.neoworker.co.kr/api/emergency/status` → `{"active":false,...}`

---

## 10. Firebase 설정

- 클라이언트 설정 파일은 배치되어 있다: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` (프로젝트 `fcm-project-af3ae`).
- 서버가 FCM HTTP v1으로 발송하려면 **서비스 계정 키(JSON)** 가 필요하다.
  - Firebase Console → 프로젝트 설정 → **서비스 계정** → **새 비공개 키 생성** → `api/firebase-service-account.json`으로 저장
  - 게시 시 자동으로 출력 폴더에 복사됨(csproj 설정). 키는 `.gitignore` 대상.
- **서비스 계정 권한**: 해당 계정에 FCM 발송 권한이 있어야 한다. (커스텀 계정이면 IAM에서 `Firebase Cloud Messaging API 관리자` 역할 부여, 또는 Firebase 기본 `firebase-adminsdk-...` 계정 키 사용 권장)
- **Cloud Console**에서 **Firebase Cloud Messaging API** 사용 설정 확인.

---

## 11. 트러블슈팅

| 증상 | 원인 | 해결 |
|---|---|---|
| 사이트 `HTTP 503` | App Pool 정지(앱 시작 크래시 → 빠른 실패 보호) | stdout 로깅 켜서 원인 확인; 보통 런타임/연결문자열 문제 |
| `dotnet --list-runtimes`에 10.0 없음 | .NET 10 미설치 | **Hosting Bundle** 설치 후 IIS 재시작 |
| `chrome-error / 페이지 로드 실패` | HTTPS 인증서/바인딩 또는 앱 미기동 | 443 바인딩·인증서 확인, 실제 엔드포인트(`/api/emergency/status`)로 테스트 |
| "FCM 서비스 계정 키 없음" | 키 미배포 또는 경로 오류 | 키를 앱 폴더에 두고 `ServiceAccountPath` 상대경로 사용 |
| 테스트 푸시 `PermissionDenied` | 서비스 계정에 FCM 발송 권한/API 없음 | IAM 역할 부여 또는 Firebase 기본 키로 교체 + FCM API 사용 설정 |
| 테스트 푸시 `Unregistered` | 토큰 만료(앱 삭제/재설치) | 앱 재설치 후 재인증으로 토큰 재등록 |
| 테스트 푸시 `SenderIdMismatch` | 앱과 서버 키의 Firebase 프로젝트 불일치 | 동일 프로젝트로 통일 후 앱 재빌드 |
| 푸시 소리 안 남 | 알림 채널 미생성(옛 빌드)/포그라운드 미표시 | 최신 앱 재설치(`emergency_channel`), Android 13+ 알림 권한 허용 |
| 로그가 1초마다 폭주 | 활성 비상(`is_active=1`)이 안 꺼짐 | `POST /api/emergency/resolve` 또는 설정 화면 "상황 해제"; EF 로그는 Warning으로 낮춤 |
| DB 시각이 9시간 어긋남 | (해결됨) UTC 저장 | 전 구간 `KoreaTime`(KST) 적용 — 재배포 시 정상 |

### 서버 로그(ASP.NET Core) 보는 법
IIS 관리자가 아니라 **stdout 로그**로 본다. `web.config`에서:
```xml
<aspNetCore ... stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="inprocess" />
```
`logs` 폴더를 만들고(App Pool에 쓰기 권한) App Pool 재시작 → `logs\stdout_<pid>_<시각>.log` 파일 생성.
(`stdout`은 폴더가 아니라 **파일명 접두사**.) 진단 후 `stdoutLogEnabled="false"`로 되돌릴 것.
```

---

> 비밀 정보(`appsettings.json`, `firebase-service-account.json`)는 `.gitignore` 대상이며 저장소에 포함되지 않는다. 서비스 계정 키가 유출되면 Firebase Console에서 즉시 폐기/재발급할 것.
