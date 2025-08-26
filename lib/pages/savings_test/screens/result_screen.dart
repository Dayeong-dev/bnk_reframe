import 'package:flutter/material.dart';
import 'package:reframe/app/app_shell.dart';
import '../services/recommender.dart';
import '../../../model/deposit_product.dart';
import '../../../service/deposit_service.dart';
import '../../deposit/deposit_detail_page.dart';
import '../../deposit/deposit_list_page.dart';

class ResultScreen extends StatelessWidget {
  static const routeName = '/savings/result';
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String code = ModalRoute.of(context)!.settings.arguments as String;

    final productId = productIdForResult(code);
    if (productId == null) {
      return Scaffold(
        appBar: AppBar(), // 기본 앱바
        body: const SafeArea(
          child: Center(child: Text('알 수 없는 결과 유형')),
        ),
      );
    }

    final title = getRecommendationText(code);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(), // ✅ 기본 AppBar(뒤로가기 자동)
      body: SafeArea(
        child: Stack(
          children: [
            // 메인 스크롤 (본문만 아래로 60px 내림)
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 결과 문구
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _Brand.primary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 추천 카드: 화려 + "자세히 보기"만 (추천 배지 제거)
                  FutureBuilder<DepositProduct>(
                    future: fetchProduct(productId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return _cardSkeleton();
                      }
                      if (snap.hasError) {
                        return _errorBox('상품 정보를 불러오지 못했어요.\n${snap.error}');
                      }
                      final p = snap.data!;
                      return _RecommendCardFancy(
                        product: p,
                        onDetail: () {
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
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 하단 카드 버튼 2개
                  Row(
                    children: [
                      Expanded(
                        child: _BottomWidgetCard(
                          title: '더 많은 상품\n둘러보기',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DepositListPage()),
                            );
                          },
                          imageAsset: 'assets/images/deposit_product.png',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BottomWidgetCard(
                          title: '오늘의 운세\n확인하고\n커피까지!',
                          onTap: () =>
                              Navigator.pushNamed(context, '/event/fortune'),
                          imageAsset: 'assets/images/coffee.png',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ✅ 홈으로 돌아가기 → 루트('/')로 이동 (내비바가 보이는 AppShell로)
            Positioned(
              left: 20,
              right: 20,
              bottom: 60, // 필요시 여백 조절
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _Brand.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // 스택 비우고 AppShell을 예적금 탭(initialTab: 1)으로 시작
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const AppShell(initialTab: 1)),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    '홈으로 돌아가기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- helpers ---
  static Widget _cardSkeleton() => Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(18),
        ),
      );

  static Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3F3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFCACA)),
        ),
        child: Text(msg, style: const TextStyle(color: Colors.red)),
      );
}

/// 브랜드 토큰
class _Brand {
  static const primary = Color(0xFF2962FF);
  static const ink = Color(0xFF111827);
  static const border = Color(0x1F000000);
  static const glow = Color(0x332962FF);
}

/// ===== 추천 카드(화려) - '추천' 뱃지 제거 버전 =====
class _RecommendCardFancy extends StatelessWidget {
  final DepositProduct product;
  final VoidCallback onDetail;

  const _RecommendCardFancy({
    required this.product,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final maxRateText = '최대 ${product.maxRate.toStringAsFixed(2)}%';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onDetail,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE9F0FF), Color(0xFFFFFFFF)],
          ),
          border: Border.all(color: const Color(0x1A2962FF)),
          boxShadow: const [
            BoxShadow(
                color: _Brand.glow, blurRadius: 24, offset: Offset(0, 10)),
            BoxShadow(
                color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 상품명 (배지 제거)
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _Brand.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 10),

              // 요약
              if (product.summary.isNotEmpty)
                Text(
                  product.summary,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87, height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 14),

              // 최대 금리 강조
              Text(
                maxRateText,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: _Brand.primary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),

              // 기간 칩
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(text: '${product.period}개월'),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0x11000000)),
              const SizedBox(height: 12),

              // CTA: 자세히 보기 (1개만)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _Brand.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onDetail,
                  child: const Text('자세히 보기',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 칩
class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// 하단 추천 위젯 카드
class _BottomWidgetCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final String imageAsset;
  const _BottomWidgetCard({
    required this.title,
    required this.onTap,
    required this.imageAsset,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: const [
            BoxShadow(
                color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Image.asset(imageAsset, width: 48, height: 48),
            ),
          ],
        ),
      ),
    );
  }
}
