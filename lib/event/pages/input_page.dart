// input_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

import '../models/types.dart';
import '../service/fortune_auth_service.dart';
import '../service/fortune_firestore_service.dart';
import 'loading_page.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final nameController = TextEditingController();
  final yearController = TextEditingController();
  final monthController = TextEditingController();
  final dayController = TextEditingController();

  String gender = "남";
  bool isAgreed = true; // ✅ 기본값 체크 On
  String? invitedBy;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  String? _lastHandled; // 같은 URI 중복 처리 방지

  // ==== 타이핑 효과 ====
  static const String _fullTitle = '정보를 입력해주세요';
  String _typedTitle = '';
  Timer? _typeTimer;

  @override
  void initState() {
    super.initState();
    _initAuthAndLinks();

    // 시작 지연 후 타이핑 시작 (300ms 지연)
    Future.delayed(const Duration(milliseconds: 300), _startTyping);
  }

  void _startTyping() {
    // 타이핑 속도: 글자당 90ms
    _typeTimer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_typedTitle.length >= _fullTitle.length) {
        t.cancel();
        return;
      }
      setState(() {
        _typedTitle = _fullTitle.substring(0, _typedTitle.length + 1);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final raw = ModalRoute.of(context)?.settings.arguments;
    if (raw is Map) {
      final v =
      (raw['inviter'] ?? raw['inviteCode'] ?? raw['code'])?.toString();
      if (v != null && v.isNotEmpty && invitedBy == null) {
        setState(() => invitedBy = v); // StartPage → InputPage 전달분 반영
      }
    }
  }

  Future<void> _initAuthAndLinks() async {
    // 로그인 보장(UID 필요 시 null 방지)
    await FortuneAuthService.ensureSignedIn();

    _appLinks = AppLinks();

    // 콜드스타트 링크
    try {
      final initial = await _appLinks.getInitialLink();
      _maybeCaptureInvite(initial, source: 'initial');
    } catch (e) {
      debugPrint('⚠️ initial app link error: $e');
    }

    // 런타임 링크
    _linkSub = _appLinks.uriLinkStream.listen(
          (uri) => _maybeCaptureInvite(uri, source: 'stream'),
      onError: (err) => debugPrint('⚠️ uri link stream error: $err'),
    );
  }

  bool _isOurLink(Uri link) {
    final isCustom = link.scheme == 'abcd1234' && link.host == 'fortune';
    final isHttps = link.scheme == 'https' &&
        link.host == 'abc123-2580c.web.app' &&
        link.pathSegments.isNotEmpty &&
        link.pathSegments.first == 'fortune'; // /fortune/...
    return isCustom || isHttps;
  }

  void _maybeCaptureInvite(Uri? link, {String? source}) {
    if (link == null) return;
    if (!_isOurLink(link)) return;

    final key = link.toString();
    if (_lastHandled == key) return; // 같은 링크 두 번 방지
    _lastHandled = key;

    final invite = link.queryParameters['inviteCode'] ??
        link.queryParameters['inviter'] ??
        link.queryParameters['code'];

    if (invite != null && invite.isNotEmpty) {
      setState(() => invitedBy = invite); // 내부적으로만 저장, 화면엔 노출 X
      debugPrint('📩 invitedBy captured($source): $invitedBy | $link');
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _typeTimer?.cancel();
    nameController.dispose();
    yearController.dispose();
    monthController.dispose();
    dayController.dispose();
    super.dispose();
  }

  String _composeBirth() {
    final y = yearController.text.trim();
    final m = monthController.text.trim().padLeft(2, '0');
    final d = dayController.text.trim().padLeft(2, '0');
    return '$y$m$d';
  }

  bool _validateInputs() {
    final name = nameController.text.trim();
    final y = yearController.text.trim();
    final m = monthController.text.trim();
    final d = dayController.text.trim();

    if (name.isEmpty) return _fail('이름을 입력해주세요.');
    if (y.length != 4 || int.tryParse(y) == null) {
      return _fail('생년(4자리 숫자)을 입력해주세요.');
    }
    final mi = int.tryParse(m);
    final di = int.tryParse(d);
    if (mi == null || mi < 1 || mi > 12) return _fail('월은 1~12 사이여야 해요.');
    if (di == null || di < 1 || di > 31) return _fail('일은 1~31 사이여야 해요.');
    return true;
  }

  bool _fail(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    return false;
  }

  Future<void> _onStart() async {
    if (!_validateInputs()) return;

    // ✅ 익명 로그인 보장 (UID 즉시 확보)
    await FortuneAuthService.ensureSignedIn();

    final name = nameController.text.trim();
    final birth = _composeBirth();

    // ✅ 동의 저장은 '베스트 에포트' — 실패해도 흐름을 멈추지 않음
    if (isAgreed) {
      try {
        await FortuneFirestoreService.saveOrUpdateUserConsent(
          isAgreed: true,
          name: name,
          birth: birth,
          gender: gender,
        );
      } catch (e, stack) {
        debugPrint('⚠️ 동의 저장 실패(무시하고 진행): $e');
        debugPrint(stack.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('동의 저장에 실패했지만 테스트는 계속 진행합니다.')),
          );
        }
      }
    }

    if (!mounted) return;

    final FortuneFlowArgs args = (
    isAgreed: isAgreed,
    name: isAgreed ? name : null,
    birthDate: isAgreed ? birth : null,
    gender: isAgreed ? gender : null,
    invitedBy: invitedBy, // 내부 전달만, 화면 노출 없음
    );

    // ✅ 항상 결과 로딩으로 진행
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoadingPage(args: args)),
    );
  }

  // 공통 스타일 (StartPage와 톤 맞춤)
  InputDecoration _decor(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black87, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 제목은 타이핑 텍스트로 대체하므로 AppBar 타이틀 없음
        centerTitle: true,
        elevation: 0.5,
      ),

      // ✅ 하단 고정 버튼
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _onStart,
              child: const Text(
                '운세 보러가기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            // 상단 타이틀(타이핑)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _typedTitle.isEmpty ? ' ' : _typedTitle,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 이름
            TextField(
              controller: nameController,
              decoration: _decor('이름'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 22),

            // 성별
            const Text(
              "성별",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => gender = "남"),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: gender == "남"
                            ? const Color(0xFFD8E3FF)
                            : Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "남",
                        style: TextStyle(
                          color:
                          gender == "남" ? Colors.black87 : Colors.black54,
                          fontWeight:
                          gender == "남" ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => gender = "여"),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: gender == "여"
                            ? const Color(0xFFD8E3FF)
                            : Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "여",
                        style: TextStyle(
                          color:
                          gender == "여" ? Colors.black87 : Colors.black54,
                          fontWeight:
                          gender == "여" ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // 생년월일
            const Text(
              "생년월일",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: yearController,
                    keyboardType: TextInputType.number,
                    decoration: _decor('년', hint: '2025'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: monthController,
                    keyboardType: TextInputType.number,
                    decoration: _decor('월', hint: '12'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: dayController,
                    keyboardType: TextInputType.number,
                    decoration: _decor('일', hint: '31'),
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 개인정보 동의 영역
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isAgreed,
                      onChanged: (v) => setState(() => isAgreed = v ?? false),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text(
                          '개인정보 수집/이용 동의 (선택)',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),

                // 안내 문구
                const Padding(
                  padding: EdgeInsets.only(left: 12, right: 8, bottom: 4),
                  child: Text(
                    '동의 시 이름·생년월일·성별을 서버에 저장합니다.\n'
                        '동의하지 않으면 결과 페이지에서만 일시적으로 사용됩니다.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
