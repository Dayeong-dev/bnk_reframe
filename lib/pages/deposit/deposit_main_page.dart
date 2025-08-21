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
import 'package:reframe/pages/branch/map_page.dart';

/// 통화 포맷터: 1,000 단위 콤마
String formatCurrency(int value) => NumberFormat("#,###").format(value);

void pushNamedRoot(BuildContext context, String routeName,
    {Object? arguments}) {
  Navigator.of(context, rootNavigator: true)
      .pushNamed(routeName, arguments: arguments);
}

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

  // ============= 이자 계산기 (경계/구획 강조 개선) =============
  void showInterestCalculator(BuildContext context, DepositProduct product) {
    final amountController = TextEditingController(text: "1,000,000");
    final FocusNode amountFocus = FocusNode();

    int months = product.period > 0 ? product.period : 1;
    final double rate = product.maxRate;
    int interestResult = 0;

    String formatCurrency(int v) => NumberFormat("#,###").format(v);

    void calculate(StateSetter s) {
      final amount =
          int.tryParse(amountController.text.replaceAll(",", "")) ?? 0;
      final interest = (amount * (rate / 100) * (months / 12)).round();
      s(() => interestResult = interest);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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

            // 섹션 공통 데코
            BoxDecoration sectionBox({Color? fill}) => BoxDecoration(
                  color: fill ?? Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade400, width: 1.2),
                );

            Widget sectionTitle(String t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                );

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismissKeyboard,
                child: FractionallySizedBox(
                  heightFactor: 0.88, // 처음 열었을 때 '닫기' 버튼 노출 확보
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FB),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 30,
                          spreadRadius: 6,
                          offset: const Offset(0, -5),
                        ),
                      ],
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300, width: 1),
                        bottom:
                            BorderSide(color: Colors.grey.shade300, width: 0.6),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      bottom: true,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              "${product.name} 이자 계산기",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 섹션 1: 상품 요약
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: sectionBox(fill: Colors.white),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  sectionTitle("상품 요약"),
                                  _infoLine(
                                    "최대 금리",
                                    "${rate.toStringAsFixed(2)}%",
                                    highlight: true,
                                  ),
                                  const SizedBox(height: 6),
                                  _infoLine("기본 가입기간", "${product.period}개월"),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // 섹션 2: 예치금 (단일 입력 박스)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: TextField(
                                controller: amountController,
                                focusNode: amountFocus,
                                enableSuggestions: false,
                                autocorrect: false,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                decoration: InputDecoration(
                                  labelText: "예치금",
                                  prefixText: "₩ ",
                                  prefixStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade400,
                                        width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF304FFE), width: 2),
                                  ),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: '지우기',
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                              minWidth: 36, minHeight: 36),
                                          onPressed: () {
                                            amountController.clear();
                                            s(() {});
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
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) {
                                  dismissKeyboard();
                                  calculate(s);
                                },
                                onChanged: (v) {
                                  final numeric =
                                      v.replaceAll(RegExp(r'[^0-9]'), '');
                                  final formatted = NumberFormat("#,###")
                                      .format(int.parse(
                                          numeric.isEmpty ? "0" : numeric));
                                  amountController.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(
                                        offset: formatted.length),
                                  );
                                  calculate(s);
                                },
                              ),
                            ),

                            const SizedBox(height: 10),

                            // 섹션 3: 가입기간 (한 줄 + 슬라이더)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: sectionBox(fill: Colors.white),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // "가입기간" | "6개월"
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "가입기간",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      Text(
                                        "$months 개월",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2.5,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 10),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                              overlayRadius: 18),
                                      activeTickMarkColor:
                                          const Color(0xFF304FFE)
                                              .withOpacity(.4),
                                      inactiveTickMarkColor:
                                          Colors.grey.shade300,
                                    ),
                                    child: Slider(
                                      value: months.toDouble(),
                                      min: 1,
                                      max: 36,
                                      divisions: 35,
                                      label: "$months 개월",
                                      activeColor: const Color(0xFF304FFE),
                                      onChanged: (v) {
                                        months = v.toInt();
                                        s(() {});
                                        calculate(s);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // 섹션 4: 결과
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: sectionBox(fill: Colors.grey.shade50),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  sectionTitle("예상 결과"),
                                  const SizedBox(height: 2),
                                  Center(
                                    child: Column(
                                      children: [
                                        const Text(
                                          "예상 이자수익",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        TweenAnimationBuilder<int>(
                                          tween: IntTween(
                                              begin: 0, end: interestResult),
                                          duration:
                                              const Duration(milliseconds: 680),
                                          curve: Curves.easeOutCubic,
                                          builder: (_, value, __) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            child: Text(
                                              "${formatCurrency(value)} 원",
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF304FFE),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 16),
                                  resultRow(
                                      "예치금", "${formatCurrency(amount)} 원"),
                                  resultRow("이자수익",
                                      "${formatCurrency(interestResult)} 원"),
                                  resultRow(
                                    "총 수령액",
                                    "${formatCurrency(total)} 원",
                                    highlight: true,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // 닫기
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Color(0xFF304FFE), width: 2),
                                  foregroundColor: const Color(0xFF304FFE),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text("닫기"),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
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
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom),
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
                          color:
                              active ? _accent : Colors.black.withOpacity(0.2),
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

      // ✅ 추천 & 근처 지점 (공통 위젯) — 추천은 /savings/start로 이동
      shortcutRow(context),
      const SizedBox(height: 18),

      // ⭐ 금리 높은 추천 — 아이콘 제거 + 폰트 확대
      sectionTitle("⭐ 금리 높은 추천"),
      productSlider(recommended.take(5).toList()),
      const SizedBox(height: 12),

      // 🔥 인기 TOP 5
      sectionTitle("🔥 인기 상품 TOP 5"),
      productList(topViewed.take(5).toList()),
    ];
  }

  // === 심플 모드 === (예전 심플 UI로 복원 + 라우팅 유지)
  List<Widget> _buildSimpleModeSection() {
    return [
      const SizedBox(height: 12),

      // 카테고리 바로가기 — 예전처럼 BigPrimaryButton(테두리) 3개
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: neoDecoration(),
                child: _BigPrimaryButton(
                  label: "예금",
                  icon: Icons.savings,
                  accent: _accent,
                  showIcon: false,
                  filled: false, // 테두리 버튼
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: neoDecoration(),
                child: _BigPrimaryButton(
                  label: "적금",
                  icon: Icons.account_balance_wallet,
                  accent: _accent,
                  showIcon: false,
                  filled: false,
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: neoDecoration(),
                child: _BigPrimaryButton(
                  label: "입출금",
                  icon: Icons.money,
                  accent: _accent,
                  showIcon: false,
                  filled: false,
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
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // 🔙 예전 심플 UI의 "빠른 기능" 영역 (두 개의 큰 버튼)
      // ✅ 라우팅 유지: 내 추천 → /savings/start, 근처 지점 → /map
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _BigPrimaryButton(
                label: "맞춤 상품 추천",
                icon: Icons.recommend,
                accent: _accent,
                filled: false, // 꽉 찬 버튼(예전 스타일)
                onTap: () => pushNamedRoot(context, '/savings/start'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigPrimaryButton(
                label: "근처 지점 위치",
                icon: Icons.location_on,
                accent: Colors.green,
                filled: false, // 테두리 버튼
                onTap: () => pushNamedRoot(context, '/map'),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 20),

      // 추천 리스트 (예전 심플 카드)
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

      ...topViewed.take(4).map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _SimpleProductCard(
                p: p,
                accent: _accent,
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

  // === 가로형 추천 카드 (아이콘 제거 + 폰트 확대) ===
  Widget productSlider(List<DepositProduct> products) {
    final pastelSets = [
      [const Color(0xFFEAF4FF), const Color(0xFFD7ECFF)],
      [const Color(0xFFE8FFF6), const Color(0xFFD4F7EA)],
      [const Color(0xFFFFF2E5), const Color(0xFFFFE7CC)],
      [const Color(0xFFF3EEFF), const Color(0xFFE8E1FF)],
    ];

    return SizedBox(
      height: 196,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (_, i) {
          final p = products[i];
          final colors = pastelSets[i % pastelSets.length];
          final bigIcon = _serviceIconFor(p); // 내부 미사용이지만 인터페이스 유지
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
                subtitle: "${p.period}개월",
                bg1: colors[0],
                bg2: colors[1],
                bigIcon: bigIcon,
                hashtag: hashtag,
                rateText: "최고 ${p.maxRate.toStringAsFixed(2)}%",
                cornerIcon: bigIcon,
                // ▼ 추가 파라미터: 아이콘 숨기기 / 폰트 확대
                showCornerIcon: false,
                titleFontSize: 18.0,
                hashtagFontSize: 14.0,
                bottomLeftFontSize: 15.0,
                bottomRightFontSize: 18.0,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

// ▼ 파라미터 추가: showCornerIcon, 폰트 크기 조절
class _PastelServiceCard extends StatelessWidget {
  final String title;
  final String subtitle; // ex) "12개월"
  final Color bg1;
  final Color bg2;
  final IconData bigIcon; // (호환용) — 숨길 수 있음
  final String hashtag; // 제목 아래
  final String rateText; // ex) "최고 7.00%"
  final IconData cornerIcon; // (호환용, 미사용)
  final bool showCornerIcon; // ← 신규: 우상단 큰 아이콘 표시 여부
  final double titleFontSize;
  final double hashtagFontSize;
  final double bottomLeftFontSize; // "개월"
  final double bottomRightFontSize; // "최고 7.00%"

  const _PastelServiceCard({
    required this.title,
    required this.subtitle,
    required this.bg1,
    required this.bg2,
    required this.bigIcon,
    required this.hashtag,
    required this.rateText,
    required this.cornerIcon,
    this.showCornerIcon = true,
    this.titleFontSize = 18.0,
    this.hashtagFontSize = 13.0,
    this.bottomLeftFontSize = 14.5,
    this.bottomRightFontSize = 16.5,
  });

  @override
  Widget build(BuildContext context) {
    const double w = 250;
    const double h = 150;
    const accent = Color(0xFF304FFE);

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
            if (showCornerIcon)
              Positioned(
                right: 14,
                top: 10,
                child: Icon(
                  bigIcon,
                  size: 86,
                  color: Colors.black.withOpacity(0.12),
                ),
              ),

            // 본문
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목 (폰트 확대)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 해시태그 (폰트 확대)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          hashtag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: hashtagFontSize,
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
                      ),
                      const SizedBox(width: 8),
                      _coin(),
                      const SizedBox(width: 4),
                      _coin(small: true),
                    ],
                  ),

                  const Spacer(),

                  // 하단: 좌(개월) / 우(최고금리) — 폰트 확대
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: bottomLeftFontSize,
                          fontWeight: FontWeight.w800,
                          color: Colors.black.withOpacity(0.60),
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        rateText,
                        style: TextStyle(
                          fontSize: bottomRightFontSize,
                          fontWeight: FontWeight.w900,
                          color: accent,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: accent.withOpacity(0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 기존 동전 그대로 재사용
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

// ===== 금리 배지 (우하단 강조) =====
class _RateBadge extends StatelessWidget {
  final String text;
  const _RateBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Color(0xFF304FFE),
        ),
      ),
    );
  }
}

// ▼ filled 옵션 추가: false면 화이트 카드 + 테두리(기본보기 톤과 유사)
class _BigPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color accent;
  final double horizontalPadding;
  final double verticalPadding;
  final bool showIcon;
  final bool filled;

  const _BigPrimaryButton({
    required this.label,
    this.icon,
    required this.onTap,
    required this.accent,
    this.horizontalPadding = 16,
    this.verticalPadding = 16,
    this.showIcon = true,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
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
    } else {
      // 화이트 카드 + 테두리
      final style = OutlinedButton.styleFrom(
        side: BorderSide(color: accent.withOpacity(0.6), width: 1.6),
        foregroundColor: accent,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
      );
      if (showIcon && icon != null) {
        return SizedBox(
          height: 64,
          child: OutlinedButton.icon(
            icon: Icon(icon, size: 22),
            label: Text(label),
            onPressed: onTap,
            style: style,
          ),
        );
      } else {
        return SizedBox(
          height: 64,
          child: OutlinedButton(
            onPressed: onTap,
            style: style,
            child: Text(label),
          ),
        );
      }
    }
  }
}

/// ✅ 공통 쇼트컷 카드: 추천 상품(/savings/start), 영업점/ATM(/map)
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
            // 🔁 변경: 스낵바 → /savings/start 라우팅
            onTap: () => pushNamedRoot(context, '/savings/start'),
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(right: 8),
              decoration: neoBox(),
              child: const Column(
                children: [
                  Icon(Icons.recommend, size: 36, color: Colors.indigo),
                  SizedBox(height: 10),
                  Text(
                    "저축 성향 테스트",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.indigo,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "맞춤 상품 추천",
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
            onTap: () => pushNamedRoot(context, '/map'),
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(left: 8),
              decoration: neoBox().copyWith(color: Colors.green.shade50),
              child: const Column(
                children: [
                  Icon(Icons.location_on, size: 36, color: Colors.green),
                  SizedBox(height: 10),
                  Text(
                    "영업점, ATM",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "위치확인",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green),
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
