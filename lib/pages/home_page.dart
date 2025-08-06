import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'auth/splash_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _secureStorage = FlutterSecureStorage();
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
            onPressed: () {
              Navigator.pop(context);
            },
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Secure Storage를 지웠습니다.")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("메인 화면"),
            ElevatedButton(
              onPressed: _initSecureStorage,
              child: Text("Secure Storage 초기화"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => SplashPage()),
                );
              },
              child: Text("Splash 화면으로 이동"),
            ),
            // ✅ 여기 예적금 버튼 2개 추가!
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, "/depositList"),
              child: Text("예적금 전체 목록"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, "/depositMain"),
              child: Text("예적금 메인 페이지"),
            ),
          ],
        ),
      ),
    );
  }
}
