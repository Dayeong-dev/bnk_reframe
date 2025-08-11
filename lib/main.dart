import 'package:flutter/material.dart';
import 'package:reframe/pages/auth/join_page.dart';
import 'package:reframe/pages/auth/login_page.dart';
import 'package:reframe/pages/auth/splash_page.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/pages/home_page.dart';
import 'package:reframe/pages/walk/step_debug_page.dart';
import 'package:reframe/pages/chat/bnk_chat_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "BNK 부산은행",
      debugShowCheckedModeBanner: false,
      home: SplashPage(),
      routes: {
        "/home": (context) => const HomePage(),
        "/join": (context) => const JoinPage(),
        "/login": (context) => const LoginPage(),

        // ✅ 예적금 테스트용 페이지 라우트
        "/depositList": (context) => DepositListPage(),
        "/depositMain": (context) => DepositMainPage(),
        "/step-debug": (context) => StepDebugPage(),
        "/chat-debug": (context) => BnkChatPage(),
      },
    );
  }
}
