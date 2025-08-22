import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../pages/deposit/deposit_detail_page.dart';
import '../config/share_links.dart';
import '../models/types.dart';
import '../service/fortune_auth_service.dart';

// 상세 상품 조회(기간/금리 용)
import 'package:reframe/service/deposit_service.dart';
import 'package:reframe/model/deposit_product.dart';

// 브랜드 컬러
const _brandBlue = Color(0xFF2962FF);

class ResultPage extends StatefulWidget {
  final FortuneFlowArgs args;
  final FortuneResponse data;
  const ResultPage({super.key, required this.args, required this.data});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  // 추천 카드에 기간/금리 표시를 위해 상세를 캐싱
  final Map<int, DepositProduct> _productDetails = {};

  @override
  void initState() {
    super.initState();
    _prefetchDetails(); // 상세(기간/금리) 가능하면 미리 불러오기
  }

  Future<void> _prefetchDetails() async {
    final ids = widget.data.products.map((p) => p.productId).whereType<int>().toList();
    if (ids.isEmpty) return;

    try {
      final futures = ids.map((id) async {
        try {
          final detail = await fetchProduct(id);
          return MapEntry(id, detail);
        } catch (_) {
          return null; // 개별 실패는 무시
        }
      }).toList();

      final results = await Future.wait(futures);
      final map = <int, DepositProduct>{};
      for (final e in results) {
        if (e != null) map[e.key] = e.value;
      }
      if (mounted && map.isNotEmpty) {
        setState(() {
          _productDetails.addAll(map);
        });
      }
    } catch (_) {
      // 전체 실패는 UI에 영향 없이 무시
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
      ..writeln(widget.data.fortune)
      ..writeln()
      ..writeln((widget.data.content ?? '').isNotEmpty ? widget.data.content : '')
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
    final now = DateTime.now();
    final formattedDate = "${now.month}월 ${now.day}일"; // 오늘 날짜

    // 하단 내비게이션/홈 인디케이터에 가리지 않도록 여유 패딩 계산
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    const extraForNav = kBottomNavigationBarHeight; // 일반적인 바 높이
    final bottomPadding = 24.0 + extraForNav + bottomSafe;

    return Scaffold(
      appBar: AppBar(title: const Text(""), toolbarHeight: 30),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 0),
            Text(
              '$formattedDate 오늘은',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _brandBlue,
              ),
            ),

            Text(
              widget.data.fortune,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            if ((widget.data.content ?? '').isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.data.content!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),

            const SizedBox(height: 50),

            // 고객 이름 멘트
            Text(
              '${widget.args.name} 님에게 추천드려요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 22),

            // 추천 상품 리스트(레이아웃 유지: 세로 나열, 모양만 파란 카드)
            if (widget.data.products.isNotEmpty)
              ...widget.data.products.map((p) {
                final detail = _productDetails[p.productId];
                final periodText = (detail?.period ?? 0) > 0 ? "${detail!.period}개월" : null;
                final rateText = (detail?.maxRate ?? 0) > 0
                    ? "최고 ${detail!.maxRate.toStringAsFixed(2)}%"
                    : null;

                // 해시태그: category/summary 중 하나 사용, 없으면 기본값
                final hashtag = _buildHashtag(p.category, p.summary);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DepositDetailPage(productId: p.productId),
                          settings: const RouteSettings(name: '/deposit/detail'),
                        ),
                      );
                    },
                    child: _BlueBadgeCard(
                      title: p.name,
                      hashtag: hashtag,
                      periodText: periodText, // null이면 자동 생략
                      rateText: rateText,     // null이면 자동 생략
                    ),
                  ),
                );
              }).toList(),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _shareFortune,
                child: const Text(
                  "친구에게 공유하기",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
    String raw = (category ?? '').trim();
    if (raw.isEmpty) raw = (summary ?? '').trim();
    if (raw.isEmpty) raw = '목돈만들기';

    // 특수문자 제거 + 공백 제거
    final cleaned = raw
        .replaceAll(RegExp(r'[^ㄱ-ㅎ가-힣A-Za-z0-9 ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '');
    return '#$cleaned';
  }
}

/// =======================================
/// 파란 배지 스타일 카드 (이미지와 유사한 톤/레이아웃)
/// - 좌상: 제목
/// - 그 아래: 해시태그 + 작은 코인 두 개(이모지로 대체)
/// - 하단: 좌측 기간(옵션) / 우측 파란 ‘최고 금리’(옵션)
/// =======================================
class _BlueBadgeCard extends StatelessWidget {
  final String title;
  final String hashtag;
  final String? periodText; // ex) "12개월" (없으면 생략)
  final String? rateText;   // ex) "최고 7.00%" (없으면 생략)

  const _BlueBadgeCard({
    required this.title,
    required this.hashtag,
    this.periodText,
    this.rateText,
  });

  @override
  Widget build(BuildContext context) {
    // 이미지 느낌과 비슷한 밝은 블루 톤
    final gradient = const LinearGradient(
      colors: [Color(0xFFEAF2FF), Color(0xFFDDE8FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Ink(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        // 이미지 대비 살짝 더 촘촘한 패딩
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),

            // 해시태그 + 동전 이모지
            Row(
              children: [
                Flexible(
                  child: Text(
                    hashtag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.black.withOpacity(0.65),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text("🟡", style: TextStyle(fontSize: 14)),
                const SizedBox(width: 2),
                const Text("🟡", style: TextStyle(fontSize: 12)),
              ],
            ),

            const SizedBox(height: 10),

            // 하단: 좌(기간) / 우(금리)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 기간이 있으면 표시
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
                // 금리가 있으면 파란색 굵게
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
