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

import 'package:reframe/pages/savings_test/screens/start_screen.dart';
import 'package:reframe/pages/savings_test/screens/question_screen.dart';
import 'package:reframe/pages/savings_test/screens/result_screen.dart';
import 'package:reframe/pages/deposit/deposit_detail_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 1) 네이버 지도 SDK 초기화 (앱에서 1회만)
  await FlutterNaverMap().init(
    clientId:
        '1vyye633d9', // 네이버 지도 Client ID (iOS는 Info.plist의 NMFClientId도 필요)
    onAuthFailed: (e) => debugPrint('❌ 지도 인증 실패: $e'),
  );

  final firebaseService = await FirebaseService.init(
    baseUrl: FirebaseService.defaultBaseUrl,
    forceRefreshToken: true,
  );

  runApp(MyApp(firebaseService: firebaseService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.firebaseService});
  final FirebaseService firebaseService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: "BNK 부산은행",
      debugShowCheckedModeBanner: false,

      // ✅ 공식 + 보조 옵저버를 한 번에 연결
      navigatorObservers: firebaseService.observers,

      home: SplashPage(),
      routes: {
        "/home": (context) => const HomePage(),
        "/join": (context) => const JoinPage(),
        "/login": (context) => const LoginPage(),

        "/depositList": (context) => const DepositListPage(), // ← 이름으로 집계
        "/depositMain": (context) => DepositMainPage(),
        "/step-debug": (context) => StepDebugPage(),
        "/chat-debug": (context) => BnkChatPage(),
        "/more-page": (context) => MorePage(),
        '/map': (context) => const MapPage(),
        "/enroll-first": (context) => FirstStepPage(),
        "/enroll-second": (context) => SecondStepPage()
        '/savings/start':   (_) => const StartScreen(),
        '/savings/question':(_) => const QuestionScreen(),
        '/savings/result':  (_) => const ResultScreen(),
        //'/fortune':   (_) => const FortunePage(),
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,        // 각 화면 기본 배경
        colorScheme: const ColorScheme.light(         // M3에서 표면색도 흰색으로
          primary: primaryColor,
          surface: Colors.white,
          background: Colors.white,
        ),
        appBarTheme: const AppBarTheme(               // AppBar도 완전 흰색
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.transparent,       // M3 틴트로 회색 끼 도는 것 방지
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
