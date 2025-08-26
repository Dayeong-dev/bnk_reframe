import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:reframe/app/app_shell.dart';
import 'package:reframe/constants/api_constants.dart';
import 'package:reframe/pages/auth/auth_store.dart';
import 'package:reframe/pages/auth/join_page.dart';

import '../../common/biometric_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ===== 스타일 토큰 =====
  static const _brand = Color(0xFF2962FF);
  static const _border = Color(0xFFE6EAF0);
  static const _hint = Colors.black38;

  final _secureStorage = const FlutterSecureStorage();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _idFocus = FocusNode();
  final FocusNode _pwFocus = FocusNode();

  String? _error; // 에러 텍스트
  bool _isLoading = false;
  bool _isButtonEnabled = false;
  bool _obscurePw = true;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_checkInput);
    _passwordController.addListener(_checkInput);
  }

  void _checkInput() {
    final hasInput = _usernameController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;

    if (_error != null) {
      setState(() => _error = null);
    }
    if (_isButtonEnabled != hasInput) {
      setState(() => _isButtonEnabled = hasInput);
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty) {
      setState(() => _error = '아이디를 입력해주세요.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = '비밀번호를 입력해주세요.');
      return;
    }

    try {
      final url = "$apiBaseUrl/mobile/auth/signin";
      setState(() => _isLoading = true);

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 8)); // 8초 제한

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];

        // 메모리에 AccessToken 저장
        setAccessToken(accessToken);
        // Secure Storage에 RefreshToken 저장
        await _secureStorage.write(key: "refreshToken", value: refreshToken);

        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("로그인 성공")));

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppShell()),
        );

        await _maybeOfferEnableBiometric();

      } else if (response.statusCode == 401) {
        if (!mounted) return;
        setState(() => _error = '아이디 또는 비밀번호가 잘못되었습니다.');
      } else {
        if (!mounted) return;
        setState(() => _error = '로그인 오류');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '로그인 오류');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _maybeOfferEnableBiometric() async {
    final secure = _secureStorage;
    final already = await secure.read(key: 'biometricEnabled');
    if (already == 'true') return; // 이미 ON

    final supported = await BiometricAuth.isSupportedAndEnrolled();
    if (!supported) return; // 미지원/미등록 → 제안 안함

    if (!mounted) return;
    final agree = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 외부 클릭 닫힘 방지
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // 둥근 모서리
          ),
          backgroundColor: Colors.white, // 배경색
          title: Center(
            child: Text(
              '생체로 자동 로그인 보호',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B0D12),
              ),
              textAlign: TextAlign.center, // 혹시 모를 줄바꿈 대비
            ),
          ),
          content: const Text(
            '앱 실행 시 생체인증으로\n자동 로그인을 보호할까요?',
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly, // 버튼 정렬
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
                textStyle: const TextStyle(fontSize: 15),
              ),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3182F6), // Toss 블루 같은 포인트 컬러
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: const Text('켜기'),
            ),
          ],
        );
      },
    );


    if (agree == true) {
      final ok = await BiometricAuth.authenticate('생체 인증으로 자동로그인을 보호합니다');
      if (ok) {
        await secure.write(key: 'biometricEnabled', value: 'true');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('생체 인증 보호가 켜졌습니다')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _idFocus.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets; // 키보드 높이 포함
    final viewportHeight = mq.size.height - viewInsets.bottom; // 키보드만큼 뺀 화면 높이

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // ✅ 자동 이중 밀기 방지
      body: MediaQuery.removePadding( // ✅ SafeArea 하단 패딩 제거 (이중여백 방지)
        context: context,
        removeBottom: true,
        child: SafeArea(
          top: true,
          bottom: false,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              // 스크롤 컨텐츠가 최소한 '키보드 제외한 화면 높이'를 채우게 함
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewportHeight),
                child: Align(
                  alignment: Alignment.topCenter, // ✅ Center 대신 상단 정렬
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 0),
                          Image.asset(
                            "assets/images/logo/logo_small.png",
                            width: 220,
                            fit: BoxFit.contain,
                          ),
                          Text(
                            '예적금/자산 기능을 이용하려면 로그인해주세요.',
                            style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.6)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),

                          // 아이디
                          _buildTextField(
                            controller: _usernameController,
                            hintText: '아이디를 입력하세요.',
                            focusNode: _idFocus,
                            prefix: const Icon(Icons.person_outline, size: 20),
                            onFieldSubmitted: (_) => _pwFocus.requestFocus(),
                          ),
                          const SizedBox(height: 12),

                          // 비밀번호
                          _buildTextField(
                            controller: _passwordController,
                            hintText: '비밀번호를 입력하세요.',
                            focusNode: _pwFocus,
                            obscureText: _obscurePw,
                            prefix: const Icon(Icons.lock_outline, size: 20),
                            onFieldSubmitted: (_) =>
                            (_isButtonEnabled && !_isLoading) ? _login() : null,
                          ),
                          const SizedBox(height: 10),

                          // 에러 배너(있을 때만)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: (_error == null || _error!.isEmpty)
                                ? const SizedBox(height: 0)
                                : Container(
                              key: const ValueKey('error'),
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F1),
                                border:
                                Border.all(color: const Color(0xFFFFD5D5)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline,
                                      size: 18, color: Color(0xFFD32F2F)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.2,
                                          color: Color(0xFFD32F2F)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // 로그인 버튼
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                              (_isButtonEnabled && !_isLoading) ? _login : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isButtonEnabled
                                    ? _brand
                                    : const Color(0xFFBFC7D5),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFFE6EAF0),
                                disabledForegroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                '로그인',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 하단 링크
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '아직 계정이 없으신가요?',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context, rootNavigator: true).push(
                                    MaterialPageRoute(
                                        builder: (_) => const JoinPage()),
                                  );
                                },
                                child: const Text(
                                  "회원가입",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              )
                            ],
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===== 공통 입력 박스 =====
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    FocusNode? focusNode,
    bool obscureText = false,
    void Function(String)? onFieldSubmitted,
    Widget? prefix,
    Widget? suffix,
  }) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        onFieldSubmitted: onFieldSubmitted,
        textInputAction: onFieldSubmitted == null
            ? TextInputAction.done
            : TextInputAction.next,
        decoration: InputDecoration(
          prefixIcon: prefix == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
                  child: prefix,
                ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: suffix,
          hintText: hintText,
          hintStyle: const TextStyle(color: _hint),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _brand, width: 1.4),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _brand, width: 1.4),
          ),
        ),
      ),
    );
  }
}
