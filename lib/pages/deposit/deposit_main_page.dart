import 'dart:async';
import 'package:flutter/material.dart';
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/service/deposit_service.dart';
import 'deposit_detail_page.dart';

class DepositMainPage extends StatefulWidget {
  @override
  State<DepositMainPage> createState() => _DepositMainPageState();
}

class _DepositMainPageState extends State<DepositMainPage> {
  final PageController _bannerController = PageController();
  final TextEditingController _searchController = TextEditingController();

  List<DepositProduct> allProducts = [];
  List<DepositProduct> topViewed = [];
  List<DepositProduct> recommended = [];
  List<DepositProduct> newProducts = [];

  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    fetchData();
    startAutoSlide();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void startAutoSlide() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_bannerController.hasClients) {
        int next = (_bannerController.page?.round() ?? 0) + 1;
        if (next >= 3) next = 0;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void fetchData() async {
    final data = await fetchAllProducts();

    setState(() {
      allProducts = data;
      topViewed = List.from(data)
        ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
      recommended = List.from(data)
        ..sort((a, b) => b.maxRate.compareTo(a.maxRate));
      newProducts = List.from(data)
        ..sort((a, b) => b.productId.compareTo(a.productId));
    });
  }

  void goToDetail(DepositProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DepositDetailPage(productId: product.productId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('BNK 예적금'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔍 검색창
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '상품명 또는 설명 검색',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // 🎞 슬라이드 배너
            SizedBox(
              height: 160,
              child: PageView(
                controller: _bannerController,
                children: [
                  bannerItem("📣 지금 5% 특별금리 적금 출시!", Colors.indigo),
                  bannerItem("🌿 ESG 실천 적금 인기!", Colors.green),
                  bannerItem("🔥 인기 TOP5 예적금 확인하기", Colors.orange),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🗂 예금/적금/입출금 카테고리 바로가기
            categorySection(),

            const SizedBox(height: 20),

            // ⭐ 나를 위한 추천
            sectionTitle("⭐ 나를 위한 금리 높은 추천상품"),
            productSlider(recommended.take(5).toList()),

            const SizedBox(height: 20),

            // 🏷 목적별 추천 (해시태그)
            sectionTitle("🏷 목적별 추천"),
            purposeChips(),

            const SizedBox(height: 20),

            // 🔥 인기 상품 TOP 5
            sectionTitle("🔥 인기 상품 TOP 5"),
            productList(topViewed.take(5).toList()),

            const SizedBox(height: 20),

            // 🆕 신규 출시 상품
            sectionTitle("🆕 신규 출시"),
            productList(newProducts.take(3).toList()),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget bannerItem(String text, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget productSlider(List<DepositProduct> products) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (_, i) {
          final p = products[i];
          return GestureDetector(
            onTap: () => goToDetail(p),
            child: Container(
              width: 240,
              margin: const EdgeInsets.only(
                left: 16,
                right: 8,
                top: 10,
                bottom: 10,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      p.summary,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "최고금리: ${p.maxRate}%",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget productList(List<DepositProduct> products) {
    return Column(
      children: products.map((p) {
        return GestureDetector(
          onTap: () => goToDetail(p),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              title: Text(p.name),
              subtitle: Text(p.summary),
              trailing: Text(
                '${p.maxRate}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget categorySection() {
    final items = [
      {'label': '예금', 'icon': Icons.savings},
      {'label': '적금', 'icon': Icons.account_balance_wallet},
      {'label': '입출금', 'icon': Icons.money},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((item) {
        return Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.indigo[100],
              child: Icon(item['icon'] as IconData, color: Colors.indigo),
            ),
            const SizedBox(height: 4),
            Text(
              item['label'] as String,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget purposeChips() {
    final tags = ["여행자금", "자동차구입", "청년지원", "노후대비", "신혼부부", "육아", "주택청약"];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags
            .map(
              (tag) =>
                  Chip(label: Text(tag), backgroundColor: Colors.indigo[50]),
            )
            .toList(),
      ),
    );
  }
}
