import 'package:flutter/material.dart';
import 'package:reframe/pages/auth/join_page.dart';
import 'package:reframe/pages/auth/login_page.dart';
import 'package:reframe/pages/auth/splash_page.dart';
import 'package:reframe/pages/customer/more_page.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/pages/home_page.dart';
import 'package:reframe/pages/walk/step_debug_page.dart';
import 'package:reframe/service/firebase_service.dart';
import 'package:reframe/pages/savings_test/saving_test_page.dart';
import 'package:reframe/pages/chat/bnk_chat_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
        "/savings": (context) => SavingsTestPage(),
        "/chat-debug": (context) => BnkChatPage(),
        "/more-page": (context) => MorePage(),
      },
    );
  }
}
