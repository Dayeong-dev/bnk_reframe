import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:reframe/app/app_shell.dart';
import 'package:http/http.dart' as http;
import 'package:reframe/pages/auth/auth_store.dart';

import '../../constants/api_constants.dart';

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
    final refreshToken = await _secureStorage.read(key: "refreshToken");
    final biometricEnabled = await _secureStorage.read(key: "biometricEnabled");

    // if (refreshToken != null && biometricEnabled == 'true') {
    //   final didAuthenticate = await _auth.authenticate(
    //     localizedReason: "생체 인증으로 로그인하세요.",
    //   );
    //
    //   if (didAuthenticate) {
    //     Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AppShell()));
    //     return;
    //   }
    // }

    if (refreshToken != null) {
      Uri url = Uri.parse("$apiBaseUrl/mobile/auth/refresh");

      final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refreshToken': refreshToken
        })
      );

      if(response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];

        // Memory(전역변수)에 Access Token 저장
        setAccessToken(accessToken);
        // Secure Storage에 Refresh Token 저장
        await _secureStorage.write(key: "refreshToken", value: refreshToken);

        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AppShell()));

        return;
      }
    }

    Navigator.pushReplacementNamed(context, '/login');

    if (!mounted) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
