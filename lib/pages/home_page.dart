// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

// 필요 페이지들 직접 import (위젯 push용)
import 'package:reframe/event/pages/fortune_hub_page.dart';
import 'package:reframe/pages/chat/bnk_chat_page.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/pages/savings_test/screens/start_screen.dart';
import 'package:reframe/pages/walk/step_debug_page.dart';
// TODO: 저축성향/챗봇 페이지가 있다면 여기 import 해주세요.
// import 'package:reframe/pages/savings/savings_start_page.dart';
// import 'package:reframe/pages/chat/bnk_chat_page.dart';

import 'auth/splash_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _secureStorage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricSupport();
    });
  }

  Future<void> _checkBiometricSupport() async {
    final canCheckBiometrics = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    final available = await _auth.getAvailableBiometrics();
    final alreadyEnabled = await _secureStorage.read(key: 'biometricEnabled');

    if (canCheckBiometrics &&
        isSupported &&
        available.isNotEmpty &&
        alreadyEnabled == null) {
      _showBiometricRegisterDialog();
    }
  }

  void _showBiometricRegisterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("생체 인증 등록"),
        content: const Text("다음 로그인부터 생체 인증을 사용하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("아니요"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final didAuthenticate = await _auth.authenticate(
                localizedReason: "생체 인증 등록",
              );
              if (!mounted) return;
              if (didAuthenticate) {
                await _secureStorage.write(
                  key: 'biometricEnabled',
                  value: 'true',
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("생체 인증이 등록되었습니다.")),
                );
              }
            },
            child: const Text("네"),
          ),
        ],
      ),
    );
  }

  Future<void> _initSecureStorage() async {
    await _secureStorage.deleteAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Secure Storage를 지웠습니다.")));
  }

  // ✅ 탭 내부 네비게이터로 push (하단바 유지)
  Future<T?> _push<T>(Widget page) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("메인 화면"),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _initSecureStorage,
                child: const Text("Secure Storage 초기화"),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // Splash는 대체 이동 유지
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SplashPage()),
                  );
                },
                child: const Text("Splash 화면으로 이동"),
              ),
              const Divider(height: 28),

              // ✅ 예적금: 위젯 직접 push (Named route 사용 X)
              ElevatedButton(
                onPressed: () => _push(const DepositListPage()),
                child: const Text("예적금 전체 목록"),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _push(DepositMainPage()),
                child: const Text("예적금 메인 페이지"),
              ),

              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _push(const StepDebugPage()),
                child: const Text("걸음 수 테스트"),
              ),

              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _push(const FortuneHubPage()),
                child: const Text("운세 테스트"),
              ),

              // 👉 아래 두 개는 실제 페이지 위젯 이름으로 바꿔서 _push(...) 하세요.
              ElevatedButton(
                onPressed: () => _push(const StartScreen()),
                child: const Text("저축성향 테스트"),
              ),
              ElevatedButton(
                onPressed: () => _push(const BnkChatPage()),
                child: const Text("챗봇 테스트"),
              ),

              const SizedBox(height: 8),
              // (임시로 네임드 라우트를 꼭 써야 한다면 루트 네비 사용 — 하단바는 안 보일 수 있음)
              // ElevatedButton(
              //   onPressed: () => Navigator.of(context, rootNavigator: true)
              //       .pushNamed("/chat-debug"),
              //   child: const Text("챗봇 테스트(루트 네비로)"),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
