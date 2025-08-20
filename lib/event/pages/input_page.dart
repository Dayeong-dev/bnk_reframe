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
  bool isAgreed = false;
  String? invitedBy;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  String? _lastHandled; // 같은 URI 중복 처리 방지

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final raw = ModalRoute.of(context)?.settings.arguments;
    if (raw is Map) {
      final v = (raw['inviter'] ?? raw['inviteCode'] ?? raw['code'])?.toString();
      if (v != null && v.isNotEmpty && invitedBy == null) {
        setState(() => invitedBy = v);   // ★ StartPage → InputPage 전달분 반영
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initAuthAndLinks();
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

  // 내 앱에서 온 링크만 true
  bool _isOurLink(Uri link) {
    final isCustom = link.scheme == 'abcd1234' && link.host == 'fortune';
    final isHttps  = link.scheme == 'https'
        && link.host == 'abc123-2580c.web.app'
        && link.pathSegments.isNotEmpty
        && link.pathSegments.first == 'fortune'; // /fortune/...

    return isCustom || isHttps;
  }

  void _maybeCaptureInvite(Uri? link, {String? source}) {
    if (link == null) return;
    if (!_isOurLink(link)) return;

    final key = link.toString();
    if (_lastHandled == key) return; // 같은 링크 두 번 방지
    _lastHandled = key;

    // 다양한 키 허용: inviteCode / inviter / code
    final invite =
        link.queryParameters['inviteCode'] ??
            link.queryParameters['inviter'] ??
            link.queryParameters['code'];

    if (invite != null && invite.isNotEmpty) {
      setState(() => invitedBy = invite);
      debugPrint('📩 invitedBy captured($source): $invitedBy | $link');
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
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
    if (y.length != 4 || int.tryParse(y) == null) return _fail('생년(4자리 숫자)을 입력해주세요.');
    final mi = int.tryParse(m); final di = int.tryParse(d);
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

    // 로그인 보장(한 번 더 안전)
    await FortuneAuthService.ensureSignedIn();

    final name = nameController.text.trim();
    final birth = _composeBirth();

    try {
      if (isAgreed) {
        await FortuneFirestoreService.saveOrUpdateUserConsent(
          isAgreed: true,
          name: name,
          birth: birth,
          gender: gender,
        );
      }

      if (!mounted) return;

      final FortuneFlowArgs args = (
      isAgreed: isAgreed,
      name: isAgreed ? name : null,
      birthDate: isAgreed ? birth : null,
      gender: isAgreed ? gender : null,
      invitedBy: invitedBy, // ← 여기서 Result/Loading으로 넘김
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoadingPage(args: args)),
      );
    } catch (e, stack) {
      debugPrint('🔥 저장/이동 중 오류: $e');
      debugPrint(stack.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('문제가 발생했어요. 다시 시도해주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = invitedBy == null ? '초대 코드 없음' : '초대한 사람: $invitedBy';

    return Scaffold(
      appBar: AppBar(title: const Text("이름 / 생년월일 입력")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(hint, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "이름"),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),

            const Text("성별"),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text("남"),
                  selected: gender == "남",
                  onSelected: (_) => setState(() => gender = "남"),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text("여"),
                  selected: gender == "여",
                  onSelected: (_) => setState(() => gender = "여"),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Text("생년월일"),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "년 (예: 1998)"),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: monthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "월"),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: dayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "일"),
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isAgreed,
                  onChanged: (v) => setState(() => isAgreed = v ?? false),
                ),
                const Expanded(
                  child: Text(
                    "개인정보 수집·이용에 동의합니다. (동의 시 이름/생년월일/성별을 서버에 저장하며, "
                        "동의하지 않으면 결과 페이지에서만 일시적으로 사용됩니다.)",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onStart,
                child: const Text("운세 보러가기"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
