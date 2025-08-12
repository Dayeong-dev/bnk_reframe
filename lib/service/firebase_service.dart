// lib/service/firebase_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart'; // flutterfire configure 로 생성된 파일

// 백그라운드 수신 핸들러(최상위 함수 필수)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 필요 시 최소 로깅/저장만 (UI 금지)
}

/// Analytics 화면 전환 로깅용 커스텀 옵저버 (observer.dart 대체)
class AnalyticsRouteObserver extends NavigatorObserver {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  void _log(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) {
      _analytics.logScreenView(screenName: name);
    }
  }
  @override
  void didPush(Route route, Route? previousRoute) { _log(route); super.didPush(route, previousRoute); }
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) { _log(newRoute); super.didReplace(newRoute: newRoute, oldRoute: oldRoute); }
  @override
  void didPop(Route route, Route? previousRoute) { _log(previousRoute); super.didPop(route, previousRoute); }
}

class FirebaseService {
  FirebaseService._(this.analytics, this.routeObserver, this._baseUrl);

  final FirebaseAnalytics analytics;
  final AnalyticsRouteObserver routeObserver;
  final String _baseUrl;

  /// 실습용 고정 서버 IP (요청하신 값)
  static String get defaultBaseUrl => 'http://localhost:8080';

  /// main()에서 한 번만 호출
  static Future<FirebaseService> init({
    String? baseUrl,
    bool forceRefreshToken = true, // 패키지/프로젝트 이관 후 권장
  }) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _requestNotificationPermission();

    final resolved = baseUrl ?? defaultBaseUrl;
    await _prepareAndRegisterFcmToken(resolved, forceRefreshToken);

    final analytics = FirebaseAnalytics.instance;
    final observer = AnalyticsRouteObserver();
    return FirebaseService._(analytics, observer, resolved);
  }

  // ─ internal ─
  static Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (!status.isGranted) { await Permission.notification.request(); }
  }

  static Future<void> _prepareAndRegisterFcmToken(
    String baseUrl,
    bool forceRefreshToken,
  ) async {
    final fcm = FirebaseMessaging.instance;

    if (forceRefreshToken) {
      try { await fcm.deleteToken(); } catch (_) {}
    }

    final token = await fcm.getToken();
    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      await _registerTokenToServer(baseUrl, token);
    }

    fcm.onTokenRefresh.listen((t) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', t);
      await _registerTokenToServer(baseUrl, t);
    });

    // 포그라운드/클릭 리스너: 필요 시 로직 확장
    FirebaseMessaging.onMessage.listen((_) {});
    FirebaseMessaging.onMessageOpenedApp.listen((_) {});
  }

  static Future<void> _registerTokenToServer(
    String baseUrl,
    String token,
  ) async {
    final url = Uri.parse('$baseUrl/api/v1/fcm/register');
    try {
      // TODO: userId는 로그인 연동 후 교체
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': 'user9999', 'token': token}),
      );
    } catch (_) {
      // 네트워크 예외는 조용히 처리(정책에 따라 재시도 구현 가능)
    }
  }
}
