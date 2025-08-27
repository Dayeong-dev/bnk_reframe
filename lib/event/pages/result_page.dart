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
const _brandBlue = Color(0xFF2962FF);
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
    // 공유 본문에 키워드를 포함하려면 아래 줄 유지. 공유에도 숨기려면 이 줄 삭제.
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

    // 하단 네비/홈 인디케이터 여백
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    const extraForNav = kBottomNavigationBarHeight;
    final bottomPadding = 20.0 + extraForNav + bottomSafe;

    final short = (widget.data.fortune).trim(); // 15자 이내 문장
    final kw = (widget.data.keyword ?? '').trim(); // 단일 키워드
    final hasDetail = (widget.data.content ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        toolbarHeight: 30,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// ===== 헤더(날짜) =====
            _HeaderDateBadge(dateText: '$formattedDate 오늘은'),
            const SizedBox(height: 10),

            /// 짧은 문장(서브타이틀)
            if (short.isNotEmpty)
              Text(
                short, // ex) "새로운 시작을 도전하기 좋은 하루"
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                ),
              ),

            /// 키워드 UI 출력 제거 (구분선/키워드 텍스트 전부 숨김)
            const SizedBox(height: 14),

            /// 운세 본문 영역
            if (hasDetail)
              _FortuneInsightCard(
                content: widget.data.content!,
                keyword: kw, // 팁 생성 용도로만 사용, 화면에는 표시되지 않음
              ),

            /// content 와 추천 타이틀 사이 간격 3배(15 -> 45)
            const SizedBox(height: 45),

            /// 추천 섹션 타이틀 — 느낌표 + 가운데 정렬
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

            /// 추천 상품 카드 목록(미니멀 카드)
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

            const SizedBox(height: 0),

            /// 공유 버튼 — 파란 배경 + 흰 글자
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlue,      // 파란 버튼
                  foregroundColor: Colors.white,     // 전경색(리플/아이콘 등)
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _shareFortune,
                child: const Text(
                  "친구에게 공유하기",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,             // 흰 글자
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildHashtag(String? category, String? summary) {
    // 화면에서 '키워드'는 숨겼지만, 상품 카드 해시태그는 카테고리/요약 기반으로 유지
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

/// 헤더(날짜)
class _HeaderDateBadge extends StatelessWidget {
  final String dateText;
  const _HeaderDateBadge({required this.dateText});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Text(
          dateText,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _brandBlue,
          ),
        ),
        const SizedBox(width: 8),
        const Text('', style: TextStyle(fontSize: 20)),
      ],
    );
  }
}

/// 운세 인사이트 카드
/// - 상단 헤더: 🔆 오늘의 인사이트
/// - 본문: 큰 따옴표 스타일
/// - 작은 실천 제안: 키워드 기반 1~2개 체크리스트(키워드 텍스트는 표시하지 않음)
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
            // 헤더
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

            // 본문 (큰 따옴표 스타일)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('❝',
                    style: TextStyle(fontSize: 20, color: Color(0xFF94A3B8))),
                const SizedBox(width: 6),
                Expanded(
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
                const SizedBox(width: 6),
                const Text('❞',
                    style: TextStyle(fontSize: 20, color: Color(0xFF94A3B8))),
              ],
            ),

            // 작은 실천 제안(있을 때만)
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

  /// 키워드별 작은 실천 제안 (텍스트는 화면에 표시하지 않음)
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

/// 추천 상품 카드 — 미니멀
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
            /// 타이틀
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

            /// 해시태그(상품 카테고리/요약 기반)
            Text(
              hashtag,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 10),

            /// 하단 정보(기간 / 금리)
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
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: _brandBlue,
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
