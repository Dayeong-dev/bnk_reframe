// input_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
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
  // ===== 공통 사이즈(★추가: 모든 입력 위젯 높이 통일) =====
  static const double _fieldHeight = 52;

  // ===== 텍스트 컨트롤러 =====
  final nameController = TextEditingController();

  // ✅ 생년월일 숫자 상태(라벨에만 보이고, 탭하면 모달에서 변경)
  int _year = 2000;
  int _month = 1;
  int _day = 1;

  String gender = "남";

  // ✅ 기본값 체크 On
  bool isAgreed = true;

  String? invitedBy;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  String? _lastHandled;

  // 방문 기록 중복 방지 키(초대코드별 1회만)
  String? _inviteRecordedFor;

  // ==== 타이핑 효과 ====
  static const String _fullTitle = '정보를 입력해주세요';
  String _typedTitle = '';
  Timer? _typeTimer;

  // ===== 범위 =====
  static const int _minYear = 1900;
  final int _maxYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _initAuthAndLinks();
    Future.delayed(const Duration(milliseconds: 300), _startTyping);
  }

  void _startTyping() {
    _typeTimer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_typedTitle.length >= _fullTitle.length) {
        t.cancel();
        return;
      }
      setState(
              () => _typedTitle = _fullTitle.substring(0, _typedTitle.length + 1));
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
        _recordInviteVisitIfNeeded(v, source: 'route-arg');
      }
    }
  }

  Future<void> _initAuthAndLinks() async {
    await FortuneAuthService.ensureSignedIn();
    _appLinks = AppLinks();

    try {
      final initial = await _appLinks.getInitialLink();
      _maybeCaptureInvite(initial, source: 'initial');
    } catch (e) {
      debugPrint('⚠️ initial app link error: $e');
    }

    _linkSub = _appLinks.uriLinkStream.listen(
          (uri) => _maybeCaptureInvite(uri, source: 'stream'),
      onError: (err) => debugPrint('⚠️ uri link stream error: $err'),
    );
  }

  bool _isOurLink(Uri link) {
    final isCustom = link.scheme == 'bnk-app-push';
    final isHttps = link.scheme == 'https' &&
        link.host == 'bnk-app-push.web.app' &&
        link.pathSegments.isNotEmpty &&
        link.pathSegments.first == 'fortune';
    return isCustom || isHttps;
  }

  void _maybeCaptureInvite(Uri? link, {String? source}) {
    if (link == null) return;
    if (!_isOurLink(link)) return;

    final key = link.toString();
    if (_lastHandled == key) return;
    _lastHandled = key;

    final invite = link.queryParameters['inviteCode'] ??
        link.queryParameters['inviter'] ??
        link.queryParameters['code'];

    if (invite != null && invite.isNotEmpty) {
      if (invitedBy != invite) {
        setState(() => invitedBy = invite); // 내부 저장 (중복 setState 제거)
      }
      debugPrint('📩 invitedBy captured($source): $invitedBy | $link');
      _recordInviteVisitIfNeeded(invite, source: source ?? 'link');
    }
  }

  // ====== 초대 방문 기록(클레임/정산 없이 "방문만" 저장) ======
  Future<void> _recordInviteVisitIfNeeded(String inviter,
      {String? source}) async {
    if (_inviteRecordedFor == inviter) return; // 동일 초대자 중복 기록 방지

    try {
      await FortuneAuthService.ensureSignedIn();
      final invitee = FortuneAuthService.getCurrentUid();
      if (invitee == null) return;

      await FortuneFirestoreService.rewardInviteOnce(
        inviterUid: inviter,
        inviteeUid: invitee,
        source: source,
        debugAllowSelf: true, // ✅ 같은 사람이 초대돼도 카운트 증가(테스트)
      );

      _inviteRecordedFor = inviter;
      debugPrint('✅ visit recorded for inviter=$inviter by invitee=$invitee');
    } catch (e, st) {
      debugPrint('⚠️ visit record failed: $e\n$st');
      // 방문 기록 실패는 UX 영향 최소화: 알림 없이 지나감
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _typeTimer?.cancel();
    nameController.dispose();
    super.dispose();
  }

  // ===== 날짜 유틸 =====
  int _daysInMonth(int year, int month) {
    if (month == 12) return 31;
    final firstOfNext = DateTime(year, month + 1, 1);
    return firstOfNext.subtract(const Duration(days: 1)).day;
  }

  String _composeBirth() {
    final y = _year.toString().padLeft(4, '0');
    final m = _month.toString().padLeft(2, '0');
    final d = _day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  bool _validateInputs() {
    final name = nameController.text.trim();
    if (name.isEmpty) return _fail('이름을 입력해주세요.');

    final selected = DateTime(_year, _month, _day);
    final minDate = DateTime(_minYear, 1, 1);
    final maxDate = DateTime.now();

    if (selected.isBefore(minDate))
      return _fail('생년월일은 $_minYear-01-01 이후여야 해요.');
    if (selected.isAfter(maxDate)) return _fail('미래 날짜는 선택할 수 없어요.');
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

    // ✅ 동의 저장은 '베스트 에포트'
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

    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoadingPage(args: args)),
      );
    } catch (e, stack) {
      debugPrint('🔥 저장/이동 중 오류: $e');
      debugPrint(stack.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문제가 발생했어요. 다시 시도해주세요.')),
      );
    }
  }

  InputDecoration _decor(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black87, width: 1.2),
      ),
    );
  }

  // ====== 초대코드 미니 배지 ======
  Widget _inviteBadge() {
    if (invitedBy == null || invitedBy!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.link, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(
                  '초대코드: ${invitedBy!}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: invitedBy!));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('초대코드를 복사했어요.')),
                    );
                  },
                  child: const Icon(Icons.copy_rounded,
                      size: 14, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// === 모달 다이얼로그(숫자 휠) 열기 ===
  Future<void> _openBirthPickerModal() async {
    int tempYear = _year;
    int tempMonth = _month;
    int tempDay = _day;

    final years =
    List<int>.generate(_maxYear - _minYear + 1, (i) => _minYear + i);
    final months = List<int>.generate(12, (i) => i + 1);

    int yearIndex = years.indexOf(tempYear);
    int monthIndex = tempMonth - 1;
    int dayMax = _daysInMonth(tempYear, tempMonth);
    List<int> days = List<int>.generate(dayMax, (i) => i + 1);
    int dayIndex = (tempDay - 1).clamp(0, dayMax - 1);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final primary = const Color(0xFF2962FF);
        return Dialog(
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (context, setSB) {
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 헤더
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          const Text('생년월일 선택',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(context), // 취소
                            child: const Text('취소'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              setState(() {
                                _year = tempYear;
                                _month = tempMonth;
                                _day = tempDay;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('완료'),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),

                    // 본문: 3열 숫자 휠
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: SizedBox(
                        height: 220,
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoPicker(
                                itemExtent: 36,
                                scrollController: FixedExtentScrollController(
                                    initialItem: yearIndex),
                                onSelectedItemChanged: (i) {
                                  tempYear = years[i];
                                  final newMax =
                                  _daysInMonth(tempYear, tempMonth);
                                  if (tempDay > newMax) tempDay = newMax;
                                  dayMax = newMax;
                                  days =
                                  List<int>.generate(newMax, (k) => k + 1);
                                  dayIndex = (tempDay - 1).clamp(0, newMax - 1);
                                  setSB(() {});
                                },
                                children: years
                                    .map((y) => Center(child: Text('$y')))
                                    .toList(),
                              ),
                            ),
                            Expanded(
                              child: CupertinoPicker(
                                itemExtent: 36,
                                scrollController: FixedExtentScrollController(
                                    initialItem: monthIndex),
                                onSelectedItemChanged: (i) {
                                  tempMonth = months[i];
                                  final newMax =
                                  _daysInMonth(tempYear, tempMonth);
                                  if (tempDay > newMax) tempDay = newMax;
                                  dayMax = newMax;
                                  days =
                                  List<int>.generate(newMax, (k) => k + 1);
                                  dayIndex = (tempDay - 1).clamp(0, newMax - 1);
                                  setSB(() {});
                                },
                                children: months
                                    .map((m) => Center(child: Text('$m')))
                                    .toList(),
                              ),
                            ),
                            Expanded(
                              child: CupertinoPicker(
                                itemExtent: 36,
                                scrollController: FixedExtentScrollController(
                                    initialItem: dayIndex),
                                onSelectedItemChanged: (i) => tempDay = days[i],
                                children: days
                                    .map((d) => Center(child: Text('$d')))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final birthLabel = '$_year년 $_month월 $_day일';

    return Scaffold(
      appBar: AppBar(),

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

            // ✅ 초대코드 배지(감지된 경우에만)
            _inviteBadge(),
            const SizedBox(height: 6),
            const SizedBox(height: 20),

            // ===== 이름 (★수정: 높이/폭을 다른 요소와 동일하게) =====
            SizedBox(
              height: _fieldHeight,
              child: TextField(
                controller: nameController,
                decoration: _decor('이름'),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: 22),

            // 성별
            const Text('성별',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => gender = "남"),
                    child: Container(
                      height: _fieldHeight,
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
                      height: _fieldHeight,
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

            // === 생년월일 (탭 → 모달 숫자 휠) ===
            const Text('생년월일',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                await _openBirthPickerModal();
                setState(() {}); // 라벨 갱신 보장
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: _fieldHeight, // ★ 같은 높이
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      birthLabel,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_month_outlined),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 개인정보 동의 (체크박스 고정, 라벨만 왼쪽으로 당김)
            Builder(builder: (context) {
              void toggle() => setState(() => isAgreed = !isAgreed);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ 체크박스는 그대로
                  Checkbox(
                    value: isAgreed,
                    onChanged: (v) => setState(() => isAgreed = v ?? false),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),

                  // ✅ 라벨만 왼쪽으로 당기기
                  Transform.translate(
                    offset: const Offset(-1, 0), // ← 텍스트만 왼쪽으로 6px
                    child: GestureDetector(
                      onTap: toggle,
                      behavior: HitTestBehavior.translucent,
                      child: const Text(
                        '개인정보 수집/이용 동의 (선택)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              );
            }),


            // 안내 문구
            const Padding(
              padding: EdgeInsets.only(left: 7, right: 8, bottom: 4), // ← 12 → 16
              child: Text(
                '동의 시 이름·생년월일·성별을 서버에 저장합니다.\n'
                    '동의하지 않으면 결과 페이지에서만 일시적으로 사용됩니다.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black54),
              ),
            ),


            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
