import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/types.dart';
import '../service/fortune_auth_service.dart';
import '../service/fortune_firestore_service.dart';
import '../config/share_links.dart';

class ResultPage extends StatefulWidget {
  final FortuneFlowArgs args;
  const ResultPage({super.key, required this.args});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {

  static const bool kBypassDailyLimitForTest = true;

  String _fortuneText = "";
  String _recommendTitle = "추천 상품";
  String _recommendDesc = "오늘의 운세와 어울리는 상품을 소개합니다.";

  @override
  void initState() {
    super.initState();
    _buildFortuneAndRecommendation();

    // 초대 보상(초대한 사람만 +1, 10개마다 쿠폰 발급)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rewardIfInvited();
    });

    // ★ 테스트 중에는 오늘 사용 기록을 남기지 않음
    if (!kBypassDailyLimitForTest) {
      _markDailyUsed();
    }
  }

  Future<void> _markDailyUsed() async {
    try {
      await FortuneFirestoreService.setLastDrawDateToday();
    } catch (e) {
      debugPrint('⚠️ lastDrawDate 기록 실패: $e');
    }
  }

  void _buildFortuneAndRecommendation() {
    final today = DateTime.now();
    final todayX = "${today.year}${today.month}${today.day}";
    final base = "${widget.args.birthDate ?? ''}${widget.args.gender ?? ''}$todayX";
    final seed = base.hashCode.abs();

    final fortunes = [
      "꾸준한 노력이 결실을 맺는 날입니다.",
      "새로운 인연이나 기회가 찾아옵니다.",
      "집중력과 계획성이 빛을 발해요.",
      "행운의 기운이 당신을 돕습니다.",
      "작은 습관이 큰 변화를 만듭니다.",
    ];
    final f = fortunes[seed % fortunes.length];
    _fortuneText = f;

    if (f.contains("꾸준") || f.contains("노력") || f.contains("계획")) {
      _recommendTitle = "추천 상품: 정기적금 (자동이체 우대)";
      _recommendDesc = "목표를 정하고 매달 꾸준히 저축해보세요.\n우대금리 조건도 함께 확인!";
    } else if (f.contains("행운") || f.contains("기회")) {
      _recommendTitle = "추천 상품: 자유적금 (목돈 마련)";
      _recommendDesc = "여유 있을 때 자유롭게 납입하며\n목돈을 만들어보세요.";
    } else {
      _recommendTitle = "추천 상품: 단기 예금 (유동성 우선)";
      _recommendDesc = "자금 계획이 중요하다면\n단기 예금으로 안정적인 운용을!";
    }
    if (mounted) setState(() {});
  }

  String? _resolveInviter() {
    // 1) Flow args 우선
    final fromArgs = widget.args.invitedBy;
    if (fromArgs != null && fromArgs.isNotEmpty) return fromArgs;

    // 2) Navigator RouteSettings.arguments(Map)에서 보조 추출
    final raw = ModalRoute.of(context)?.settings.arguments;
    if (raw is Map) {
      final m = raw;
      final v = (m['inviter'] ?? m['code'] ?? m['inviteCode'])?.toString();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  Future<void> _rewardIfInvited() async {
    final inviter = _resolveInviter();
    if (inviter == null || inviter.isEmpty) return;

    await FortuneAuthService.ensureSignedIn();

    final me = FortuneAuthService.getCurrentUid();
    if (me == null) return;

    try {
      await FortuneFirestoreService.rewardInviteOnce(
        inviterUid: inviter,
        inviteeUid: me,            // ✅ 통일
        source: 'fortune',
        debugAllowSelf: false,     // 한 기기 테스트시만 true
      );
    } catch (e) {
      debugPrint("🔥 초대 보상 처리 오류: $e");
    }
  }

  Future<void> _shareFortune() async {
    await FortuneAuthService.ensureSignedIn();

    final myUid = FortuneAuthService.getCurrentUid();
    if (myUid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인을 다시 시도해주세요.')),
      );
      return;
    }

    final appLink = ShareLinks.shareUrl(inviteCode: myUid, src: 'result');
    final playStore = ShareLinks.playStoreUrl;

    final text = StringBuffer()
      ..writeln('✨ 오늘의 운세')
      ..writeln()
      ..writeln(_fortuneText)
      ..writeln()
      ..writeln(_recommendTitle)
      ..writeln()
      ..writeln(appLink)
      ..writeln()
      ..writeln('설치가 필요하면 ➜ $playStore');

    await Share.share(text.toString(), subject: '오늘의 운세를 확인해보세요!');
  }


  @override
  Widget build(BuildContext context) {
    final isAgreed = widget.args.isAgreed;

    return Scaffold(
      appBar: AppBar(title: const Text("오늘의 운세 결과")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text("✨ 오늘의 운세는...",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(_fortuneText,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFD4F3D8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Text(_recommendTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(_recommendDesc, textAlign: TextAlign.center),
                ]),
              ),

              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isAgreed ? "타겟팅 광고 영역 (동의 O)" : "범용 광고 영역 (동의 X)",
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _shareFortune,
                  child: const Text("친구에게 공유하기"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
