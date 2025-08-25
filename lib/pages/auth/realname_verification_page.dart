import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reframe/constants/color.dart';
import 'package:reframe/model/realname_verification.dart';
import 'package:reframe/service/verification_service.dart';

import '../../constants/api_constants.dart';
import '../enroll/pdf_view_page.dart';

class RealnameVerificationPage extends StatefulWidget {
  const RealnameVerificationPage({super.key});

  @override
  State<RealnameVerificationPage> createState() => _RealnameVerificationPageState();
}

class _RealnameVerificationPageState extends State<RealnameVerificationPage> {
  // ----- keys -----
  final _topFormKey = GlobalKey<FormState>();
  final _bottomFormKey = GlobalKey<FormState>();

// (이미 쓰고 있던 개별 필드 key가 있으면 그대로 둬도 됨)
  final _phoneFieldKey = GlobalKey<FormFieldState<String>>();
  final _carrierFieldKey = GlobalKey<FormFieldState<String>>(); // 드롭다운 사용 시

// ----- autovalidate (상/하 분리) -----
  AutovalidateMode _autoTop = AutovalidateMode.disabled;
  AutovalidateMode _autoBottom = AutovalidateMode.disabled;

  // ----- style -----
  final _errorColor = const Color(0xffd32f2f);

  // ----- controllers -----
  final _nameController = TextEditingController();
  final _rrnFrontController = TextEditingController(); // 앞 6자리
  final _rrnBackController = TextEditingController();  // 뒤 6자리
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  // ----- focus -----
  final _nameFocus = FocusNode();
  final _rrnFrontFocus = FocusNode();
  final _rrnBackFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();

  // ----- state -----
  String? _carrier; // 드롭다운 선택값
  bool _isSending = false;
  bool _isLoading = false;
  bool _sentOnce = false;

  // 약관
  bool get _agreedAll => items.where((c) => c.required).every((c) => c.viewed && c.checked);

  // 인증번호 전송 버튼 활성화 조건: 상단 5개 모두 유효
  bool get _canSendCode {
    final nameOk    = _nameController.text.trim().isNotEmpty;

    final front     = _rrnFrontController.text.replaceAll(RegExp(r'\D'), '');
    final back      = _rrnBackController.text.replaceAll(RegExp(r'\D'), '');
    final rrnOk     = front.length == 6 && back.length == 7;

    final carrierOk = _carrier != null && _carrier!.isNotEmpty;

    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final phoneOk     = phoneDigits.length >= 10 && phoneDigits.length <= 11;

    return nameOk && rrnOk && carrierOk && phoneOk;
  }

  List<ConsentItem> items = [
    ConsentItem(
      kind: ConsentKind.privacy,
      title: '[필수] 개인정보 수집·이용 동의서',
      pdfUrl: '$apiBaseUrl/uploads/common/개인정보수집이용동의.pdf',
      required: true,
    ),
    ConsentItem(
      kind: ConsentKind.privacy,
      title: '[필수] 개인정보 제공 동의서',
      pdfUrl: '$apiBaseUrl/uploads/common/개인정보제공동의.pdf',
      required: true,
    ),
    ConsentItem(
      kind: ConsentKind.identity,
      title: '[필수] 고유식별정보 처리 동의서',
      pdfUrl: '$apiBaseUrl/uploads/common/고유식별정보처리동의.pdf',
      required: true,
    ),
    ConsentItem(
      kind: ConsentKind.thirdParty,
      title: '[필수] 개인정보 제3자 제공 동의',
      pdfUrl: '$apiBaseUrl/uploads/common/개인(신용)정보 제3자 제공 동의서.pdf',
      required: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 상단 필드 변경 시 버튼/에러 갱신
    _nameController.addListener(() => setState(() {}));
    _rrnFrontController.addListener(() {
      setState(() {});
      // 앞 6자리 입력 완료되면 뒤 6자리로 포커스 이동
      if (_rrnFrontController.text.replaceAll(RegExp(r'\D'), '').length >= 6) {
        _rrnBackFocus.requestFocus();
      }
    });
    _rrnBackController.addListener(() {
      setState(() {});
      // 뒤 6자리 입력 완료되면 통신사 → 휴대폰으로 자연스럽게 이동
      if (_rrnBackController.text.replaceAll(RegExp(r'\D'), '').length >= 7) {
        _phoneFocus.requestFocus();
      }
    });
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rrnFrontController.dispose();
    _rrnBackController.dispose();
    _phoneController.dispose();
    _codeController.dispose();

    _nameFocus.dispose();
    _rrnFrontFocus.dispose();
    _rrnBackFocus.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  // ===== Actions =====
  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  RealnameVerification _buildForm() {
    return RealnameVerification(
      name: _nameController.text.trim(),
      rrnFront: _digits(_rrnFrontController.text),
      carrier: _carrier ?? '',
      phone: _digits(_phoneController.text),
    );
  }

  Future<void> _sendCode() async {
    // 상단 입력 에러를 바로 보이도록 전환
    setState(() => _autoTop = AutovalidateMode.always);

    // 드롭다운/전화번호는 키로 validate (필요 시)
    final carrierOk = _carrierFieldKey.currentState?.validate() ?? true; // 드롭다운 없으면 true
    final phoneOk   = _phoneFieldKey.currentState?.validate() ?? false;

    // 주민번호 통합 에러
    final rrnOk = vRrnCombined() == null;

    // 상단 폼의 다른 필드들 검사
    final topFormOk = _topFormKey.currentState?.validate() ?? false;

    if (!(topFormOk && rrnOk && carrierOk && phoneOk)) {
      _focusFirstError();
      return;
    }

    setState(() => _isSending = true);
    try {
      // (try 바깥에서 _isSending = true; 했다면 생략 가능)
      final code = await requestCode(_buildForm());

      if (!mounted) return;
      setState(() {
        _sentOnce = true;
        _autoBottom = AutovalidateMode.disabled;

        final isNumericCode = RegExp(r'^\d{4,6}$').hasMatch(code);
        _codeController.text = isNumericCode ? code : '';
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeFocus.requestFocus();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호를 전송했어요.')),
      );
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? '입력하신 정보가 잘못되었습니다.' : msg)),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    if (!_sentOnce) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 인증번호를 전송해 주세요.')),
      );
      return;
    }

    // 하단 폼 에러 보이도록 전환 + 검증
    setState(() => _autoBottom = AutovalidateMode.always);
    final bottomOk = _bottomFormKey.currentState?.validate() ?? false;

    // 상단(주민번호 통합 에러)도 안전하게 한 번 더 체크(선택)
    final rrnOk = vRrnCombined() == null;

    if (!bottomOk || !rrnOk) {
      _focusFirstError();
      return;
    }

    if (!_agreedAll) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 약관 3건을 모두 동의해 주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String inputCode = _codeController.text;
      bool result = await verifyCode(_buildForm(), inputCode);

      if (!mounted) return;
      if(result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('본인인증이 완료되었습니다.')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('본인인증에 실패하였습니다.')),
        );
      }
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본인인증에 실패하였습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _focusFirstError() {
    if (vName(_nameController.text) != null) { _nameFocus.requestFocus(); return; }
    if (vRrnFront(_rrnFrontController.text) != null) { _rrnFrontFocus.requestFocus(); return; }
    if (vRrnBack7(_rrnBackController.text) != null) { _rrnBackFocus.requestFocus(); return; }
    if ((_carrierFieldKey.currentState?.validate() ?? false) == false) { // 드롭다운
      // Dropdown은 포커스 이동이 어려우니 스낵바로 안내
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('통신사를 선택해주세요.')),
      );
      return;
    }
    if (vPhone(_phoneController.text) != null) { _phoneFocus.requestFocus(); return; }
    if (_sentOnce && vCode(_codeController.text) != null) { _codeFocus.requestFocus(); return; }
  }

  // ===== Validators =====

  String? vName(String? v) {
    if (v == null || v.trim().isEmpty) return '이름을 입력해주세요.';
    return null;
  }

  String? vRrnFront(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(s)) return '생년월일 6자리를 입력해주세요.';
    final mm = int.tryParse(s.substring(2, 4)) ?? 0;
    final dd = int.tryParse(s.substring(4, 6)) ?? 0;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return '올바른 날짜를 입력해주세요.';
    return null;
  }

  String? vRrnBack7(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\d{7}$').hasMatch(s)) return '뒷자리 7자리를 입력해주세요.';
    return null;
  }


  String? vCarrierSelected() {
    return (_carrier == null || _carrier!.isEmpty) ? '통신사를 선택해주세요.' : null;
  }

  String? vPhone(String? v) {
    if (v == null || v.trim().isEmpty) return '휴대폰 번호를 입력해주세요.';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 11) return '휴대폰 번호는 10~11자리 숫자입니다.';
    return null;
  }

  String? vCode(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '인증번호를 입력해주세요.';
    if (s.length < 4 || s.length > 6) return '인증번호 4~6자리를 입력해주세요.';
    if (!RegExp(r'^\d+$').hasMatch(s)) return '숫자만 입력해주세요.';
    return null;
  }

  // 주민번호 통합 에러 (Row 아래 한 줄로 표시)
  String? vRrnCombined() {
    final e1 = vRrnFront(_rrnFrontController.text);
    if (e1 != null) return e1;
    final e2 = vRrnBack7(_rrnBackController.text);
    return e2;
  }

  // ===== UI builders =====

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
    Key? fieldKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(labelText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
          fieldKey: fieldKey,
        ),
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
    String? Function(String?)? validator,
    Key? fieldKey,
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
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black38),
        errorText: errorText,
        errorStyle: TextStyle(color: _errorColor, fontSize: 12),
        errorMaxLines: 2,
        helperText: helperText,
        helperStyle: const TextStyle(color: Colors.blueAccent, fontSize: 12),
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
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

  // ===== Build =====

  @override
  Widget build(BuildContext context) {
    final rrnErr = (_autoTop == AutovalidateMode.always) ? vRrnCombined() : null;
    final sendDisabled = _isSending || !_canSendCode;

    return Scaffold(
      appBar: AppBar(title: const Text('본인인증'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [

              // ───── 상단 Form ─────
              Form(
                key: _topFormKey,
                autovalidateMode: _autoTop,
                child: Column(
                  children: [
                    // 이름
                    _buildTextField(
                      controller: _nameController,
                      hintText: '이름을 입력해주세요.',
                      labelText: '이름',
                      focusNode: _nameFocus,
                      onFieldSubmitted: (_) => _rrnFrontFocus.requestFocus(),
                      validator: vName,
                    ),
                    const SizedBox(height: 20),

                    // 주민등록번호 (앞6+뒤6) - 각 필드 validator는 null, 아래 한 줄에 통합 에러
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('주민등록번호', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextInput(
                                controller: _rrnFrontController,
                                hintText: '앞 6자리 (YYMMDD)',
                                keyboardType: TextInputType.number,
                                focusNode: _rrnFrontFocus,
                                onFieldSubmitted: (_) => _rrnBackFocus.requestFocus(),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                validator: null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const SizedBox(width: 14, child: Center(child: Text('-', style: TextStyle(fontSize: 18)))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextInput(
                                controller: _rrnBackController,
                                hintText: '뒤 7자리',
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                focusNode: _rrnBackFocus,
                                onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(7),
                                ],
                                validator: null,
                              ),
                            ),
                          ],
                        ),
                        if (rrnErr != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(rrnErr, style: TextStyle(color: _errorColor, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('휴대폰 번호', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),

                        Row(
                          children: [
                            // 통신사 드롭다운
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                key: _carrierFieldKey,
                                value: _carrier,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), // ⬅ 높이 통일
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.black12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.black),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.black12),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.black),
                                  ),
                                  errorStyle: TextStyle(color: _errorColor, fontSize: 12),
                                ),
                                hint: const Text('통신사 선택'),
                                items: const [
                                  DropdownMenuItem(value: 'SKT', child: Text('SKT')),
                                  DropdownMenuItem(value: 'KT', child: Text('KT')),
                                  DropdownMenuItem(value: 'LGU+', child: Text('LG U+')),
                                  DropdownMenuItem(value: '알뜰폰(SKT망)', child: Text('알뜰폰(SKT망)')),
                                  DropdownMenuItem(value: '알뜰폰(KT망)', child: Text('알뜰폰(KT망)')),
                                  DropdownMenuItem(value: '알뜰폰(LGU+망)', child: Text('알뜰폰(LGU+망)')),
                                  DropdownMenuItem(value: '기타', child: Text('기타')),
                                ],
                                onChanged: (val) {
                                  setState(() => _carrier = val);
                                  _phoneFocus.requestFocus();
                                },
                                validator: (_) => vCarrierSelected(),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // 휴대폰 입력
                            Expanded(
                              flex: 6,
                              child: _buildTextInput(
                                fieldKey: _phoneFieldKey,
                                controller: _phoneController,
                                hintText: '010-1234-5678',
                                keyboardType: TextInputType.phone,
                                focusNode: _phoneFocus,
                                onFieldSubmitted: (_) => _sendCode(),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                  KoreanPhoneNumberFormatter(),
                                ],
                                validator: vPhone,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 인증번호 전송 버튼 (가로 전체)
                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_isSending || !_canSendCode) ? null : _sendCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isSending
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('인증번호 전송'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ───── 하단 Form (전송 후 노출) ─────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _sentOnce
                    ? Form(
                  key: _bottomFormKey,
                  autovalidateMode: _autoBottom, // ✅ 초기에 disabled
                  child: Column(
                    key: const ValueKey('bottom'),
                    children: [
                      _buildTextField(
                        controller: _codeController,
                        hintText: '인증번호 4~6자리를 입력해주세요.',
                        labelText: '인증번호',
                        keyboardType: TextInputType.number,
                        focusNode: _codeFocus,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: vCode,
                      ),
                      const SizedBox(height: 20),

                      // 약관 (FormField → 하단 Form에 포함)
                      FormField<bool>(
                        validator: (_) => _agreedAll ? null : '필수 약관에 모두 동의해주세요.',
                        builder: (state) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('약관 동의(필수)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            // 약관 리스트
                            ...items.map((c) => _consentTile(
                              item: c,
                              onOpenPdf: () async {
                                if (c.pdfUrl == null || c.pdfUrl!.isEmpty) return;
                                final viewedOk = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PdfViewerPage(
                                      title: c.title.replaceFirst('[필수] ', ''),
                                      pdfUrl: c.pdfUrl!,
                                    ),
                                  ),
                                );

                                if (viewedOk == true) {
                                  setState(() {
                                    c.viewed = true;
                                    c.checked = true; // 열람 완료 시 자동 체크
                                  });
                                }
                              },
                            )),
                            if (state.hasError)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 4),
                                child: Text(state.errorText!,
                                    style: TextStyle(color: _errorColor, fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 다음
                      SizedBox(
                        width: double.infinity, height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              )
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('다음', style: TextStyle(color: Colors.white),),
                        ),
                      ),
                    ],
                  ),
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _consentTile({
    required ConsentItem item,
    required VoidCallback onOpenPdf,
  }) {
    final canTapCheckbox = !item.mustOpen; // mustOpen이면 직접 체크 불가

    return CheckboxListTile(
      value: item.checked,
      onChanged: canTapCheckbox ? (v) {
        setState(() {
          item.checked = v ?? false;
          if (!item.checked) item.viewed = false; // 해제 시 viewed도 초기화(선택)
        });
      } : null, // 직접 체크 비활성화
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          Expanded(child: Text(item.title, style: const TextStyle(fontSize: 14, color: Colors.black))),
          if (item.pdfUrl != null && item.pdfUrl!.isNotEmpty)
            TextButton(
              onPressed: onOpenPdf, // PDF 열람 버튼
              child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.black,),
            ),
        ],
      ),
    );
  }
}

/// 국내 휴대폰 번호 자동 포맷터
/// - 입력: 숫자만(최대 11자리)
/// - 표시: 010-1234-5678 (8자리 이상: 3-4-4), 4~7자리: 3-나머지
class KoreanPhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) digits = digits.substring(0, 11);

    String formatted;
    if (digits.length <= 3) {
      formatted = digits;
    } else if (digits.length <= 7) {
      // 3-나머지
      formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else {
      // 3-4-나머지
      formatted =
      '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }

    // 커서 위치 보정
    int nonDigitBefore = _nonDigitCountBefore(newValue.text, newValue.selection.baseOffset);
    int cursorPosition = (newValue.selection.baseOffset - nonDigitBefore).clamp(0, digits.length);
    // 하이픈 추가 후 커서 위치 재계산
    int adjusted = _mapDigitIndexToFormattedIndex(digits, cursorPosition);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: adjusted),
    );
  }

  int _nonDigitCountBefore(String text, int index) {
    int count = 0;
    for (int i = 0; i < index && i < text.length; i++) {
      if (!RegExp(r'\d').hasMatch(text[i])) count++;
    }
    return count;
  }

  int _mapDigitIndexToFormattedIndex(String digits, int digitIndex) {
    // digitIndex(0..len) -> formatted index considering hyphens
    if (digitIndex <= 3) return digitIndex;
    if (digits.length <= 3) return digitIndex;

    if (digits.length <= 7) {
      // pattern: 3-xxxx
      return digitIndex + 1; // one hyphen before
    }

    // pattern: 3-4-xxxx
    if (digitIndex <= 7) {
      return digitIndex + 1; // first hyphen only
    } else {
      return digitIndex + 2; // two hyphens
    }
  }
}

enum ConsentKind { privacy, identity, thirdParty }

class ConsentItem {
  final ConsentKind kind;
  final String title;
  final String? pdfUrl;
  final bool required;

  // 무조건 보고 넘어가야 하는지 (기본: true)
  final bool mustOpen;

  // 최소 열람 시간(초): 끝까지 스크롤 OR 이 초 경과 중 하나를 만족하면 통과
  final int minViewSeconds;

  bool viewed;   // PDF 열람 완료 여부
  bool checked;  // 동의 여부

  ConsentItem({
    required this.kind,
    required this.title,
    this.pdfUrl,
    this.required = true,
    this.mustOpen = true,
    this.minViewSeconds = 5,
    this.viewed = false,
    this.checked = false,
  });
}
