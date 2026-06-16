import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// 접속 대상.
enum AppTarget {
  production, // 배포 서버(HTTPS 도메인)
  device,     // 실기기 → 같은 와이파이의 PC(LAN IP)
  emulator,   // 에뮬레이터/시뮬레이터 → localhost(Android는 10.0.2.2)
}

/// API 서버 주소.
class AppConfig {
  // ───────────────────────────────────────────────────────────
  // ▶ 접속 대상 선택 — 여기만 바꾸면 됩니다.
  static const AppTarget target = AppTarget.production;
  // ───────────────────────────────────────────────────────────

  /// 운영(배포) 서버 — HTTPS 도메인. iPhone 단축어 "복사하기" URL도 이 주소 사용.
  static const String productionBaseUrl = 'https://emergencypush.neoworker.co.kr';

  /// 실기기 테스트 — PC에서 API 실행 시 "PC의 LAN IP". (휴대폰과 같은 와이파이)
  static const String testBaseUrl = 'http://192.168.0.50:5048';

  static const int _devPort = 5048;

  static String get apiBaseUrl {
    switch (target) {
      case AppTarget.production:
        return productionBaseUrl;
      case AppTarget.device:
        return testBaseUrl;
      case AppTarget.emulator:
        if (kIsWeb) return 'http://localhost:$_devPort';
        if (Platform.isAndroid) return 'http://10.0.2.2:$_devPort';
        return 'http://localhost:$_devPort';
    }
  }
}
