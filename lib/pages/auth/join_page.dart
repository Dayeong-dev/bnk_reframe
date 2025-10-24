// lib/pages/auth/join_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:reframe/constants/color.dart';

import '../../constants/api_constants.dart';

class JoinPage extends StatefulWidget {
  const JoinPage({super.key});

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final _formKey = GlobalKey<FormState>();
  final _idFieldKey = GlobalKey<FormFieldState<String>>();

  // === 성별 버튼 컬러 (여기서 색 바꿔요) ===
  static const _selBg = Color(0xFFDCE7FF); // 선택됨 배경 (연한 파랑)
  static const _unSelBg = Colors.white; // 선택안됨 배경
  static const _selText = Colors.black87; // 선택됨 글자
  static const _unSelText = Colors.black54; // 선택안됨 글자
  static const _border = Color(0x22000000); // 테두리(옅은 회색)

  // ===== 컨트롤러 & 포커스 =====
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthController = TextEditingController();

  final FocusNode _idFocus = FocusNode();
  final FocusNode _pwFocus = FocusNode();
  final FocusNode _pwChkFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _birthFocus = FocusNode();

  // ===== 상태 =====
  String? _gender = 'M'; // 'M' | 'F'
  bool _isLoading = false;

  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable; // null=미확인, true=가능, false=불가
  String _lastCheckedUsername = '';
  String? _errorUsernameText;

  bool _pwVisible = false;
  bool _pwChkVisible = false;

  // 앱 톤 컬러(에러/헬퍼)
  final Color _errorColor = const Color(0xffd32f2f);
  final Color _helperColor = const Color(0xff1e88e5);

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(() {
      // 아이디 변경 시 중복확인 상태 초기화
      final username = _usernameController.text.trim();

      if(_lastCheckedUsername != username) {
        setState(() {
          _isUsernameAvailable = null;
          _lastCheckedUsername = '';
          _errorUsernameText = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordCheckController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _birthController.dispose();

    _idFocus.dispose();
    _pwFocus.dispose();
    _pwChkFocus.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _birthFocus.dispose();
    super.dispose();
  }

  // =========================
  // 아이디 중복 검사
  // =========================
  Future<void> _checkUsername() async {
    final err = vUsername(_usernameController.text.trim());
    if (err != null) {
      setState(() {
        _isUsernameAvailable = null;
        _lastCheckedUsername = '';
        _errorUsernameText = err;
      });
      _idFieldKey.currentState?.validate();
      return;
    }

    final username = _usernameController.text.trim();
    setState(() {
      _isCheckingUsername = true;
      _isUsernameAvailable = null;
      _errorUsernameText = null;
    });

    try {
      final url = "$apiBaseUrl/username/check?username=$username";
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _isUsernameAvailable = true;
          _lastCheckedUsername = username;
          _errorUsernameText = null;
        });
      } else if (response.statusCode == 409) {
        setState(() {
          _isUsernameAvailable = false;
          _lastCheckedUsername = username;
          _errorUsernameText = '중복된 아이디 입니다.';
        });
      } else {
        setState(() => _errorUsernameText = '아이디 확인 중 오류가 발생했습니다.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorUsernameText = '아이디 확인 중 오류가 발생했습니다.');
    } finally {
      if (!mounted) return;
      setState(() => _isCheckingUsername = false);
      _idFieldKey.currentState?.validate();
    }
  }

  // =========================
  // 회원가입
  // =========================
  Future<void> _join() async {
    // 1) 폼 검증
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (_isUsernameAvailable != true || _lastCheckedUsername != username) {
      // 아이디 확인 안 했거나, 확인 후 값이 바뀐 경우
      setState(() => _errorUsernameText = '아이디 중복확인을 진행해주세요.');
      // 아이디 영역으로 스크롤/포커스
      _idFocus.requestFocus();
      return;
    }

    final birthRaw = _birthController.text.trim(); // 19981209
    String? birthFormatted;
    if (birthRaw.length == 8) {
      birthFormatted =
      "${birthRaw.substring(0,4)}-${birthRaw.substring(4,6)}-${birthRaw.substring(6,8)}";
    } else {
      birthFormatted = birthRaw; // fallback
    }

    try {
      setState(() => _isLoading = true);
      final url = "$apiBaseUrl/mobile/auth/signup";

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': username,
              'password': password,
              'name': name,
              'phone': phone,
              'email': email,
              'gender': _gender,
              'birth': birthFormatted,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("회원가입 성공")),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        throw Exception("회원가입 오류");
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("회원가입 중 오류가 발생했습니다.")),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    // 바깥 탭 시 키보드 내리기
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('회원가입'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ===== 아이디 + 중복확인 =====
                    _Section(
                      title: '아이디',
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextInput(
                              fieldKey: _idFieldKey,
                              controller: _usernameController,
                              hintText: '아이디를 입력해주세요.',
                              errorText: _errorUsernameText,
                              helperText: (_isUsernameAvailable == true &&
                                      _lastCheckedUsername ==
                                          _usernameController.text.trim())
                                  ? '사용 가능한 아이디 입니다.'
                                  : null,
                              focusNode: _idFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _pwFocus.requestFocus(),
                              validator: vUsername,
                              suffix: _buildClearSuffix(_usernameController),
                              autofill: const [AutofillHints.newUsername],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: (_isCheckingUsername || _isLoading)
                                  ? null
                                  : _checkUsername,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.black12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: _isCheckingUsername
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.search),
                              label: const Text(
                                '중복확인',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== 비밀번호 =====
                    _Section(
                      title: '비밀번호',
                      child: Column(
                        children: [
                          _buildTextInput(
                            controller: _passwordController,
                            hintText: '비밀번호를 입력해주세요.',
                            focusNode: _pwFocus,
                            obscureText: !_pwVisible,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _pwChkFocus.requestFocus(),
                            validator: vPassword,
                            suffix: _buildPwToggle(
                              visible: _pwVisible,
                              onTap: () =>
                                  setState(() => _pwVisible = !_pwVisible),
                            ),
                            autofill: const [AutofillHints.newPassword],
                          ),
                          const SizedBox(height: 8),
                          _buildTextInput(
                            controller: _passwordCheckController,
                            hintText: '비밀번호 확인을 입력해주세요.',
                            focusNode: _pwChkFocus,
                            obscureText: !_pwChkVisible,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _nameFocus.requestFocus(),
                            validator: (v) =>
                                vPasswordCheck(v, _passwordController.text),
                            suffix: _buildPwToggle(
                              visible: _pwChkVisible,
                              onTap: () => setState(
                                  () => _pwChkVisible = !_pwChkVisible),
                            ),
                            autofill: const [AutofillHints.newPassword],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== 이름 / 전화번호 / 이메일 =====
                    _Section(
                      title: '기본정보',
                      child: Column(
                        children: [
                          _buildTextInput(
                            controller: _nameController,
                            hintText: '이름을 입력해주세요.',
                            labelText: '이름',
                            focusNode: _nameFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                            validator: vName,
                            suffix: _buildClearSuffix(_nameController),
                            autofill: const [AutofillHints.name],
                          ),
                          const SizedBox(height: 12),
                          _buildTextInput(
                            controller: _phoneController,
                            hintText: '전화번호를 입력해주세요.',
                            labelText: '전화번호',
                            keyboardType: TextInputType.phone,
                            focusNode: _phoneFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                            validator: vPhone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            suffix: _buildClearSuffix(_phoneController),
                            autofill: const [AutofillHints.telephoneNumber],
                          ),
                          const SizedBox(height: 12),
                          _buildTextInput(
                            controller: _emailController,
                            hintText: '이메일을 입력해주세요.',
                            labelText: '이메일',
                            keyboardType: TextInputType.emailAddress,
                            focusNode: _emailFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _birthFocus.requestFocus(),
                            validator: vEmail,
                            suffix: _buildClearSuffix(_emailController),
                            autofill: const [AutofillHints.email],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== 성별 (ChoiceChip) =====
                    // ===== 성별 (사진 스타일: 좌우 꽉 채운 알약 버튼) =====
                    _Section(
                      title: '성별',
                      child: Row(
                        children: [
                          // 남성
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _gender = 'M'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: (_gender == 'M') ? _selBg : _unSelBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _border),
                                ),
                                child: Text(
                                  '남',
                                  style: TextStyle(
                                    fontWeight: (_gender == 'M')
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: (_gender == 'M')
                                        ? _selText
                                        : _unSelText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 여성
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _gender = 'F'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: (_gender == 'F') ? _selBg : _unSelBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _border),
                                ),
                                child: Text(
                                  '여',
                                  style: TextStyle(
                                    fontWeight: (_gender == 'F')
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: (_gender == 'F')
                                        ? _selText
                                        : _unSelText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== 생년월일 =====
                    _Section(
                      title: '생년월일',
                      child: _buildTextInput(
                        controller: _birthController,
                        hintText: '생년월일을 입력해주세요.(예: 20250101)',
                        labelText: '생년월일',
                        keyboardType: TextInputType.datetime,
                        focusNode: _birthFocus,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).unfocus(),
                        validator: vBirth,
                        suffix: _buildClearSuffix(_birthController),
                        autofill: const [AutofillHints.birthday],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ===== CTA 버튼 =====
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed:
                            (_isLoading || _isCheckingUsername) ? null : _join,
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "회원가입",
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===== 공통 입력 래퍼 =====
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? labelText,
    String? errorText,
    String? helperText,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
        ],
        _buildTextInput(
          controller: controller,
          hintText: hintText,
          errorText: errorText,
          helperText: helperText,
          keyboardType: keyboardType,
          focusNode: focusNode,
          obscureText: obscureText,
          inputFormatters: inputFormatters,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
        )
      ],
    );
  }

  // ===== 실제 입력 필드 =====
  Widget _buildTextInput({
    Key? fieldKey,
    required TextEditingController controller,
    required String hintText,
    String? labelText,
    String? errorText,
    String? helperText,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
    Widget? suffix,
    List<String>? autofill,
    TextInputAction? textInputAction,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      focusNode: focusNode,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      textInputAction: textInputAction,
      autofillHints: autofill,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black38),
        errorText: errorText,
        errorStyle: TextStyle(color: _errorColor, fontSize: 12),
        helperText: helperText,
        helperStyle: TextStyle(color: _helperColor, fontSize: 12),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black),
        ),
      ),
    );
  }

  // ===== 유틸: 클리어 버튼 =====
  Widget _buildClearSuffix(TextEditingController c) {
    return (c.text.isEmpty)
        ? const SizedBox(width: 0, height: 0)
        : IconButton(
            onPressed: () {
              c.clear();
              setState(() {}); // suffix 갱신
            },
            icon: const Icon(Icons.close_rounded,
                size: 18, color: Colors.black38),
          );
  }

  // ===== 유틸: 비밀번호 토글 =====
  Widget _buildPwToggle({required bool visible, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        size: 18,
        color: Colors.black54,
      ),
    );
  }

  // =========================
  // 검증 로직 (네 기존 규칙 유지)
  // =========================
  String? vUsername(String? v) {
    if (v == null || v.trim().isEmpty) return '아이디를 입력해주세요.';
    final s = v.trim();
    if (s.length < 5 || s.length > 20) return '아이디는 5~20자로 입력해주세요.';
    final hasLetter = RegExp(r'[a-z]').hasMatch(s); // 영문(소문자)
    final hasDigit = RegExp(r'\d').hasMatch(s);
    if (!hasLetter || !hasDigit) return '아이디는 소문자+숫자 조합만 가능합니다.';
    return null;
  }

  String? vPassword(String? v) {
    if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
    final s = v.trim();
    if (s.length < 8 || s.length > 20) return '비밀번호는 8~20자로 입력해주세요.';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(s);
    final hasDigit = RegExp(r'\d').hasMatch(s);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(s);
    if (!hasLetter || !hasDigit || !hasSpecial) {
      return '영문, 숫자, 특수문자를 모두 포함해야 합니다.';
    }
    return null;
  }

  String? vPasswordCheck(String? v, String original) {
    if (v == null || v.isEmpty) return '비밀번호 확인을 입력해주세요.';
    if (v != original) return '비밀번호가 일치하지 않습니다.';
    return null;
  }

  String? vName(String? v) {
    if (v == null || v.isEmpty) return '이름을 입력해주세요.';
    return null;
  }

  String? vPhone(String? v) {
    if (v == null || v.trim().isEmpty) return '전화번호를 입력해주세요.';
    final s = v.replaceAll(RegExp(r'\D'), '');
    if (s.length < 10 || s.length > 11) return '전화번호는 10~11자리 숫자여야 합니다.';
    return null;
  }

  String? vEmail(String? v) {
    if (v == null || v.trim().isEmpty) return '이메일을 입력해주세요.';
    final s = v.trim();
    final reg = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!reg.hasMatch(s)) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  String? vBirth(String? v) {
    if (v == null || v.trim().isEmpty) return '생년월일을 입력해주세요.';
    final s = v.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(s)) return 'YYYYMMDD 형식으로 입력해주세요.';
    final y = int.parse(s.substring(0, 4));
    final m = int.parse(s.substring(4, 6));
    final d = int.parse(s.substring(6, 8));
    try {
      final dt = DateTime(y, m, d);
      if (dt.year != y || dt.month != m || dt.day != d) return '존재하지 않는 날짜입니다.';
      final now = DateTime.now();
      if (dt.isAfter(now)) return '미래 날짜는 입력할 수 없습니다.';
      if (y < 1900) return '1900년 이후의 연도를 입력해주세요.';
    } catch (_) {
      return '올바른 날짜를 입력해주세요.';
    }
    return null;
  }
}

// ===== 섹션 공통 위젯: 제목 + 본문 =====
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 타이틀(라벨)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        // 본문
        child,
      ],
    );
  }
}
