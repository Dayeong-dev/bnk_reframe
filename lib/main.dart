// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'package:reframe/constants/color.dart';
import 'package:reframe/pages/auth/join_page.dart';
import 'package:reframe/pages/auth/login_page.dart';
import 'package:reframe/pages/auth/splash_page.dart';
import 'package:reframe/pages/branch/map_page.dart';
import 'package:reframe/pages/customer/more_page.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/pages/enroll/enroll_first.dart';
import 'package:reframe/pages/enroll/enroll_second.dart';
import 'package:reframe/pages/home_page.dart';
import 'package:reframe/pages/walk/step_debug_page.dart';
import 'package:reframe/service/firebase_service.dart';
import 'package:reframe/pages/chat/bnk_chat_page.dart';

// ── 운세 이벤트: Firebase/딥링크/페이지들 ────────────────────────────────
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event/service/fortune_auth_service.dart';
import 'event/service/deep_link_service.dart';
import 'event/pages/start_page.dart';
import 'event/pages/coupons_page.dart';

// ── Savings 테스트 페이지 ────────────────────────────────────────────────
import 'package:reframe/pages/savings_test/screens/start_screen.dart';
import 'package:reframe/pages/savings_test/screens/question_screen.dart';
import 'package:reframe/pages/savings_test/screens/result_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'event/core/live_coupon_announcer.dart';

// ✅ 기존 전역 네비게이터 키 (api_interceptor가 import함)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ko_KR', null);

  await FlutterNaverMap().init(
    clientId: '1vyye633d9',
    onAuthFailed: (e) => debugPrint('❌ 지도 인증 실패: $e'),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await FortuneAuthService.ensureSignedIn();
    debugPrint('✅ 익명 로그인 보장 완료');
  } catch (e, st) {
    debugPrint('🔥 익명 로그인 실패: $e\n$st');
  }

  final firebaseService = await FirebaseService.init(forceRefreshToken: true);

  runApp(MyApp(firebaseService: firebaseService));

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await LiveCouponAnnouncer.I.start();
    } catch (e) {
      debugPrint('⚠️ LiveCouponAnnouncer start failed: $e');
    }
  });

}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.firebaseService});
  final FirebaseService firebaseService;

  @override
  Widget build(BuildContext context) {
    return DeepLinkBootstrapper(
      child: MaterialApp(
        // ✅ 루트 네비게이터에 전역 키 장착 (api_interceptor가 여기 컨텍스트를 씀)
        navigatorKey: navigatorKey,
        title: "BNK 부산은행",
        debugShowCheckedModeBanner: false,
        navigatorObservers: firebaseService.observers,

        home: SplashPage(),
        routes: {
          "/home": (context) => const HomePage(),
          "/join": (context) => const JoinPage(),
          "/login": (context) => const LoginPage(),
          "/depositList": (context) => const DepositListPage(),
          "/depositMain": (context) => DepositMainPage(),
          "/step-debug": (context) => StepDebugPage(),
          "/chat-debug": (context) => BnkChatScreen(),
          "/more-page": (context) => MorePage(),
          '/map': (context) => const MapPage(),
          // Savings 테스트 라우트
          '/savings/start': (_) => const StartScreen(),
          '/savings/question': (_) => const QuestionScreen(),
          '/savings/result': (_) => const ResultScreen(),

          // 운세 이벤트 라우트
          '/event/fortune': (_) => const StartPage(),
          '/event/coupons': (_) => const CouponsPage(stampCount: 0),
        },
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: const ColorScheme.light(
            primary: primaryColor,
            surface: Colors.white,
            background: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 앱 전역 딥링크 초기화/라우팅 부트스트랩퍼
class DeepLinkBootstrapper extends StatefulWidget {
  const DeepLinkBootstrapper({super.key, required this.child});
  final Widget child;

  @override
  State<DeepLinkBootstrapper> createState() => _DeepLinkBootstrapperState();
}

class _DeepLinkBootstrapperState extends State<DeepLinkBootstrapper> {
  final _deepLinks = DeepLinkService();
  bool _navigatedFromLink = false;

  @override
  void initState() {
    super.initState();

    _deepLinks.init((uri) async {
      final me = await FortuneAuthService.ensureSignedIn();

      final inviter = uri.queryParameters['inviter'];
      final code = uri.queryParameters['code'] ?? uri.queryParameters['inviteCode'];
      final inviterOrCode = inviter ?? code;

      if (!_navigatedFromLink) {
        _navigatedFromLink = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = navigatorKey.currentState;
          if (nav == null) return;
          nav.push(
            MaterialPageRoute(
              builder: (_) => const StartPage(),
              settings: RouteSettings(
                name: '/event/fortune',
                arguments: {
                  'fromDeepLink': true,
                  'inviter': inviterOrCode,
                  'raw': uri.toString(),
                  'me': me,
                },
              ),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _deepLinks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
