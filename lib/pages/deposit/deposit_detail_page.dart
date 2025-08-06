import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/service/deposit_service.dart';

class DepositDetailPage extends StatefulWidget {
  final int productId;
  const DepositDetailPage({super.key, required this.productId});

  @override
  State<DepositDetailPage> createState() => _DepositDetailPageState();
}

class _DepositDetailPageState extends State<DepositDetailPage> {
  DepositProduct? product;

  @override
  void initState() {
    super.initState();
    loadProduct();
  }

  void loadProduct() async {
    try {
      final result = await fetchProduct(widget.productId);

      // 🔍 디버깅용 로그 출력
      print("✅ 상품 이름: ${result.name}");
      print("🟠 modalDetail 길이: ${result.modalDetail.length}");
      print("🟠 modalRate 길이: ${result.modalRate.length}");
      print("🟢 modalDetail preview:\n${result.modalDetail.substring(0, 100)}");
      print("🟢 modalRate preview:\n${result.modalRate.substring(0, 100)}");

      setState(() {
        product = result;
      });
    } catch (e) {
      print("❌ 상품 불러오기 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (product == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(product!.name),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(product!),
          const SizedBox(height: 24),
          _buildDetailBody(product!),
          const SizedBox(height: 32),
          _buildFooterSection(product!),
        ],
      ),
    );
  }

  Widget _buildHeader(DepositProduct product) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "[BNK 부산은행]",
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            product.summary
                .replaceAll('<br>', '\n')
                .replaceAll('<br/>', '  ')
                .replaceAll('<br />', ''),
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            "최고금리: ${product.maxRate}%",
            style: TextStyle(color: Colors.white),
          ),
          Text(
            "최저금리: ${product.minRate}%",
            style: TextStyle(color: Colors.white),
          ),
          Text(
            "가입기간: ${product.period}개월",
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// DETAIL 영역 파싱 (JSON or HTML 자동 판별)
  Widget _buildDetailBody(DepositProduct product) {
    final detail = product.detail.trim();

    print("detail 정보: " + detail);

    // HTML 태그로 시작하면 바로 HtmlWidget() 처리
    if (detail.startsWith("<")) {
      print("💡 DETAIL은 HTML 형식 → HtmlWidget으로 처리");
      return HtmlWidget(detail);
    }

    try {
      final decodedOnce = jsonDecode(detail);

      final decoded = decodedOnce is String
          ? jsonDecode(decodedOnce)
          : decodedOnce;

      if (decoded is List &&
          decoded.isNotEmpty &&
          decoded.first is Map<String, dynamic>) {
        print("✅ DETAIL은 JSON 형식이고, 섹션 수: ${decoded.length}");
        return Column(
          children: decoded
              .asMap()
              .entries
              .map(
                (entry) => _buildDetailSection(
                  entry.key,
                  Map<String, dynamic>.from(entry.value),
                ),
              )
              .toList(),
        );
      } else {
        print("⚠️ JSON 파싱 성공했지만 형식이 예상과 다름 → HtmlWidget으로 처리");
        return HtmlWidget(detail);
      }
    } catch (e, s) {
      print("❌ DETAIL 파싱 실패: $e");
      return HtmlWidget(detail); // fallback
    }
  }

  Widget _buildDetailSection(int index, Map<String, dynamic> e) {
    print("🔧 섹션 렌더링 시작: $index");

    final isReversed = index % 2 == 1;
    final String title = e['title'] ?? '제목 없음';
    final String content = e['content'] ?? '';

    final String rawImageUrl = e['imageURL'] ?? '';
    final String imageUrl = rawImageUrl.startsWith('/')
        ? 'assets$rawImageUrl'
        : rawImageUrl;

    print("🖼️ 이미지 원본: $rawImageUrl → 변환: $imageUrl");

    return Container(
      color: isReversed ? Colors.grey[200] : Colors.white,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(content),
          const SizedBox(height: 16),
          if (imageUrl.trim().isNotEmpty)
            Center(
              child: Column(
                children: [
                  ClipOval(
                    child: Container(
                      width: 160,
                      height: 160,
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: imageUrl.startsWith("http")
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const CircularProgressIndicator();
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print("❌ Image.network 에러: $imageUrl\n$error");
                                return const Icon(Icons.broken_image);
                              },
                            )
                          : Image.asset(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                print("❌ Image.asset 로딩 실패: $imageUrl");
                                print("🪵 error: $error");
                                print("🪵 stackTrace: $stackTrace");
                                return const Icon(Icons.broken_image, size: 48);
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 상품안내 + 금리이율 안내 (ExpansionTile로 출력)
  Widget _buildFooterSection(DepositProduct product) {
    return Column(
      children: [
        ExpansionTile(
          title: const Text("상품안내"),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: product!.modalDetail.trim().isEmpty
                  ? const Text("❗ 상품안내 정보가 없습니다.")
                  : HtmlWidget(product!.modalDetail),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text("금리/이율 안내"),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: product!.modalRate.trim().isEmpty
                  ? const Text("❗ 금리/이율 정보가 없습니다.")
                  : HtmlWidget(product!.modalRate),
            ),
          ],
        ),
      ],
    );
  }
}
