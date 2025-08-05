import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:reframe/constants/api_constants.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _secureStorage = FlutterSecureStorage();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _login() async {
    const url = "$apiBaseUrl/api/auth/signin";

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
      }),
    );

    if(response.statusCode == 200) {
      final data = json.decode(response.body);
      final username = data['username'];

      // Secure Storage에 저장
      _secureStorage.write(key: "username", value: username);
      Navigator.pushReplacementNamed(context, "/main");

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("로그인 성공"))
      );

      Navigator.pushReplacementNamed(context, '/home');

    } else if(response.statusCode == 401) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("아이디 또는 비밀번호가 잘못되었습니다. "))
      );

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("로그인 오류"))
      );
    }

    setState(() => _isLoading = false);

    return;
  }

  @override
  void dispose() {  // 현재 위젯이 화면에서 사라질 때 호출
    super.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('로그인'),
        centerTitle: true,
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: '아이디',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    return value == null || value.isEmpty ? '아이디를 입력하세요' : null;
                  }
              ),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    return value == null || value.isEmpty ? '비밀번호를 입력하세요' : null;
                  }
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
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
            ],
          ),
        ),
      ),
    );
  }
}
