// lib/service/firebase_service.dart
import 'dart:async'; // TimeoutException 등
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
  // 필요 시 background 메시지 처리
  debugPrint(
      '📨 [BG] title=${message.notification?.title}, data=${message.data}');
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
  );

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver analyticsObserver; // 공식 옵저버
  final AnalyticsRouteObserver routeObserver; // 보조 옵저버

  /// ✅ ADB reverse (tcp:8090) 기준 고정 URL
  /// - USB 연결된 실기기에서 `adb reverse tcp:8090 tcp:8090` 실행한 상태 가정
  /// - 앱은 항상 127.0.0.1:8090 로 요청 → PC의 8090 으로 역방향 포워딩
  static const String _BASE_URL = 'http://127.0.0.1:8090';

  /// Navigator에 그대로 연결할 옵저버들
  List<NavigatorObserver> get observers => [analyticsObserver, routeObserver];

  /// 앱 시작 시 1회만 호출
  static Future<FirebaseService> init({
    bool forceRefreshToken = false, // 기본: false
  }) async {
    // Firebase Core
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 메시징(백그라운드 핸들러)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 알림 권한 & iOS 전경 표시 옵션
    await _requestNotificationPermission();

    // FCM 토큰 준비/등록
    await _prepareAndRegisterFcmToken(forceRefreshToken);

    // Analytics
    final analytics = FirebaseAnalytics.instance;
    final analyticsObs = FirebaseAnalyticsObserver(analytics: analytics);
    final routeObs = AnalyticsRouteObserver();

    return FirebaseService._(analytics, analyticsObs, routeObs);
  }

  // ─────────────────────────────────────────────────────
  // Internal
  // ─────────────────────────────────────────────────────

  /// iOS/Android 알림 권한 요청 + iOS 전경 표시 옵션
  static Future<void> _requestNotificationPermission() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('🔔 [Permission] status=${settings.authorizationStatus}');

    // iOS 전경 알림 표시 허용
    if (Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('📣 [iOS] Foreground notification presentation enabled');
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
      if (apns != null && apns.isNotEmpty) {
        debugPrint('🪪 [iOS] APNs token ready (len=${apns.length})');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 250));
    } while (DateTime.now().isBefore(end));
    debugPrint('⏱️ [iOS] APNs token wait timeout');
  }

  /// 디버그용 토큰 마스킹
  static String _mask(String? s) {
    if (s == null || s.isEmpty) return 'null';
    final t = s.trim();
    if (t.length <= 12) return '***len=${t.length}';
    return '${t.substring(0, 6)}...${t.substring(t.length - 6)}(len=${t.length})';
  }

  /// FCM 토큰 준비/저장/서버 등록 + onTokenRefresh 구독
  static Future<void> _prepareAndRegisterFcmToken(
    bool forceRefreshToken,
  ) async {
    final fcm = FirebaseMessaging.instance;

    // iOS: APNs 토큰이 먼저 필요
    await _waitForAPNsToken();

    // onTokenRefresh는 먼저 구독(레이스 방지)
    fcm.onTokenRefresh.listen((t) async {
      final token = t.trim();
      debugPrint('♻️ [FCM] onTokenRefresh: ${_mask(token)}');
      final ok = await _registerTokenToServer(token);
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
      }
    });

    // (선택) 마이그레이션 등 특별한 경우에만 강제 재발급
    if (forceRefreshToken) {
      try {
        await fcm.deleteToken();
        debugPrint('🔁 [FCM] 기존 토큰 삭제 완료(강제 재발급 옵션)');
      } catch (e) {
        debugPrint('⚠️ [FCM] 토큰 삭제 실패: $e');
      }
    }

    // 최초 토큰
    String? token;
    try {
      token = await fcm.getToken();
      debugPrint('🔑 [FCM] getToken: ${_mask(token)}');
    } catch (e) {
      debugPrint('💥 [FCM] getToken 예외: $e');
    }

    if (token != null && token.isNotEmpty) {
      final ok = await _registerTokenToServer(token.trim());
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token.trim());
      }
    } else {
      debugPrint('⚠️ [FCM] 토큰이 null/빈값. 권한/네트워크/APNs 상태 확인 필요');
    }

    // 수신 로그(옵션)
    FirebaseMessaging.onMessage.listen((RemoteMessage m) {
      debugPrint(
          '📩 [FCM] onMessage title=${m.notification?.title} data=${m.data}');
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
      debugPrint('📬 [FCM] onMessageOpenedApp title=${m.notification?.title}');
    });
  }

  /// 서버로 FCM 토큰 등록 (성공/실패를 반환)
  static Future<bool> _registerTokenToServer(String token) async {
    final url = Uri.parse('$_BASE_URL/api/v1/fcm/register');
    try {
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': 'user0000', 'token': token}),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        debugPrint('✅ [FCM] token 등록 성공: ${_mask(token)}');
        return true;
      } else {
        debugPrint(
          '❌ [FCM] token 등록 실패 HTTP ${res.statusCode}: ${res.body} | token=${_mask(token)}',
        );
        return false;
      }
    } on SocketException catch (e) {
      debugPrint('🌐 [FCM] 네트워크 실패(Socket): $e | url=$url');
      return false;
    } on TimeoutException {
      debugPrint('⏱️ [FCM] 등록 타임아웃 | url=$url');
      return false;
    } catch (e) {
      debugPrint('💥 [FCM] 등록 예외: $e | url=$url');
      return false;
    }
  }
}
