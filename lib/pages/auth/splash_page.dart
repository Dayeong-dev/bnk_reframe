import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:reframe/app/app_shell.dart';
import 'package:http/http.dart' as http;
import 'package:reframe/pages/auth/auth_store.dart';
import 'package:reframe/pages/auth/login_page.dart';

import '../../constants/api_constants.dart';
import '../../common/biometric_auth.dart';

enum CheckResult { toLogin, toHome }

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const _minSplash = Duration(milliseconds: 800);
  final _secureStorage = FlutterSecureStorage();
  final _auth = LocalAuthentication();

  bool _routed = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 현재 프레임의 모든 위젯이 렌더링된 이후에 실행
      _startGate();
    });
  }

  Future<void> _startGate() async {
    final resultCheckLogin = _checkLoginStatus();
    final gated = await Future.wait([
      resultCheckLogin,
      Future.delayed(_minSplash),
    ]);

    final CheckResult checkResult = gated.first as CheckResult;

    if (!mounted) return;

    if (checkResult == CheckResult.toHome) {
      await _navigateOnce(MaterialPageRoute(builder: (context) => AppShell()));
    } else {
      await _navigateOnce(MaterialPageRoute(builder: (context) => LoginPage()));
    }
  }

  Future<CheckResult> _checkLoginStatus() async {
    try {
      final refreshToken = await _secureStorage.read(key: "refreshToken");
      final biometricEnabled =
          await _secureStorage.read(key: "biometricEnabled");

      if(refreshToken == null || refreshToken.isEmpty) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => LoginPage()));
        return CheckResult.toLogin;
      }

      Uri url = Uri.parse("$apiBaseUrl/mobile/auth/refresh");

      final response = await http
          .post(url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'refreshToken': refreshToken}))
          .timeout(const Duration(seconds: 8)); // 8초 제한

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final accessToken = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String;

        // Memory(전역변수)에 Access Token 저장
        setAccessToken(accessToken);
        // Secure Storage에 Refresh Token 저장
        await _secureStorage.write(key: "refreshToken", value: refreshToken);

        if(biometricEnabled == "true") {
          final didAuthenticate = await BiometricAuth.authenticate('자동 로그인을 위해 생체인증이 필요합니다');
          if (!didAuthenticate) return CheckResult.toLogin;
        }

        return CheckResult.toHome;
      } else {
        await _secureStorage.delete(key: "refreshToken");
        return CheckResult.toLogin;
      }
    } on TimeoutException {
      return CheckResult.toLogin;
    } catch (e) {
      await _secureStorage.delete(key: "refreshToken");
      return CheckResult.toLogin;
    }
  }

  // 단일 네비게이션 헬퍼(중복 호출 방지)
  Future<void> _navigateOnce(Route routeBuilder) async {
    if (!mounted || _routed) return;
    _routed = true;
    Navigator.of(context).pushAndRemoveUntil(routeBuilder, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset("assets/images/logo/logo_small.png", width: 200),
        SizedBox(height: 16),
        CircularProgressIndicator(color: Colors.black),
      ],
    )));
  }
}
