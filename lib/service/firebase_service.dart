// lib/service/firebase_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart'; // FirebaseAnalyticsObserver
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';

/// ======================
/// Background message handler
/// ======================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // TODO: 필요 시 background 메시지 처리 로직 추가
}

/// ======================
/// (보조) 라우트 옵저버
/// ======================
class AnalyticsRouteObserver extends NavigatorObserver {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> _log(Route<dynamic>? route) async {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) {
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

/// ======================
/// FirebaseService
/// ======================
class FirebaseService {
  FirebaseService._(
    this.analytics,
    this.analyticsObserver,
    this.routeObserver,
    this._baseUrl,
  );

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver analyticsObserver; // 공식 옵저버
  final AnalyticsRouteObserver routeObserver; // 보조 옵저버
  final String _baseUrl;

  /// 실습/기본 서버
  static String get defaultBaseUrl => 'http://localhost:8080';

  /// Navigator에 그대로 연결할 옵저버들
  List<NavigatorObserver> get observers => [analyticsObserver, routeObserver];

  /// 앱 시작 시 1회만 호출
  static Future<FirebaseService> init({
    String? baseUrl,
    bool forceRefreshToken = true,
  }) async {
    // Firebase Core
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 메시징(백그라운드 핸들러)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 알림 권한 & iOS 전경 표시 옵션
    await _requestNotificationPermission();

    // APNs → FCM 토큰 준비 & 서버 등록
    final resolved = baseUrl ?? defaultBaseUrl;
    await _prepareAndRegisterFcmToken(resolved, forceRefreshToken);

    // Analytics
    final analytics = FirebaseAnalytics.instance;
    final analyticsObs = FirebaseAnalyticsObserver(analytics: analytics);
    final routeObs = AnalyticsRouteObserver();

    return FirebaseService._(analytics, analyticsObs, routeObs, resolved);
  }

  // ─────────────────────────────────────────────────────
  // Internal
  // ─────────────────────────────────────────────────────

  /// iOS/Android 알림 권한 요청 + iOS 전경 표시 옵션
  static Future<void> _requestNotificationPermission() async {
    final messaging = FirebaseMessaging.instance;

    // iOS/Android 13+ 권한 요청
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // iOS 전경 알림 표시 허용
    if (Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// iOS에서 APNs 토큰이 준비될 때까지 잠시 대기
  static Future<void> _waitForAPNsToken({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!Platform.isIOS) return; // Android/Web은 불필요

    final end = DateTime.now().add(timeout);
    String? apns;
    do {
      apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns != null && apns.isNotEmpty) return;
      await Future.delayed(const Duration(milliseconds: 250));
    } while (DateTime.now().isBefore(end));
    // 필요하면 타임아웃 로깅 추가
  }

  /// FCM 토큰 준비/저장/서버 등록 + onTokenRefresh 구독
  static Future<void> _prepareAndRegisterFcmToken(
    String baseUrl,
    bool forceRefreshToken,
  ) async {
    final fcm = FirebaseMessaging.instance;

    // iOS: APNs 토큰이 먼저 필요
    await _waitForAPNsToken();

    // 강제 토큰 재발급 옵션
    if (forceRefreshToken) {
      try {
        await fcm.deleteToken();
      } catch (_) {}
    }

    // FCM 토큰 요청
    String? token;
    try {
      token = await fcm.getToken();
    } catch (_) {
      token = null;
    }

    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      await _registerTokenToServer(baseUrl, token);
    }

    // 토큰 갱신 구독
    fcm.onTokenRefresh.listen((t) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', t);
      await _registerTokenToServer(baseUrl, t);
    });

    // 포그라운드/백그라운드 클릭 콜백 (필요 시 구현)
    FirebaseMessaging.onMessage.listen((RemoteMessage m) {
      // TODO: 앱 포그라운드 수신 처리
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
      // TODO: 알림 클릭으로 앱 오픈 처리
    });
  }

  /// 서버로 FCM 토큰 등록
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
      // 네트워크 예외는 조용히 무시
    }
  }
}
