import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../pages/deposit/deposit_detail_page.dart';
import '../config/share_links.dart';
import '../models/types.dart';
import '../service/fortune_auth_service.dart';

// 상세 상품 조회(기간/금리 용)
import 'package:reframe/service/deposit_service.dart';
import 'package:reframe/model/deposit_product.dart';

/// 브랜드 톤
const _cardBg = Color(0xFFF7F9FC);
const _border = Color(0xFFE3E8F0);

class ResultPage extends StatefulWidget {
  final FortuneFlowArgs args;
  final FortuneResponse data;
  const ResultPage({super.key, required this.args, required this.data});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  /// 추천 카드에 기간/금리 표시를 위해 상세 캐시
  final Map<int, DepositProduct> _productDetails = {};

  @override
  void initState() {
    super.initState();
    _prefetchDetails();
  }

  Future<void> _prefetchDetails() async {
    final ids =
        widget.data.products.map((p) => p.productId).whereType<int>().toList();
    if (ids.isEmpty) return;

    try {
      final futures = ids.map((id) async {
        try {
          final detail = await fetchProduct(id);
          return MapEntry(id, detail);
        } catch (_) {
          return null; // 개별 실패 무시
        }
      }).toList();

      final results = await Future.wait(futures);
      final map = <int, DepositProduct>{};
      for (final e in results) {
        if (e != null) map[e.key] = e.value;
      }
      if (mounted && map.isNotEmpty) {
        setState(() => _productDetails.addAll(map));
      }
    } catch (_) {/* 전체 실패는 UI에 영향 없이 무시 */}
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

    final short = (widget.data.fortune).trim(); // 15자 이내 문장
    final kw = (widget.data.keyword ?? '').trim(); // 단일 키워드
    final detail = (widget.data.content ?? '').trim(); // 상세 설명

    final text = StringBuffer()
      ..writeln('✨ 오늘의 운세')
      ..writeln()
      ..writeln(short)
      ..writeln(detail.isNotEmpty ? '\n$detail' : '')
      ..writeln(kw.isNotEmpty ? '\n#$kw' : '')
      ..writeln('\n추천 상품')
      ..writeln(widget.data.products
          .map((p) => '- ${p.name} (${p.category})')
          .join('\n'))
      ..writeln('\n$appLink')
      ..writeln('\n설치가 필요하면 ➜ $playStore');

    final shareStr = text
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .join('\n');

    await Share.share(shareStr, subject: '오늘의 운세를 확인해보세요!');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = "${now.month}월 ${now.day}일";

    final short = (widget.data.fortune).trim();
    final kw = (widget.data.keyword ?? '').trim();
    final hasKw = kw.isNotEmpty;
    final hasDetail = (widget.data.content ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        toolbarHeight: 30,
      ),

      /// ✅ 본문: 불필요한 큰 하단 패딩 제거 + 드래그(bounce) 제거
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderDateBadge(dateText: '$formattedDate 오늘은'),
            const SizedBox(height: 10),
            if (short.isNotEmpty)
              Text(
                short,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                ),
              ),
            if (hasKw) ...[
              const SizedBox(height: 8),
              _KeywordSeparatorTag(keyword: kw),
            ],
            const SizedBox(height: 14),
            if (hasDetail)
              _FortuneInsightCard(
                content: widget.data.content!,
                keyword: kw,
              ),
            const SizedBox(height: 15),
            Text(
              '${widget.args.name} 님에게 추천드려요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 10),
            if (widget.data.products.isNotEmpty)
              ...widget.data.products.map((p) {
                final detail = _productDetails[p.productId];
                final periodText =
                    (detail?.period ?? 0) > 0 ? "${detail!.period}개월" : null;
                final rateText = (detail?.maxRate ?? 0) > 0
                    ? "최고 ${detail!.maxRate.toStringAsFixed(2)}%"
                    : null;

                final hashtag = _buildHashtag(p.category, p.summary);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DepositDetailPage(productId: p.productId),
                          settings:
                              const RouteSettings(name: '/deposit/detail'),
                        ),
                      );
                    },
                    child: _ProductCard(
                      title: p.name,
                      hashtag: hashtag,
                      periodText: periodText,
                      rateText: rateText,
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),

      /// ✅ 하단 고정: 앱 프라이머리 컬러 사용 + SafeArea
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _shareFortune,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                elevation: 0,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '친구에게 공유하기',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buildHashtag(String? category, String? summary) {
    String raw = (category ?? '').trim();
    if (raw.isEmpty) raw = (summary ?? '').trim();
    if (raw.isEmpty) raw = '목돈만들기';
    final cleaned = raw
        .replaceAll(RegExp(r'[^ㄱ-ㅎ가-힣A-Za-z0-9 ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '');
    return '#$cleaned';
  }
}

/// ===================== 컴포넌트 =====================

class _HeaderDateBadge extends StatelessWidget {
  final String dateText;
  const _HeaderDateBadge({required this.dateText});

  @override
  Widget build(BuildContext context) {
    final brandBlue = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🔮', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Text(
          dateText,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: brandBlue,
          ),
        ),
        const SizedBox(width: 8),
        const Text('✨', style: TextStyle(fontSize: 20)),
      ],
    );
  }
}

class _KeywordSeparatorTag extends StatelessWidget {
  final String keyword;
  const _KeywordSeparatorTag({required this.keyword});

  @override
  Widget build(BuildContext context) {
    final brandBlue = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        const _GradientLine(),
        const SizedBox(width: 10),
        Text(
          '#$keyword',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: brandBlue,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 10),
        const _GradientLine(),
      ],
    );
  }
}

class _GradientLine extends StatelessWidget {
  const _GradientLine();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1.2,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, _border, Colors.transparent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}

class _FortuneInsightCard extends StatelessWidget {
  final String content;
  final String keyword;
  const _FortuneInsightCard({
    required this.content,
    required this.keyword,
  });

  @override
  Widget build(BuildContext context) {
    final tips = _tipsFor(keyword);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FBFF), Color(0xFFF3F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Text('🔆', style: TextStyle(fontSize: 18)),
                SizedBox(width: 6),
                Text(
                  '오늘의 인사이트',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('❝',
                    style: TextStyle(fontSize: 20, color: Color(0xFF94A3B8))),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    // content 바인딩은 아래 Expanded 밖에서 처리
                    '',
                  ),
                ),
                SizedBox(width: 6),
                Text('❞',
                    style: TextStyle(fontSize: 20, color: Color(0xFF94A3B8))),
              ],
            ),
            // 위 Row에서 content를 넣기 위해 다시 구성
            Padding(
              padding: const EdgeInsets.only(left: 26, right: 26),
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),

            if (tips.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 10),
              const Text(
                '작은 실천',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              ...tips.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✅ ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _tipsFor(String kw) {
    final t = kw.toLowerCase();
    if (t.contains('도전') || t.contains('시작')) {
      return ['오늘 해야 할 새 일 한 가지를 10분만 시도해보기', '완료 후 스스로에게 칭찬 한마디 남기기'];
    }
    if (t.contains('저축') || t.contains('적금')) {
      return ['소액 자동이체 설정(예: 월 1만원부터)', '지출 항목 하나만 줄여서 그만큼 저축으로 이동'];
    }
    if (t.contains('건강') || t.contains('걷기')) {
      return ['점심 후 10분 걷기 실천', '물 1잔 더 마시기'];
    }
    if (t.contains('행운') || t.contains('감사')) {
      return ['오늘 감사한 일 1가지 메모', '주변 사람에게 짧은 감사 메시지 보내기'];
    }
    if (t.contains('환경') || t.contains('탄소')) {
      return ['개인컵 사용하기', '엘리베이터 대신 1층 정도는 계단 이용'];
    }
    return [];
  }
}

class _ProductCard extends StatelessWidget {
  final String title;
  final String hashtag;
  final String? periodText;
  final String? rateText;

  const _ProductCard({
    required this.title,
    required this.hashtag,
    this.periodText,
    this.rateText,
  });

  @override
  Widget build(BuildContext context) {
    final brandBlue = Theme.of(context).colorScheme.primary;
    return Ink(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hashtag,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (periodText != null)
                  Text(
                    periodText!,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withOpacity(0.60),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (rateText != null)
                  Text(
                    rateText!,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: brandBlue,
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
