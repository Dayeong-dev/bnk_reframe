import 'dart:async';
import 'dart:ui' as ui; // 글래스/블러
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 심플모드 기억

import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/service/deposit_service.dart';
import 'deposit_detail_page.dart';
import 'package:flutter/services.dart';

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

  // 컬러 토큰
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
      /* ignore */
    }
  }

  Future<void> _saveSimpleMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('simpleMode', _simpleMode);
    } catch (_) {
      /* ignore */
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

  // ============= 공용 데코레이션(흰카드 음영) =============
  BoxDecoration neoDecoration({
    bool pressed = false,
    double radius = 18,
    Color? color,
  }) {
    final c = color ?? Colors.white;
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

  /// 배너에서 직접 ID로 이동 (요청: 69, 70, 73)
  void goToDetailById(int productId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DepositDetailPage(productId: productId),
      ),
    );
  }

  // ============= 이자 계산기 (개선) =============
  // 교체할 메서드 전체
  void showInterestCalculator(BuildContext context, DepositProduct product) {
    final amountController = TextEditingController(text: "1,000,000");
    final FocusNode amountFocus = FocusNode();

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

            void dismissKeyboard() => FocusScope.of(context).unfocus();

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismissKeyboard, // 바깥 탭 시 키보드 닫기
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
                    top: false,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // 상단 그립 + 키보드 내리기 버튼
                          Row(
                            children: [
                              const Spacer(),
                              IconButton(
                                tooltip: '키보드 내리기',
                                onPressed: dismissKeyboard,
                                icon: const Icon(Icons.keyboard_hide),
                              ),
                            ],
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

                          // 요약 박스
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: neoDecoration(),
                            child: Column(
                              children: [
                                _infoLine(
                                  "최대 금리",
                                  "${rate.toStringAsFixed(2)}%",
                                ),
                                const SizedBox(height: 6),
                                _infoLine("기본 가입기간", "${product.period}개월"),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // ✅ 금액 입력 영역 (시각적 강조 + iOS Done 대체 버튼)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: neoDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "예치금액",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: amountController,
                                  focusNode: amountFocus,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  showCursor: true,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    hintText: "금액을 입력하세요 (예: 1,000,000)",
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(
                                        left: 12,
                                        right: 8,
                                      ),
                                      child: Text(
                                        "₩",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 0,
                                      minHeight: 0,
                                    ),
                                    suffixIcon: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: '지우기',
                                            onPressed: () {
                                              amountController.clear();
                                              s(() {}); // 즉시 UI 반영
                                              calculate(s);
                                            },
                                            icon: const Icon(Icons.clear),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              dismissKeyboard();
                                              calculate(s);
                                            },
                                            child: const Text(
                                              "완료",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                        width: 1.2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: _accent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) {
                                    dismissKeyboard();
                                    calculate(s);
                                  },
                                  onChanged: (v) {
                                    final numeric = v.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    );
                                    final formatted = NumberFormat("#,###")
                                        .format(
                                          int.parse(
                                            numeric.isEmpty ? "0" : numeric,
                                          ),
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
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 가입기간 슬라이더
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
    return Scaffold(
      backgroundColor: Colors.white, // ✅ 메인 배경 흰색
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        title: const Text(
          'BNK 예적금',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
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
                        ? _buildSimpleModeSection()
                        : _buildNormalModeSection(),
                  ),
                ),
              ),
            ),
    );
  }

  // === 기본 모드 ===
  List<Widget> _buildNormalModeSection() {
    return [
      // ✅ 이미지 배너 (69 → 70 → 73)
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
                  return bannerImageItem(
                    asset: 'assets/images/069.png',
                    onTap: () => goToDetailById(69),
                  );
                } else if (i == 1) {
                  return bannerImageItem(
                    asset: 'assets/images/070.png',
                    onTap: () => goToDetailById(70),
                  );
                } else {
                  return bannerImageItem(
                    asset: 'assets/images/073.png',
                    onTap: () => goToDetailById(73),
                  );
                }
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

      // 금리 높은 추천(파스텔 서비스 카드 슬라이더)
      sectionTitle("⭐ 금리 높은 추천"),
      productSlider(recommended.take(5).toList()),
      const SizedBox(height: 12),

      // 인기 TOP 5 (세로 카드)
      sectionTitle("🔥 인기 상품 TOP 5"),
      productList(topViewed.take(5).toList()),
    ];
  }

  // === 심플 모드 ===
  List<Widget> _buildSimpleModeSection() {
    final accent = _accent;

    return [
      const SizedBox(height: 12),

      // 카테고리 바로가기
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
                horizontalPadding: 8,
                verticalPadding: 12,
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

      // 빠른 기능
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

      // 추천 리스트 (심플 카드)
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
  Widget bannerImageItem({required String asset, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: neoDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(asset, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
    );
  }

  Widget productSlider(List<DepositProduct> products) {
    final pastelSets = [
      [const Color(0xFFEAF4FF), const Color(0xFFD7ECFF)],
      [const Color(0xFFE8FFF6), const Color(0xFFD4F7EA)],
      [const Color(0xFFFFF2E5), const Color(0xFFFFE7CC)],
      [const Color(0xFFF3EEFF), const Color(0xFFE8E1FF)],
    ];

    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (_, i) {
          final p = products[i];
          final colors = pastelSets[i % pastelSets.length];
          final bigIcon = _serviceIconFor(p);
          final hashtag = _hashtagFrom(p.purpose, p.name);

          return Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 16 : 10,
              right: i == products.length - 1 ? 16 : 10,
              top: 8,
              bottom: 12,
            ),
            child: _TapScale(
              onTap: () => goToDetail(p),
              child: _PastelServiceCard(
                title: p.name,
                subtitle: "최고 ${p.maxRate.toStringAsFixed(2)}% · ${p.period}개월",
                bg1: colors[0],
                bg2: colors[1],
                bigIcon: bigIcon,
                hashtag: hashtag,
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

  IconData _serviceIconFor(DepositProduct p) {
    final name = (p.name).toLowerCase();
    if (name.contains('아이사랑')) return Icons.favorite;
    if (name.contains('사랑')) return Icons.favorite;
    if (name.contains('카드')) return Icons.credit_card;
    if (name.contains('입출금') || name.contains('통장'))
      return Icons.account_balance;
    if (name.contains('저탄소') || name.contains('친환경') || name.contains('그린'))
      return Icons.eco;
    if (name.contains('청년') || name.contains('청년도약'))
      return Icons.rocket_launch;
    if (name.contains('아기') || name.contains('아기천사') || name.contains('유아'))
      return Icons.child_care;
    if (name.contains('실버') || name.contains('백세') || name.contains('시니어'))
      return Icons.elderly;
    if (name.contains('장병') || name.contains('군')) return Icons.military_tech;
    if (name.contains('펫') || name.contains('반려')) return Icons.pets;
    if (name.contains('적금')) return Icons.savings;
    if (name.contains('예금')) return Icons.account_balance_wallet;
    return Icons.auto_awesome;
  }

  String _hashtagFrom(String? purpose, String name) {
    String raw = (purpose ?? '').trim();
    if (raw.isEmpty) {
      if (name.contains('청년'))
        raw = '청년';
      else if (name.contains('시니어') || name.contains('실버'))
        raw = '시니어';
      else if (name.contains('펫') || name.contains('반려'))
        raw = '반려생활';
      else if (name.contains('저탄소') || name.contains('그린'))
        raw = '친환경';
      else if (name.contains('장병') || name.contains('군'))
        raw = '장병우대';
      else
        raw = '목돈만들기';
    }
    final cleaned = raw
        .replaceAll(RegExp(r'[^ㄱ-ㅎ가-힣A-Za-z0-9 ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '');
    return '#$cleaned';
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

class _PastelServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color bg1;
  final Color bg2;
  final IconData bigIcon;
  final String hashtag;

  const _PastelServiceCard({
    required this.title,
    required this.subtitle,
    required this.bg1,
    required this.bg2,
    required this.bigIcon,
    required this.hashtag,
  });

  @override
  Widget build(BuildContext context) {
    const double w = 250;
    const double h = 150;

    return SizedBox(
      width: w,
      height: h,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [bg1, bg2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 16,
              bottom: 14,
              child: Row(
                children: [
                  Text(
                    hashtag,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.75),
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _coin(),
                  const SizedBox(width: 6),
                  _coin(small: true),
                ],
              ),
            ),
            Positioned(
              right: -8,
              bottom: -12,
              child: Icon(
                bigIcon,
                size: 120,
                color: Colors.grey.shade500.withOpacity(0.92),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coin({bool small = false}) {
    final size = small ? 16.0 : 20.0;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Text(
          "₩",
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _BigPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color accent;
  final double horizontalPadding;
  final double verticalPadding;
  final bool showIcon;

  const _BigPrimaryButton({
    required this.label,
    this.icon,
    required this.onTap,
    required this.accent,
    this.horizontalPadding = 16,
    this.verticalPadding = 16,
    this.showIcon = true,
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("추천으로 이동")));
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(right: 8),
              decoration: neoBox(),
              child: const Column(
                children: [
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("근처 지점으로 이동")));
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(left: 8),
              decoration: neoBox().copyWith(color: Colors.green.shade50),
              child: const Column(
                children: [
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
          Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
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
              const Text(
                "기간 ",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                "${p.period}개월",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 22),
                  label: const Text("상세보기"),
                  onPressed: onDetail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
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
