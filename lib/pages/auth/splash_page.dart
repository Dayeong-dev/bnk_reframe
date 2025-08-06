import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final _secureStorage = FlutterSecureStorage();
  final _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 현재 프레임의 모든 위젯이 렌더링된 이후에 실행
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    final username = await _secureStorage.read(key: "username");
    final biometricEnabled = await _secureStorage.read(key: "biometricEnabled");

    if (username != null && biometricEnabled == 'true') {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: "생체 인증으로 로그인하세요.",
      );

      if (didAuthenticate) {
        Navigator.pushReplacementNamed(context, "/home");
        return;
      }
    }
    // Navigator.pushReplacementNamed(context, "/login");
    Navigator.pushReplacementNamed(context, "/home");

    if (!mounted) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
