import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../constants/api_constants.dart';

class JoinPage extends StatefulWidget {
  const JoinPage({super.key});

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final _formKey = GlobalKey<FormState>();
  final _errorColor = Color(0xffd32f2f);

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController = TextEditingController();
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

  String? _gender = 'M'; // 'M' 또는 'F'
  bool _isLoading = false;

  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;   // null=미확인, true=가능, false=불가
  String _lastCheckedUsername = '';
  String? _errorUsernameText;

  @override
  void initState() {
    _usernameController.addListener(() {
      setState(() {
        _isUsernameAvailable = null;
        _lastCheckedUsername = '';
        _errorUsernameText = null;
      });
    });
    super.initState();
  }

  // 아이디 중복 검사
  Future<void> _checkUsername() async {
    final err = vUsername(_usernameController.text.trim());
    if(err != null) {
      setState(() {
        _isUsernameAvailable = null;
        _lastCheckedUsername = '';
        _errorUsernameText = err;
      });
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

      final response = await http.get(
        Uri.parse(url),
      ).timeout(Duration(seconds: 8));   // 8초 제한

      if(response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _isUsernameAvailable = true;
          _lastCheckedUsername = username;
        });
      } else if(response.statusCode == 409) {
        if (!mounted) return;
        setState(() => _errorUsernameText = '중복된 아이디 입니다.');
      } else {
        if (!mounted) return;
        setState(() => _errorUsernameText = '아이디 확인 중 오류가 발생했습니다.');
      }
    } catch(e) {
      if (!mounted) return;
      setState(() => _errorUsernameText = '아이디 확인 중 오류가 발생했습니다.');
    } finally {
      if (!mounted) return;
      setState(() => _isCheckingUsername = false);
    }

    return;
  }

  // 회원가입
  Future<void> _join() async {
    if(!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final birth = _birthController.text.trim();

    if(_isUsernameAvailable != true || _lastCheckedUsername != username) {
      setState(() => _errorUsernameText = '아이디 중복확인을 진행해주세요.');
      return;
    }

    try {
      final url = "$apiBaseUrl/mobile/auth/signup";

      setState(() => _isLoading = true);

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
          'name': name,
          'phone': phone,
          'email': email,
          'gender': _gender,
          'birth': birth,
        }),
      ).timeout(Duration(seconds: 8));   // 8초 제한
      if(response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("회원가입 성공"))
        );

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);

      } else {
        throw Exception("회원가입 오류");
      }
    } catch(e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("회원가입 중 오류가 발생했습니다. "))
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

    return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('회원가입'),
        centerTitle: true,
      ),
      body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '아이디',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextInput(
                              controller: _usernameController,
                              hintText: '아이디를 입력해주세요.',
                              errorText: _errorUsernameText,
                              helperText: (_isUsernameAvailable == true &&
                                  _lastCheckedUsername == _usernameController.text.trim()) ? '사용 가능한 아이디 입니다.' : null,
                              focusNode: _idFocus,
                              onFieldSubmitted: (_) => _pwFocus.requestFocus(),
                              validator: vUsername,
                            )
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isCheckingUsername ? null : _checkUsername,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              child: const Text('중복확인')
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    hintText: '비밀번호를 입력해주세요.',
                    labelText: '비밀번호',
                    focusNode: _pwFocus,
                    obscureText: true,
                    onFieldSubmitted: (_) => _pwChkFocus.requestFocus(),
                    validator: vPassword,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _passwordCheckController,
                    hintText: '비밀번호 확인을 입력해주세요.',
                    focusNode: _pwChkFocus,
                    obscureText: true,
                    onFieldSubmitted: (_) => _nameFocus.requestFocus(),
                    validator: (v) => vPasswordCheck(v, _passwordController.text),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _nameController,
                    hintText: '이름을 입력해주세요.',
                    labelText: '이름',
                    focusNode: _nameFocus,
                    onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                    validator: vName,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _phoneController,
                    hintText: '전화번호를 입력해주세요.',
                    labelText: '전화번호',
                    keyboardType: TextInputType.phone,
                    focusNode: _phoneFocus,
                    onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                    validator: vPhone,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _emailController,
                    hintText: '이메일을 입력해주세요.',
                    labelText: '이메일',
                    keyboardType: TextInputType.emailAddress,
                    focusNode: _emailFocus,
                    onFieldSubmitted: (_) => _birthFocus.requestFocus(),
                    validator: vEmail,
                  ),
                  const SizedBox(height: 20),
                  FormField<String>(
                    validator: (val) => (_gender == null && val == null) ? '성별을 선택해주세요.' : null,
                    builder: (state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '성별',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('남성'),
                                  value: 'M',
                                  groupValue: _gender,
                                  onChanged: (val) {
                                    setState(() {
                                      _gender = val;
                                      state.didChange(val);   // validator 연동
                                    });
                                  },
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('여성'),
                                  value: 'F',
                                  groupValue: _gender,
                                  onChanged: (val) {
                                    setState(() {
                                      _gender = val;
                                      state.didChange(val);   // validator 연동
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (state.hasError)
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                state.errorText!,
                                style: TextStyle(color: _errorColor, fontSize: 12),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _birthController,
                    hintText: '생년월일을 입력해주세요.(예: 20250101)',
                    labelText: '생년월일',
                    keyboardType: TextInputType.datetime,
                    focusNode: _birthFocus,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    onFieldSubmitted: (_) => _pwChkFocus.requestFocus(),
                    validator: vBirth,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                        onPressed: (_isLoading || _isCheckingUsername) ? null : _join,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        child: Text("회원가입"),
                    )
                  )
                ],
              ),
            ),
          )
      ),
    );
  }

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
    String? Function(String?)? validator}) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if(labelText != null) ...[
          Text(
            labelText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    String? errorText,
    String? helperText,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator}) {

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      focusNode: focusNode,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.black38),
        errorText: errorText,
        errorStyle: TextStyle(color: _errorColor, fontSize: 12),
        helperText: helperText,
        helperStyle: TextStyle(color: Colors.blueAccent, fontSize: 12),
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
    );
  }

  String? vUsername(String? v) {
    if (v == null || v.trim().isEmpty) return '아이디를 입력해주세요.';

    final s = v.trim();
    if (s.length < 5 || s.length > 20) return '아이디는 5~20자로 입력해주세요.';

    final hasLetter = RegExp(r'[a-z]').hasMatch(s);                // 영문
    final hasDigit = RegExp(r'\d').hasMatch(s);

    if (!hasLetter || !hasDigit) return '아이디는 소문자+숫자 조합만 가능합니다.';

    return null;
  }

  String? vPassword(String? v) {
    if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';

    final s = v.trim();
    if (s.length < 8 || s.length > 20) return '비밀번호는 8~20자로 입력해주세요.';

    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(s);                // 영문
    final hasDigit = RegExp(r'\d').hasMatch(s);                       // 숫자
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(s); // 특수문자

    if (!hasLetter || !hasDigit || !hasSpecial) return '영문, 숫자, 특수문자를 모두 포함해야 합니다.';

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
