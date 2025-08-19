import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:reframe/app/app_shell.dart';
import 'package:reframe/constants/api_constants.dart';
import 'package:reframe/pages/auth/auth_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _secureStorage = FlutterSecureStorage();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _idFocus = FocusNode();
  final FocusNode _pwFocus = FocusNode();

  String? _error;   // 에러 텍스트
  bool _isLoading = false;
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_checkInput);
    _passwordController.addListener(_checkInput);
  }

                                                                                                                  void _checkInput() {
    final hasInput = _usernameController.text.trim().isNotEmpty && _passwordController.text.trim().isNotEmpty;

    if(_error != null) {
      setState(() {
        _error = null;
      });
    }

    if(_isButtonEnabled != hasInput) {
      setState(() {
        _isButtonEnabled = hasInput;
      });
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if(username.isEmpty) {
      setState(() {
        _error = '아이디를 입력해주세요.';
      });
      return;
    }

    if(password.isEmpty) {
      setState(() {
        _error = '비밀번호를 입력해주세요.';
      });
      return;
    }

    try {
      final url = "$apiBaseUrl/mobile/auth/signin";

      setState(() => _isLoading = true);

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(Duration(seconds: 8));   // 8초 제한
      if(response.statusCode == 200) {
        final data = json.decode(response.body);

        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];

        // Memory(전역변수)에 Access Token 저장
        setAccessToken(accessToken);
        // Secure Storage에 Refresh Token 저장
        await _secureStorage.write(key: "refreshToken", value: refreshToken);

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("로그인 성공"))
        );

        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AppShell()));

      } else if(response.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          _error = '아이디 또는 비밀번호가 잘못되었습니다.';
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = '로그인 오류';
        });
      }
    } catch(e) {
      if (!mounted) return;
      setState(() {
        _error = '로그인 오류';
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

    return;
  }

  @override
  void dispose() {  // 현재 위젯이 화면에서 사라질 때 호출
    _usernameController.dispose();
    _passwordController.dispose();
    _idFocus.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(20),
        child: Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/images/logo/logo_small.png", width: 200,),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _usernameController,
                  hintText: '아이디를 입력하세요.',
                  focusNode: _idFocus,
                  onFieldSubmitted: (_) => _pwFocus.requestFocus()),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _passwordController,
                  hintText: '비밀번호를 입력하세요.',
                  focusNode: _pwFocus,
                  obscureText: true,
                  onFieldSubmitted: (_) => _isButtonEnabled ? _login() : null),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      _error != null ? 'ⓘ $_error' : '',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          height: 1.2
                      )
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_isButtonEnabled && !_isLoading) ? _login : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    )
                  ),
                  child: _isLoading ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ) : const Text('로그인'),
                ),
              ),
              TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/join');
                  },
                  child: Text(
                      "회원가입",
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          decoration: TextDecoration.underline
                      )
                  )
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    FocusNode? focusNode,
    bool obscureText = false,
    void Function(String)? onFieldSubmitted}) {

    return SizedBox(
      height: 48,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        onFieldSubmitted: onFieldSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.black38),
          isDense: true,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black12)
          ),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black12)
          ),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black)
          ),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black)
          ),
        ),
      ),
    );
  }
}
