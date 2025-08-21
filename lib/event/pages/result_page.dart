import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/types.dart';
import '../service/fortune_auth_service.dart';
import '../service/fortune_firestore_service.dart';
import '../config/share_links.dart';

// 추천 상품 상세로 진입
import 'package:reframe/pages/deposit/deposit_detail_page.dart';

class ResultPage extends StatefulWidget {
  final FortuneFlowArgs args;
  final FortuneResponse data;
  const ResultPage({super.key, required this.args, required this.data});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  static const bool kBypassDailyLimitForTest = true;

  // 공통 패딩 상수
  static const kBoxPadding = EdgeInsets.all(16);

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

              // ✅ 추천 상품들: 카드 탭 → DepositDetailPage 로 이동
              if (widget.data.products.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: kBoxPadding,
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
                        child: _ProductCard(
                          name: p.name,
                          summary: p.summary ?? '',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DepositDetailPage(productId: p.productId),
                                settings: const RouteSettings(name: '/deposit/detail'),
                              ),
                            );
                          },
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

/// 추천 상품 한 개 카드 위젯 (탭 가능)
class _ProductCard extends StatelessWidget {
  final String name;
  final String summary;
  final VoidCallback onTap;
  const _ProductCard({
    required this.name,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(summary, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: onTap,
              child: const Text('자세히 보기'),
            ),
          ],
        ),
      ),
    );
  }
}
