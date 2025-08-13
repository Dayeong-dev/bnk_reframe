// lib/service/firebase_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart'; // ✅ 공식 옵저버
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';

// 백그라운드 수신 핸들러
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// (보조) 커스텀 라우트 옵저버
class AnalyticsRouteObserver extends NavigatorObserver {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> _log(Route<dynamic>? route) async {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) {
      // screenClass도 함께 넣어주면 더 깔끔
      await _analytics.logScreenView(
        screenName: name,
        screenClass: route.runtimeType.toString(),
      );
    }
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _log(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    _log(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _log(previousRoute);
    super.didPop(route, previousRoute);
  }
}

class FirebaseService {
  FirebaseService._(
    this.analytics,
    this.analyticsObserver,
    this.routeObserver,
    this._baseUrl,
  );

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver analyticsObserver; // ✅ 공식
  final AnalyticsRouteObserver routeObserver;        // ✅ 보조(백업)
  final String _baseUrl;

  /// 실습용 고정 서버 IP
  static String get defaultBaseUrl => 'http://localhost:8080';

  /// 외부에서 Navigator에 바로 붙일 수 있게 제공
  List<NavigatorObserver> get observers => [analyticsObserver, routeObserver];

  /// main()에서 한 번만 호출
  static Future<FirebaseService> init({
    String? baseUrl,
    bool forceRefreshToken = true,
  }) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _requestNotificationPermission();

    final resolved = baseUrl ?? defaultBaseUrl;
    await _prepareAndRegisterFcmToken(resolved, forceRefreshToken);

    final analytics = FirebaseAnalytics.instance;
    final analyticsObs = FirebaseAnalyticsObserver(analytics: analytics); // ✅
    final routeObs = AnalyticsRouteObserver();

    return FirebaseService._(analytics, analyticsObs, routeObs, resolved);
  }

  // ─ internal ─
  static Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
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

    FirebaseMessaging.onMessage.listen((_) {});
    FirebaseMessaging.onMessageOpenedApp.listen((_) {});
  }

  static Future<void> _registerTokenToServer(
    String baseUrl,
    String token,
  ) async {
    final url = Uri.parse('$baseUrl/api/v1/fcm/register');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': 'user9999', 'token': token}),
      );
    } catch (_) {
      // 네트워크 예외는 조용히 처리
    }
  }
}
