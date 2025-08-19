import 'package:flutter/material.dart';
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
        body: SafeArea(
          child: Center(
            child: Text('알 수 없는 결과 유형: $code'),
          ),
        ),
      );
    }

    final title = getRecommendationText(code);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            /// 메인 콘텐츠
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),

                  // 결과 문구
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 추천 상품 카드
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
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (p.imageUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    p.imageUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            if (p.summary.isNotEmpty)
                              Text(
                                p.summary,
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _chip('최대 ${p.maxRate.toStringAsFixed(2)}%'),
                                _chip('${p.period}개월'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DepositDetailPage(productId: p.productId),
                                    settings: const RouteSettings(
                                        name: '/deposit/detail'),
                                  ),
                                );
                              },
                              child: const Text('자세히 보기'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

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
                                builder: (_) => const DepositListPage(),
                              ),
                            );
                          },
                          imageAsset: 'assets/images/deposit_product.png',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BottomWidgetCard(
                          title: '오늘의 운세\n확인하고\n커피까지!',
                          onTap: () => Navigator.pushNamed(context, '/fortune'),
                          imageAsset: 'assets/images/coffee.png',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            /// "처음으로 돌아가기" 버튼 고정 위치
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.2, // 화면 하단에서 20% 위
              left: 0,
              right: 0,
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                          (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text(
                    '처음으로 돌아가기',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // helpers
  static Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );

  static Widget _cardSkeleton() => Container(
    height: 100,
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(14),
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
              color: Color(0x11000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            )
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
                  fontWeight: FontWeight.w700,
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
