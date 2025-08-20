import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/types.dart';
import '../service/fortune_auth_service.dart';
import '../service/fortune_firestore_service.dart';
import '../config/share_links.dart';

const kBoxPadding = EdgeInsets.all(16);


class ResultPage extends StatefulWidget {
  final FortuneFlowArgs args;
  final FortuneResponse data;
  const ResultPage({super.key, required this.args, required this.data});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  static const bool kBypassDailyLimitForTest = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _rewardIfInvited();
      if (!kBypassDailyLimitForTest) {
        await _markDailyUsed();
      }
    });
  }

  Future<void> _markDailyUsed() async {
    try {
      await FortuneFirestoreService.setLastDrawDateToday();
    } catch (_) {}
  }

  String? _resolveInviter() {
    final fromArgs = widget.args.invitedBy;
    if (fromArgs != null && fromArgs.isNotEmpty) return fromArgs;
    final raw = ModalRoute.of(context)?.settings.arguments;
    if (raw is Map) {
      final v = (raw['inviter'] ?? raw['code'] ?? raw['inviteCode'])?.toString();
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
        inviteeUid: me,
        source: 'fortune',
        debugAllowSelf: false,
      );
    } catch (_) {}
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
      ..writeln(widget.data.fortune)
      ..writeln()
      ..writeln('키워드: ${widget.data.keyword}')
      ..writeln()
      ..writeln('추천 상품')
      ..writeln(widget.data.products.map((p) => '- ${p.name} (${p.category})').join('\n'))
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
              const Text("✨ 오늘의 운세는...", style: TextStyle(fontSize: 20), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(widget.data.fortune, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('키워드: ${widget.data.keyword}', style: const TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // 추천 상품 박스
              if (widget.data.products.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4F3D8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('추천 상품', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      ...widget.data.products.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            Text(p.name, style: const TextStyle(fontSize: 16)),
                            if (p.summary != null && p.summary!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(p.summary!, textAlign: TextAlign.center),
                              ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: kBoxPadding,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(isAgreed ? "타겟팅 광고 영역 (동의 O)" : "범용 광고 영역 (동의 X)", textAlign: TextAlign.center),
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