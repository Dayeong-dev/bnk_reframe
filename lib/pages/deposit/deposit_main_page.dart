import 'dart:async';
import 'dart:ui' as ui; // 글래스/블러
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 심플모드 기억

import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/service/deposit_service.dart';
import 'deposit_detail_page.dart';

/// 통화 포맷터: 1,000 단위 콤마
String formatCurrency(int value) => NumberFormat("#,###").format(value);

class DepositMainPage extends StatefulWidget {
  @override
  State<DepositMainPage> createState() => _DepositMainPageState();
}

class _DepositMainPageState extends State<DepositMainPage> {
  // ============= 상태/컨트롤러 =============
  late final PageController _bannerController;
  final TextEditingController _searchController = TextEditingController();

  List<DepositProduct> allProducts = [];
  List<DepositProduct> topViewed = [];
  List<DepositProduct> recommended = [];

  Timer? _bannerTimer;

  // 배너 상태
  int _currentDot = 0; // 페이지 인디케이터용(0~_pageCount-1)
  int _currentAbsPage = 0; // 절대 페이지 인덱스 (무한 캐러셀용)
  final int _pageCount = 3; // 배너 개수
  final int _loopSeed = 1000; // 초기 배수 (무한 루프처럼 보이게)

  // 컬러 토큰 (은행앱 톤)
  final Color _bg = const Color(0xFFF5F7FA);
  final Color _base = Colors.white;
  final Color _ink = const Color(0xFF111827);
  final Color _accent = const Color(0xFF304FFE); // 인디고 계열 고정

  bool _isAutoSlide = true;
  bool _isLoading = true;

  // ✅ 시니어 심플모드 (저장/로드)
  bool _simpleMode = false;
  Future<void> _loadSimpleMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() => _simpleMode = prefs.getBool('simpleMode') ?? false);
    } catch (_) {
      /* 저장 안해도 동작 */
    }
  }

  Future<void> _saveSimpleMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('simpleMode', _simpleMode);
    } catch (_) {
      /* 저장 실패는 무시 */
    }
  }

  // ============= 라이프사이클 =============
  @override
  void initState() {
    super.initState();
    _bannerController = PageController(
      viewportFraction: 0.92,
      initialPage: _loopSeed * _pageCount, // ✅ 무한 순환 느낌
    );
    _currentAbsPage = _bannerController.initialPage;

    fetchData();
    startAutoSlide();
    _loadSimpleMode(); // ✅ 심플모드 기억 불러오기
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============= 데이터 로드 =============
  Future<void> fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await fetchAllProducts();
      setState(() {
        allProducts = data;
        topViewed = List.from(data)
          ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
        recommended = List.from(data)
          ..sort((a, b) => b.maxRate.compareTo(a.maxRate));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('상품 불러오기 실패: $e')));
    }
  }

  // ============= 배너 자동 슬라이드 =============
  void startAutoSlide() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isAutoSlide || !_bannerController.hasClients) return;
      final curr = _bannerController.page?.round() ?? _currentAbsPage;
      _bannerController.animateToPage(
        curr + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  // ============= 공용 데코레이션(네오모픽) =============
  BoxDecoration neoDecoration({
    bool pressed = false,
    double radius = 18,
    Color? color,
  }) {
    final c = color ?? _base;
    if (pressed) {
      return BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(6, 6),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 10,
            offset: const Offset(-6, -6),
          ),
        ],
      );
    }
    return BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 18,
          offset: const Offset(8, 8),
        ),
        const BoxShadow(
          color: Colors.white,
          blurRadius: 14,
          offset: Offset(-8, -8),
        ),
      ],
    );
  }

  // ============= 상세/계산기 이동 =============
  void goToDetail(DepositProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DepositDetailPage(productId: product.productId),
        settings: const RouteSettings(name: '/deposit/detail'),
      ),
    );
  }

  void showInterestCalculator(BuildContext context, DepositProduct product) {
    final amountController = TextEditingController(text: "1,000,000");
    int months = product.period > 0 ? product.period : 1;
    final double rate = product.maxRate;
    int interestResult = 0;

    void calculate(StateSetter s) {
      final amount =
          int.tryParse(amountController.text.replaceAll(",", "")) ?? 0;
      final interest = (amount * (rate / 100) * (months / 12)).round();
      s(() => interestResult = interest);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, s) {
            if (interestResult == 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) => calculate(s));
            }
            final amount =
                int.tryParse(amountController.text.replaceAll(",", "")) ?? 0;
            final total = amount + interestResult;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 30,
                      spreadRadius: 6,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Text(
                          "📊 ${product.name} 이자 계산기",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: neoDecoration(),
                          child: Column(
                            children: [
                              _infoLine("최대 금리", "${rate.toStringAsFixed(2)}%"),
                              const SizedBox(height: 6),
                              _infoLine("기본 가입기간", "${product.period}개월"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          decoration: neoDecoration(),
                          child: TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "예치금액 (원)",
                              prefixIcon: const Icon(Icons.payments),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            onChanged: (v) {
                              final numeric = v.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              final formatted = NumberFormat("#,###").format(
                                int.parse(numeric.isEmpty ? "0" : numeric),
                              );
                              amountController.value = TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(
                                  offset: formatted.length,
                                ),
                              );
                              calculate(s);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "가입기간",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                            Text(
                              "$months 개월",
                              style: TextStyle(color: _ink.withOpacity(0.7)),
                            ),
                          ],
                        ),
                        Slider(
                          value: months.toDouble(),
                          min: 1,
                          max: 36,
                          divisions: 35,
                          label: "$months 개월",
                          activeColor: _accent,
                          onChanged: (v) {
                            months = v.toInt();
                            s(() {});
                            calculate(s);
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "예상 이자수익",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: interestResult),
                          duration: const Duration(milliseconds: 680),
                          curve: Curves.easeOutCubic,
                          builder: (_, value, __) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              "${formatCurrency(value)} 원",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: _accent,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: neoDecoration(),
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              resultRow("예치금", "${formatCurrency(amount)} 원"),
                              resultRow(
                                "이자수익",
                                "${formatCurrency(interestResult)} 원",
                              ),
                              resultRow(
                                "총 수령액",
                                "${formatCurrency(total)} 원",
                                highlight: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: _accent,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          child: const Text("닫기"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============= 빌드 =============
  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _ink,
        title: const Text(
          'BNK 예적금',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          // 검색 → 목록 페이지
          IconButton(
            tooltip: '검색',
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DepositListPage(initialCategory: '전체'),
                  settings: const RouteSettings(name: '/depositList'),
                ),
              );
            },
          ),
          // ✅ 시니어 심플모드 토글
          // ✅ 심플모드 토글 (아이콘 없음, 라벨만: 심플모드 ↔ 기본보기)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: _simpleMode
                    ? _accent.withOpacity(0.12)
                    : Colors.grey.shade200,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              onPressed: () async {
                setState(() => _simpleMode = !_simpleMode);
                await _saveSimpleMode();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_simpleMode ? '심플모드로 전환됨' : '기본보기로 전환됨'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Text(
                _simpleMode ? '기본보기' : '크게보기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _simpleMode ? _accent : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text("상품 정보를 불러오는 중입니다...", style: TextStyle(fontSize: 15)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _simpleMode
                        ? _buildSimpleModeSection() // ✅ 심플모드
                        : _buildNormalModeSection(), // ✅ 기본모드
                  ),
                ),
              ),
            ),
    );

    // ✅ 심플모드일 때 전체 글자/터치 여백 살짝 키우기
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_bg, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: MediaQuery(
        data: _simpleMode
            ? MediaQuery.of(context).copyWith(textScaleFactor: 1.18)
            : MediaQuery.of(context),
        child: scaffold,
      ),
    );
  }

  // === 기본 모드: 기존 섹션들 ===
  List<Widget> _buildNormalModeSection() {
    return [
      // 배너
      SizedBox(
        height: 164,
        child: Stack(
          children: [
            PageView.builder(
              controller: _bannerController,
              onPageChanged: (idx) {
                _currentAbsPage = idx;
                setState(() => _currentDot = idx % _pageCount);
              },
              itemBuilder: (_, idx) {
                final i = idx % _pageCount;
                if (i == 0) {
                  return bannerItem("📣 5% 특별금리 적금 출시!", _accent);
                } else if (i == 1) {
                  return bannerItem(
                    "🌿 저탄소 실천 적금 인기!",
                    const Color(0xFF10B981),
                  );
                }
                return bannerItem(
                  "🔥 인기 TOP5 예적금 확인하기",
                  const Color(0xFFFF8A00),
                );
              },
            ),
            // 인디케이터 + 일시정지
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: List.generate(_pageCount, (i) {
                      final active = _currentDot == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: active ? 18 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: active
                              ? _accent
                              : Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: _accent.withOpacity(0.35),
                                    blurRadius: 8,
                                  ),
                                ]
                              : [],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setState(() => _isAutoSlide = !_isAutoSlide),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isAutoSlide ? Icons.pause : Icons.play_arrow,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 18),
      // 카테고리 단축
      categorySection(context),
      const SizedBox(height: 18),

      // 추천 & 근처 지점
      shortcutRow(context),
      const SizedBox(height: 18),

      // 금리 높은 추천(네온 글래스 카드)
      sectionTitle("⭐ 금리 높은 추천"),
      productSlider(recommended.take(5).toList()),
      const SizedBox(height: 12),

      // 인기 TOP 5 (세로 카드)
      sectionTitle("🔥 인기 상품 TOP 5"),
      productList(topViewed.take(5).toList()),
    ];
  }

  // === 심플 모드: 큰 글씨/큰 버튼/높은 대비 + 기본 톤과 조화
  List<Widget> _buildSimpleModeSection() {
    final accent = _accent;

    return [
      const SizedBox(height: 12),

      // ⬇️ [심플모드] 카테고리 바로가기 (예금/적금/입출금)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _BigPrimaryButton(
                label: "예금",
                icon: Icons.savings,
                accent: accent,
                showIcon: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DepositListPage(initialCategory: '예금'),
                          settings: const RouteSettings(name: '/depositList'),
                    ),
                  );
                },
                horizontalPadding: 8, // 좌우 패딩 축소
                verticalPadding: 12, // 세로 패딩 축소
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigPrimaryButton(
                label: "적금",
                icon: Icons.account_balance_wallet,
                accent: accent,
                showIcon: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DepositListPage(initialCategory: '적금'),
                          settings: const RouteSettings(name: '/depositList'),
                    ),
                  );
                },
                horizontalPadding: 8,
                verticalPadding: 12,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigPrimaryButton(
                label: "입출금",
                icon: Icons.money,
                accent: accent,
                showIcon: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DepositListPage(initialCategory: '입출금'),
                          settings: const RouteSettings(name: '/depositList'),
                    ),
                  );
                },
                horizontalPadding: 8,
                verticalPadding: 12,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // 빠른 기능 2개 (내 추천 / 근처 지점) — 상담원 연결 제거
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _BigPrimaryButton(
                label: "내 추천",
                icon: Icons.recommend,
                accent: accent,
                onTap: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("추천으로 이동")));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigPrimaryButton(
                label: "근처 지점",
                icon: Icons.location_on,
                accent: accent,
                onTap: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("근처 지점으로 이동")));
                },
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 20),

      // 추천 리스트 (최소 정보, 큰 글씨, 톤 통일)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          "추천 상품",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
          ),
        ),
      ),
      const SizedBox(height: 8),

      ...topViewed
          .take(4)
          .map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _SimpleProductCard(
                p: p,
                accent: accent,
                onDetail: () => goToDetail(p),
                onCalc: () => showInterestCalculator(context, p),
              ),
            ),
          ),
    ];
  }

  // ============= 위젯들 =============
  Widget bannerItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Container(
        decoration: neoDecoration(),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.88), color.withOpacity(0.66)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 22,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  /// ▶ 화려한 글래스 + 네온 그라데이션 카드 슬라이더 (최고금리 강조)
  Widget productSlider(List<DepositProduct> products) {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (_, i) {
          final p = products[i];
          return Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 16 : 10,
              right: i == products.length - 1 ? 16 : 10,
              top: 8,
              bottom: 14,
            ),
            child: _TapScale(
              onTap: () => goToDetail(p),
              child: _FancyProductCard(
                name: p.name,
                period: p.period,
                maxRate: p.maxRate,
                accent: _accent,
              ),
            ),
          );
        },
      ),
    );
  }

  /// 세로 리스트 카드(이자계산 버튼 포함)
  Widget productList(List<DepositProduct> products) {
    return Column(
      children: products.map((p) {
        return GestureDetector(
          onTap: () => goToDetail(p),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 좌: 상품 이름 + 기간
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "가입기간: ${p.period}개월",
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // 중: 금리 배지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "최고 ${p.maxRate.toStringAsFixed(2)}%",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 우: 이자 계산 버튼
                InkWell(
                  onTap: () => showInterestCalculator(context, p),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calculate,
                        size: 20,
                        color: Colors.indigo.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "이자 계산",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 카테고리 바로가기
  Widget categorySection(BuildContext context) {
    final items = [
      {
        'label': '예금',
        'display': '목돈굴리기',
        'icon': Icons.savings,
        'bg1': const Color(0xFF304FFE),
        'bg2': const Color(0xFF8C9EFF),
      },
      {
        'label': '적금',
        'display': '목돈만들기',
        'icon': Icons.account_balance_wallet,
        'bg1': const Color(0xFF10B981),
        'bg2': const Color(0xFF34D399),
      },
      {
        'label': '입출금',
        'display': '입출금',
        'icon': Icons.money,
        'bg1': const Color(0xFFFF8A00),
        'bg2': const Color(0xFFFFC046),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.map((item) {
          return _TapScale(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DepositListPage(initialCategory: item['label'] as String),
                      settings: const RouteSettings(name: '/depositList'),
                ),
              );
            },
            child: Container(
              width: 104,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: neoDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 원형 그라데이션 캡슐
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [item['bg1'] as Color, item['bg2'] as Color],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(item['icon'] as IconData, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['display'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ====== 공용 소품 위젯 ======
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

class _RateBadge extends StatelessWidget {
  final double rate;
  final bool light; // 배경 밝기 옵션(배너 위에서 흰 텍스트)
  const _RateBadge({required this.rate, this.light = false});
  @override
  Widget build(BuildContext context) {
    final textColor = light ? Colors.white : Colors.red;
    final bgColor = light
        ? Colors.white.withOpacity(0.15)
        : Colors.red.withOpacity(0.08);
    final borderColor = light
        ? Colors.white.withOpacity(0.3)
        : Colors.red.withOpacity(0.25);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        "최고금리 ${rate.toStringAsFixed(2)}%",
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _TapScale({required this.child, this.onTap});
  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: InkWell(
          onTap: widget.onTap,
          child: widget.child,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

/// 네온 그라데이션 보더 + 글래스 카드 + 빛반사 애니메이션
class _FancyProductCard extends StatefulWidget {
  final String name;
  final int period;
  final double maxRate;
  final Color accent;

  const _FancyProductCard({
    required this.name,
    required this.period,
    required this.maxRate,
    required this.accent,
  });

  @override
  State<_FancyProductCard> createState() => _FancyProductCardState();
}

class _FancyProductCardState extends State<_FancyProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 카드 크기
    const double cardW = 250;
    const double cardH = 160;

    return SizedBox(
      width: cardW,
      height: cardH,
      child: AnimatedBuilder(
        animation: _ac,
        builder: (_, __) {
          // 네온 보더용 그라데이션 위치를 살짝 이동시켜 반짝임
          final t = _ac.value;
          final colors = [
            widget.accent,
            Colors.purpleAccent,
            Colors.orangeAccent,
            widget.accent,
          ];

          return Container(
            // 바깥: 네온 그라데이션 보더
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                stops: [
                  0.0,
                  (0.3 + t * 0.2).clamp(0.0, 1.0),
                  (0.7 + t * 0.2).clamp(0.0, 1.0),
                  1.0,
                ],
                begin: Alignment(-1 + t, -1),
                end: Alignment(1 - t, 1),
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withOpacity(0.28),
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2), // 보더 두께
              // 안쪽: 글래스(반투명) 카드
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // 유리 블러
                    BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),

                    // 대각선 하이라이트(빛 반사)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.20,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1, -1),
                                end: Alignment(1, 1),
                                colors: [Colors.white24, Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 내용
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 상단: 최고금리 배지 (커다랗게)
                          Align(
                            alignment: Alignment.topRight,
                            child: _BigRateBadge(
                              rate: widget.maxRate,
                              accent: widget.accent,
                            ),
                          ),
                          const Spacer(),
                          // 상품명
                          Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // 가입기간 칩
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: widget.accent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: widget.accent.withOpacity(0.18),
                              ),
                            ),
                            child: Text(
                              "가입기간 ${widget.period}개월",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: widget.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 커다란 최고금리 배지(그라데이션 텍스트 + 은은한 글로우)
class _BigRateBadge extends StatelessWidget {
  final double rate;
  final Color accent;
  const _BigRateBadge({required this.rate, required this.accent});

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: [accent, Colors.purpleAccent, Colors.orangeAccent],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Text(
              "최고금리",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
          ShaderMask(
            shaderCallback: (rect) => gradient.createShader(rect),
            child: Text(
              "${rate.toStringAsFixed(2)}%",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white, // ShaderMask가 덮어씀
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 심플모드 공통: 큰 버튼(브랜드 컬러 톤, 높은 대비, 넓은 터치)
class _BigPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon; // ✅ nullable
  final VoidCallback onTap;
  final Color accent;
  final double horizontalPadding;
  final double verticalPadding;
  final bool showIcon; // ✅ 아이콘 표시 여부

  const _BigPrimaryButton({
    required this.label,
    this.icon, // ✅ required 제거
    required this.onTap,
    required this.accent,
    this.horizontalPadding = 16, // 기본값
    this.verticalPadding = 16, // 기본값
    this.showIcon = true, // 기본은 아이콘 보이기
  });

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
    );

    // ✅ 아이콘 표시 여부에 따라 분기
    if (showIcon && icon != null) {
      return SizedBox(
        height: 64,
        child: ElevatedButton.icon(
          icon: Icon(icon, size: 22),
          label: Text(label),
          onPressed: onTap,
          style: style,
        ),
      );
    } else {
      return SizedBox(
        height: 64,
        child: ElevatedButton(
          onPressed: onTap,
          style: style,
          child: Text(label),
        ),
      );
    }
  }
}

// 심플모드 카드: 큰 글자/최고금리 강조, 룩앤필 통일(라운드+그림자)
class _SimpleProductCard extends StatelessWidget {
  final DepositProduct p;
  final Color accent;
  final VoidCallback onDetail;
  final VoidCallback onCalc;

  const _SimpleProductCard({
    required this.p,
    required this.accent,
    required this.onDetail,
    required this.onCalc,
  });

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
      const BoxShadow(
        color: Colors.white,
        blurRadius: 6,
        offset: Offset(-2, -2),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상품명 크게
          Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          // 최고금리 강조(브랜드 컬러 배지) + 기간
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.24)),
                ),
                child: Text(
                  "최고 ${p.maxRate.toStringAsFixed(2)}%",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "기간 ${p.period}개월",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 큰 버튼 두 개
          Row(
            children: [
              Expanded(
                child: _BigPrimaryButton(
                  label: "상세보기",
                  icon: Icons.open_in_new,
                  onTap: onDetail,
                  accent: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calculate, size: 22),
                  label: const Text("이자 계산"),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: accent, width: 2),
                    foregroundColor: accent,
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onCalc,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 추천/근처 지점 바로가기(톤 맞춤)
Widget shortcutRow(BuildContext context) {
  final baseColor = Colors.white;
  final borderRadius = BorderRadius.circular(20);

  BoxDecoration neoBox() => BoxDecoration(
    color: baseColor,
    borderRadius: borderRadius,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 12,
        offset: const Offset(8, 8),
      ),
      BoxShadow(
        color: Colors.white.withOpacity(0.9),
        blurRadius: 12,
        offset: const Offset(-6, -6),
      ),
    ],
  );

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () {
              // TODO: 추천 상품 화면으로 연결
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(right: 8),
              decoration: neoBox(),
              child: Column(
                children: const [
                  Icon(Icons.recommend, size: 36, color: Colors.indigo),
                  SizedBox(height: 10),
                  Text(
                    "🧠 추천 상품",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.indigo,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "개인 맞춤 추천",
                    style: TextStyle(fontSize: 13, color: Colors.indigo),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () {
              // TODO: 근처 지점 지도 화면 연결
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(left: 8),
              decoration: neoBox().copyWith(color: Colors.green.shade50),
              child: Column(
                children: const [
                  Icon(Icons.location_on, size: 36, color: Colors.green),
                  SizedBox(height: 10),
                  Text(
                    "📍 근처 지점",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "현재 위치 기반",
                    style: TextStyle(fontSize: 13, color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
