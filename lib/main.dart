import 'package:flutter/material.dart';
import 'package:reframe/app/app_shell.dart';
import 'package:reframe/pages/auth/join_page.dart';
import 'package:reframe/pages/auth/login_page.dart';
import 'package:reframe/pages/auth/splash_page.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/pages/home_page.dart';
import 'package:reframe/pages/walk/step_debug_page.dart';
import 'package:reframe/service/firebase_service.dart';
import 'package:reframe/pages/savings_test/saving_test_page.dart';
import 'package:reframe/pages/chat/bnk_chat_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase/FCM/Analytics 초기화 (필수만)
  final firebaseService = await FirebaseService.init(
    baseUrl: FirebaseService.defaultBaseUrl, // 필요 시 운영/개발 분리
    forceRefreshToken: true,                 // 패키지/프로젝트 이관 직후 권장
  );

  runApp(MyApp(firebaseService: firebaseService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.firebaseService});
  final FirebaseService firebaseService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "BNK 부산은행",  
      debugShowCheckedModeBanner: false,

       // 화면 전환 자동 추적 (Analytics)
      navigatorObservers: [firebaseService.routeObserver],

      home: SplashPage(),
      routes: {
        "/home": (context) => const HomePage(),
        "/join": (context) => const JoinPage(),
        "/login": (context) => const LoginPage(),

        // ✅ 예적금 테스트용 페이지 라우트
        "/depositList": (context) => DepositListPage(),
        "/depositMain": (context) => DepositMainPage(),
        "/step-debug": (context) => StepDebugPage(),
        "/savings": (context) => SavingsTestPage(), 
        "/chat-debug": (context) => BnkChatPage(),
      },
    );
  }
}
