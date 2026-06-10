import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// API 서버 주소.
class AppConfig {
  // ───────────────────────────────────────────────────────────
  // ⚠️ 배포 서버 도메인 — 실제 도메인으로 바꾸세요. (HTTPS)
  //    iPhone 단축어 "복사하기" URL 도 이 주소를 사용합니다.
  static const String productionBaseUrl = 'https://emergencypush.neoworker.co.kr';
  // ───────────────────────────────────────────────────────────

  /// 로컬 개발용 스위치.
  ///  - false(기본): 위 productionBaseUrl(배포 서버) 사용.
  ///  - true       : 에뮬레이터/시뮬레이터에서 로컬 .NET API(localhost:5048) 사용.
  static const bool useLocalDev = false;

  static const int _devPort = 5048;

  static String get apiBaseUrl {
    if (!useLocalDev) return productionBaseUrl;
    // 로컬 개발: Android 에뮬레이터는 호스트 localhost 를 10.0.2.2 로 접근.
    if (kIsWeb) return 'http://localhost:$_devPort';
    if (Platform.isAndroid) return 'http://10.0.2.2:$_devPort';
    return 'http://localhost:$_devPort';
  }

  /// 인증 화면 비밀번호.
  static const String authPassword = '01579#';
}
