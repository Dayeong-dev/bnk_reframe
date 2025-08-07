import 'dart:async';
import 'package:flutter/material.dart';
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/service/deposit_service.dart';
import 'deposit_detail_page.dart';
import 'package:intl/intl.dart';

String formatCurrency(int value) {
  return NumberFormat("#,###").format(value);
}

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

  void showInterestCalculator(BuildContext context, DepositProduct product) {
    final amountController = TextEditingController(text: "1,000,000");
    int months = product.period > 0 ? product.period : 1;
    double rate = product.maxRate;
    int interestResult = 0;

    void calculateInterest(StateSetter setState) {
      final amount =
          int.tryParse(amountController.text.replaceAll(",", "")) ?? 0;
      final interest = (amount * (rate / 100) * (months / 12)).round();
      setState(() => interestResult = interest);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (interestResult == 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                calculateInterest(setState);
              });
            }

            final amount =
                int.tryParse(amountController.text.replaceAll(",", "")) ?? 0;
            final total = amount + interestResult;
            final percent = total == 0 ? 0.0 : interestResult / total;

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          "📊 ${product.name}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 카드 정보
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.indigo.shade100, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.shade50,
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _infoLine("최대금리", "$rate%"),
                            _infoLine("기본 가입기간", "${product.period} 개월"),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 예치금액 입력
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: "예치금액 (원)",
                          prefixIcon: const Icon(Icons.payments),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          final numeric = value.replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          );
                          final formatted = NumberFormat(
                            "#,###",
                          ).format(int.parse(numeric.isEmpty ? "0" : numeric));
                          amountController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                          calculateInterest(setState);
                        },
                      ),
                      const SizedBox(height: 24),

                      // 슬라이더
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "가입기간",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text("$months 개월"),
                        ],
                      ),
                      Slider(
                        value: months.toDouble(),
                        min: 1,
                        max: 36,
                        divisions: 35,
                        label: "$months 개월",
                        activeColor: Colors.indigo,
                        onChanged: (val) {
                          setState(() => months = val.toInt());
                          calculateInterest(setState);
                        },
                      ),
                      const SizedBox(height: 12),

                      // 애니메이션 이자 수익
                      Center(
                        child: const Text(
                          "예상 이자수익",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Center(
                        child: TweenAnimationBuilder(
                          tween: IntTween(begin: 0, end: interestResult),
                          duration: const Duration(milliseconds: 700),
                          builder: (_, value, __) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                "${formatCurrency(value)} 원",
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // 요약
                      _infoLine("예치금", "${formatCurrency(amount)} 원"),
                      _infoLine("이자수익", "${formatCurrency(interestResult)} 원"),
                      _infoLine(
                        "총 수령액",
                        "${formatCurrency(total)} 원",
                        highlight: true,
                      ),

                      const SizedBox(height: 28),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.indigo,
                          ),
                          child: const Text("닫기"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
            categorySection(context),

            const SizedBox(height: 20),

            shortcutRow(context),
            SizedBox(height: 20),

            // ⭐ 나를 위한 추천
            sectionTitle("⭐ 나를 위한 금리 높은 추천상품"),
            productSlider(recommended.take(5).toList()),

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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상품명
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 요약 설명 (줄바꿈 처리)
                  Text(
                    p.summary.replaceAll('<br>', '\n'),
                    style: TextStyle(color: Colors.grey[700], height: 1.4),
                  ),

                  const SizedBox(height: 10),

                  // 최고금리
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.trending_up,
                            size: 16,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "최고금리: ${p.maxRate}%",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "가입기간: ${p.period}개월",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),

                      // 이자 계산기 버튼
                      TextButton.icon(
                        onPressed: () => showInterestCalculator(context, p),
                        icon: const Icon(Icons.calculate, size: 18),
                        label: const Text("이자 계산기"),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          foregroundColor: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget categorySection(BuildContext context) {
    final items = [
      {'label': '예금', 'icon': Icons.savings},
      {'label': '적금', 'icon': Icons.account_balance_wallet},
      {'label': '입출금', 'icon': Icons.money},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((item) {
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DepositListPage(initialCategory: item['label'] as String),
              ),
            );
          },
          child: Column(
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
          ),
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

Widget resultRow(String label, String value, {bool highlight = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: highlight ? Colors.indigo : Colors.black,
          ),
        ),
      ],
    ),
  );
}

Widget _infoLine(String label, String value, {bool highlight = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: highlight ? Colors.indigo : Colors.black,
          ),
        ),
      ],
    ),
  );
}

Widget shortcutRow(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        // 🧠 추천 상품
        Expanded(
          child: InkWell(
            onTap: () {
              print("추천 상품으로 이동"); // 나중에 Navigator.push로 교체
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: const [
                  Icon(Icons.recommend, size: 32, color: Colors.indigo),
                  SizedBox(height: 8),
                  Text(
                    "🧠 추천 상품",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text("개인 맞춤 추천", style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),

        // 📍 근처 영업점
        Expanded(
          child: InkWell(
            onTap: () {
              print("근처 지점으로 이동"); // 나중에 Navigator.push로 교체
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: const [
                  Icon(Icons.location_on, size: 32, color: Colors.green),
                  SizedBox(height: 8),
                  Text(
                    "📍 근처 지점",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text("현재 위치 기반", style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
