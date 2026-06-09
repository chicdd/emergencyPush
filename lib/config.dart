import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// API 서버 주소.
///
/// .NET API 는 기본적으로 http://localhost:5048 에서 동작한다(launchSettings.json).
/// - Android 에뮬레이터: 호스트 PC 의 localhost 는 10.0.2.2 로 접근.
/// - iOS 시뮬레이터 / 데스크톱: localhost 그대로.
/// 실기기에서 테스트할 때는 PC 의 LAN IP(예: http://192.168.0.10:5048)로 바꾸세요.
class AppConfig {
  static const int _port = 5048;

  static String get apiBaseUrl {
    if (kIsWeb) return 'http://localhost:$_port';
    if (Platform.isAndroid) return 'http://10.0.2.2:$_port';
    return 'http://localhost:$_port';
  }

  /// 인증 화면 비밀번호.
  static const String authPassword = '01579#';
}
