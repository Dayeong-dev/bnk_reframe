import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/service/deposit_service.dart';
import 'deposit_detail_page.dart';

/// 통화 포맷터
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

/// ===== 테마 토큰 =====
class AppTokens {
  static const Color ink = Color(0xFF111827);
  static const Color accent = Color(0xFF2962FF);
  static const Color bg = Colors.white;
  static const Color card = Colors.white;
  static const Color weak = Color(0xFF6B7280);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 14,
      spreadRadius: 0,
      offset: Offset(0, 6),
    ),
  ];
}

class _DepositMainPageState extends State<DepositMainPage> {
  late final PageController _bannerController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _bannerTimer;

  int _currentDot = 0;
  int _currentAbsPage = 0;
  final int _pageCount = 4;
  final int _loopSeed = 1000;
  bool _isAutoSlide = true;

  List<DepositProduct> allProducts = [];
  List<DepositProduct> topViewed = [];
  List<DepositProduct> recommended = [];
  bool _isLoading = true;

  bool _simpleMode = false; // 크게보기
  double get _scale => _simpleMode ? 1.28 : 1.0;

  static const double _vGap = 12.0;
  static const double _recoCardH = 130.0;
  static const double _recoCardW = 230.0;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController(
      viewportFraction: 0.92,
      initialPage: _loopSeed * _pageCount,
    );
    _currentAbsPage = _bannerController.initialPage;
    _restoreSimpleMode();
    fetchData();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _restoreSimpleMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() => _simpleMode = prefs.getBool('simpleMode') ?? false);
    } catch (_) {}
  }

  Future<void> _saveSimpleMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('simpleMode', _simpleMode);
    } catch (_) {}
  }

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('상품 불러오기 실패: $e')));
    }
  }

  void _startAutoSlide() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isAutoSlide || !_bannerController.hasClients || _simpleMode) return;
      final curr = _bannerController.page?.round() ?? _currentAbsPage;
      _bannerController.animateToPage(
        curr + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  // ▶ 쇼트컷
  Widget shortcutRow(BuildContext context, {required Color accent}) {
    BoxDecoration deco() => BoxDecoration(
          color: AppTokens.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTokens.cardShadow,
        );

    Widget btn({
      required String label,
      required IconData icon,
      required Color g1,
      required Color g2,
      required VoidCallback onTap,
    }) {
      final double labelSize = (14 * _scale);
      return _TapScale(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 88 * _scale),
          padding: EdgeInsets.symmetric(vertical: 14 * _scale),
          decoration: deco(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44 * _scale,
                height: 44 * _scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [g1, g2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 24 * _scale),
              ),
              SizedBox(height: 6 * _scale),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: labelSize, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: btn(
              label: '맞춤 상품 추천',
              icon: Icons.recommend,
              g1: const Color(0xFF7C4DFF),
              g2: const Color(0xFFB388FF),
              onTap: () => pushNamedRoot(context, '/savings/start'),
            ),
          ),
          SizedBox(width: 12 * _scale),
          Expanded(
            child: btn(
              label: '영업점 위치확인',
              icon: Icons.location_on,
              g1: const Color(0xFF009688),
              g2: const Color(0xFF4DB6AC),
              onTap: () => pushNamedRoot(context, '/map'),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 상세 이동 =====
  void goToDetail(DepositProduct product) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => DepositDetailPage(productId: product.productId),
        settings: const RouteSettings(name: '/deposit/detail'),
      ),
    );
  }

  void goToDetailById(int productId) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => DepositDetailPage(productId: productId),
        settings: const RouteSettings(name: '/deposit/detail'),
      ),
    );
  }

  // ===== 이자 계산기 =====
  void showInterestCalculator(BuildContext context, DepositProduct product) {
    const double modalScale = 1.0;

    final amountController = TextEditingController(text: "1,000,000");
    final FocusNode amountFocus = FocusNode();

    int months = product.period > 0 ? product.period : 1;
    final double rate = product.maxRate;
    int interestResult = 0;

    String fmt(int v) => NumberFormat("#,###").format(v);

    BoxDecoration sectionBox() => BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTokens.cardShadow,
        );

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
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(builder: (context, s) {
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
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismissKeyboard,
              child: FractionallySizedBox(
                heightFactor: 0.90,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: AppTokens.cardShadow,
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            product.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18 * modalScale,
                                fontWeight: FontWeight.w800,
                                color: AppTokens.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "이자 계산기",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16 * modalScale,
                                fontWeight: FontWeight.w900,
                                color: AppTokens.accent),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "예치금/가입기간을 입력해 예상 이자를 확인하세요.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppTokens.weak,
                                fontSize: 12 * modalScale),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: sectionBox(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("상품 요약",
                                    style: TextStyle(
                                        fontSize: 14 * modalScale,
                                        fontWeight: FontWeight.w800,
                                        color: AppTokens.ink)),
                                const SizedBox(height: 8),
                                DotKVRow(
                                    label: "최대 금리",
                                    value: "${rate.toStringAsFixed(2)}%",
                                    highlightValue: true,
                                    scale: modalScale),
                                const SizedBox(height: 6),
                                DotKVRow(
                                    label: "기본 가입기간",
                                    value: "${product.period}개월",
                                    scale: modalScale),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: sectionBox(),
                            child: Row(
                              children: [
                                Text("예치금",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14 * modalScale,
                                        color: AppTokens.ink)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
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
                                      style: const TextStyle(
                                          color: AppTokens.ink, fontSize: 16),
                                      decoration: InputDecoration(
                                        prefixText: '₩ ',
                                        prefixStyle: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            color: AppTokens.ink),
                                        hintText: "1,000,000",
                                        hintStyle: const TextStyle(
                                            color: Color(0xFF9AA4B2)),
                                        isDense: true,
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppTokens.accent,
                                              width: 2),
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
                                            .format(int.parse(numeric.isEmpty
                                                ? "0"
                                                : numeric));
                                        amountController.value =
                                            TextEditingValue(
                                          text: formatted,
                                          selection: TextSelection.collapsed(
                                              offset: formatted.length),
                                        );
                                        calculate(s);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTokens.accent,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {
                                      dismissKeyboard();
                                      calculate(s);
                                    },
                                    child: const Text('완료',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: sectionBox(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("가입기간",
                                        style: TextStyle(
                                            fontSize: 14 * modalScale,
                                            fontWeight: FontWeight.w800,
                                            color: AppTokens.ink)),
                                    Text("$months 개월",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14 * modalScale)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const SizedBox(height: 2),
                                _SliderWithLine(
                                  value: months.toDouble(),
                                  min: 1,
                                  max: 36,
                                  divisions: 35,
                                  onChanged: (v) {
                                    months = v.toInt();
                                    s(() {});
                                    calculate(s);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: sectionBox(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("예상 결과",
                                    style: TextStyle(
                                        fontSize: 14 * modalScale,
                                        fontWeight: FontWeight.w800,
                                        color: AppTokens.ink)),
                                const SizedBox(height: 8),
                                Center(
                                  child: Column(
                                    children: [
                                      Text("예상 이자수익",
                                          style: TextStyle(
                                              fontSize: 14 * modalScale,
                                              fontWeight: FontWeight.w700,
                                              color: AppTokens.ink)),
                                      TweenAnimationBuilder<int>(
                                        tween: IntTween(
                                            begin: 0, end: interestResult),
                                        duration:
                                            const Duration(milliseconds: 650),
                                        curve: Curves.easeOutCubic,
                                        builder: (_, value, __) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          child: Text(
                                            "${fmt(value)} 원",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 26 * modalScale,
                                              fontWeight: FontWeight.w900,
                                              color: AppTokens.accent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DotKVRow(
                                    label: "예치금",
                                    value: "${fmt(amount)} 원",
                                    scale: modalScale),
                                const SizedBox(height: 6),
                                DotKVRow(
                                    label: "이자수익",
                                    value: "${fmt(interestResult)} 원",
                                    scale: modalScale),
                                const SizedBox(height: 6),
                                DotKVRow(
                                    label: "총 수령액",
                                    value: "${fmt(total)} 원",
                                    highlightValue: true,
                                    scale: modalScale),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48 * modalScale,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTokens.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                textStyle: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15 * modalScale),
                              ),
                              child: const Text("닫기"),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Text _sectionTitle(String t) => Text(t,
      style: TextStyle(
          fontSize: 14 * _scale,
          fontWeight: FontWeight.w800,
          color: AppTokens.ink));

  @override
  Widget build(BuildContext context) {
    const ink = AppTokens.ink;
    const accent = AppTokens.accent;

    return Scaffold(
      backgroundColor: AppTokens.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('BNK 예적금',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18 * _scale,
                color: ink)),
        actions: [
          // 아이콘 살짝 아래로
          IconButton(
            tooltip: '검색',
            padding: const EdgeInsets.symmetric(horizontal: 8),
            icon: Transform.translate(
              offset: const Offset(0, 1.5),
              child: Icon(Icons.search, size: 22 * _scale),
            ),
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
                padding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6 * _scale),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                setState(() => _simpleMode = !_simpleMode);
                await _saveSimpleMode();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(_simpleMode ? '크게보기 모드 켜짐' : '기본보기 모드 켜짐'),
                    duration: const Duration(seconds: 1)));
              },
              child: Text(_simpleMode ? '기본보기' : '크게보기',
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: _simpleMode ? 16.0 : 16 * _scale,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text("상품 정보를 불러오는 중입니다...",
                      style: TextStyle(fontSize: 15 * _scale, color: ink)),
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
                        ? _buildSimpleModeSection(accent, ink)
                        : _buildNormalModeSection(accent, ink),
                  ),
                ),
              ),
            ),
    );
  }

  // === 기본 섹션 ===
  List<Widget> _buildNormalModeSection(Color accent, Color ink) {
    return [
      SizedBox(
        height: 164 * _scale,
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
                switch (i) {
                  case 0:
                    return bannerImageItem(
                        asset: 'assets/images/074.png',
                        onTap: () => goToDetailById(74));
                  case 1:
                    return bannerImageItem(
                        asset: 'assets/images/069.png',
                        onTap: () => goToDetailById(69));
                  case 2:
                    return bannerImageItem(
                        asset: 'assets/images/070.png',
                        onTap: () => goToDetailById(70));
                  default:
                    return bannerImageItem(
                        asset: 'assets/images/073.png',
                        onTap: () => goToDetailById(73));
                }
              },
            ),
            // ▼ 인디케이터 + (더 작은) 일시정지 버튼
            Positioned(
              bottom: 17,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ─── 인디케이터(dot)는 기존대로 _scale 따라감 ───
                  Row(
                    children: List.generate(_pageCount, (i) {
                      final active = _currentDot == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: (active ? 18 : 8) * _scale,
                        height: 8 * _scale,
                        margin: EdgeInsets.symmetric(horizontal: 4 * _scale),
                        decoration: BoxDecoration(
                          color:
                              active ? accent : Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                      color: accent.withOpacity(0.28),
                                      blurRadius: 8)
                                ]
                              : [],
                        ),
                      );
                    }),
                  ),

                  const SizedBox(width: 4), // 인디케이터와 버튼 간격

                  // ─── 일시정지 버튼은 고정 크기 ───
                  GestureDetector(
                    onTap: () => setState(() => _isAutoSlide = !_isAutoSlide),
                    child: Container(
                      padding: const EdgeInsets.all(2), // 내부 여백 (원 크기)
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isAutoSlide ? Icons.pause : Icons.play_arrow,
                        size: 14, // 아이콘 고정 크기
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
      SizedBox(height: _vGap * _scale),
      categorySection(context, accent: accent),
      SizedBox(height: _vGap * _scale),
      shortcutRow(context, accent: accent),
      SizedBox(height: _vGap * _scale),
      sectionTitle("⭐ 금리 높은 추천", ink),
      productSlider(recommended.take(5).toList(), accent),
      SizedBox(height: _vGap * _scale),
      sectionTitle("🔥 인기 상품 TOP 5", ink),
      productList(topViewed.take(5).toList(), accent),
    ];
  }

  // === 크게보기(시니어) 섹션 ===
  List<Widget> _buildSimpleModeSection(Color accent, Color ink) {
    return [
      SizedBox(height: 8 * _scale),
      categorySection(context, accent: accent),
      SizedBox(height: 12 * _scale),
      shortcutRow(context, accent: accent),
      SizedBox(height: 12 * _scale),
      sectionTitle("인기 상품", ink),
      _simpleBigList(topViewed.take(6).toList(), accent),
      SizedBox(height: 12 * _scale),
    ];
  }

  // ===== 위젯 모듈 =====
  Widget bannerImageItem({required String asset, required VoidCallback onTap}) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: 8 * _scale, vertical: 10 * _scale),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppTokens.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTokens.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(asset, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String title, Color ink) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Text(title,
          style: TextStyle(
              fontSize: 18 * _scale, fontWeight: FontWeight.w800, color: ink)),
    );
  }

  Widget productSlider(List<DepositProduct> products, Color accent) {
    final pastelSets = [
      [const Color(0xFFEAF4FF), const Color(0xFFD7ECFF)],
      [const Color(0xFFE8FFF6), const Color(0xFFD4F7EA)],
      [const Color(0xFFFFF2E5), const Color(0xFFFFE7CC)],
      [const Color(0xFFF3EEFF), const Color(0xFFE8E1FF)],
    ];
    return SizedBox(
      height: (_recoCardH + 26) * _scale,
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
                subtitle: "${p.period}개월",
                bg1: colors[0],
                bg2: colors[1],
                bigIcon: bigIcon,
                hashtag: hashtag,
                rateText: "최고 ${p.maxRate.toStringAsFixed(2)}%",
                cornerIcon: bigIcon,
                showCornerIcon: false,
                titleFontSize: 16.5 * _scale,
                hashtagFontSize: 12.5 * _scale,
                bottomLeftFontSize: 13.5 * _scale,
                bottomRightFontSize: 16.5 * _scale,
                width: _recoCardW * _scale,
                height: _recoCardH * _scale,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget productList(List<DepositProduct> products, Color accent) {
    return Column(
      children: products.map((p) {
        return GestureDetector(
          onTap: () => goToDetail(p),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(18 * _scale),
            decoration: BoxDecoration(
              color: AppTokens.card,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTokens.cardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(p.name,
                          style: TextStyle(
                              fontSize: 16 * _scale,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text("가입기간: ${p.period}개월",
                          style: TextStyle(
                              fontSize: 13 * _scale, color: AppTokens.weak)),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8 * _scale),
                  child: Text("최고 ${p.maxRate.toStringAsFixed(2)}%",
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: accent,
                          fontSize: 14.5 * _scale)),
                ),
                SizedBox(width: 12 * _scale),
                ElevatedButton.icon(
                  onPressed: () => showInterestCalculator(context, p),
                  icon: Icon(Icons.calculate, size: 18 * _scale),
                  label: Text("이자 계산",
                      style: TextStyle(
                          fontSize: 13 * _scale, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    minimumSize: Size(90 * _scale, 36 * _scale),
                    padding: EdgeInsets.symmetric(horizontal: 10 * _scale),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 카테고리
  Widget categorySection(BuildContext context, {required Color accent}) {
    final deco = BoxDecoration(
      color: AppTokens.card,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppTokens.cardShadow,
    );

    Widget btn(String label, IconData icon, Color a, Color b,
            VoidCallback onTap) =>
        _TapScale(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: 88 * _scale),
            padding: EdgeInsets.symmetric(vertical: 14 * _scale),
            decoration: deco,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44 * _scale,
                  height: 44 * _scale,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [a, b],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)),
                  child: Icon(icon, color: Colors.white, size: 24 * _scale),
                ),
                SizedBox(height: 6 * _scale),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14 * _scale)),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child:
                btn('목돈굴리기', Icons.savings, accent, accent.withOpacity(.6), () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DepositListPage(initialCategory: '예금'),
                  settings: const RouteSettings(name: '/depositList'),
                ),
              );
            }),
          ),
          SizedBox(width: 12 * _scale),
          Expanded(
            child: btn('목돈만들기', Icons.account_balance_wallet,
                const Color(0xFF00C6AE), const Color(0xFF4ADEDE), () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DepositListPage(initialCategory: '적금'),
                  settings: const RouteSettings(name: '/depositList'),
                ),
              );
            }),
          ),
          SizedBox(width: 12 * _scale),
          Expanded(
            child: btn('입출금', Icons.money, const Color(0xFFFF6F61),
                const Color(0xFFFFA177), () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DepositListPage(initialCategory: '입출금'),
                  settings: const RouteSettings(name: '/depositList'),
                ),
              );
            }),
          ),
        ],
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
    if (name.contains('아기') || name.contains('유아')) return Icons.child_care;
    if (name.contains('실버') || name.contains('시니어')) return Icons.elderly;
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

  /// ===== 크게보기 전용: 큰 리스트 =====
  Widget _simpleBigList(List<DepositProduct> products, Color accent) {
    return Column(
      children: products.map((p) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(18 * _scale),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTokens.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name,
                  maxLines: 2,
                  style: TextStyle(
                      fontSize: 19 * _scale,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                      color: AppTokens.ink)),
              const SizedBox(height: 8),
              Text(
                  "가입기간: ${p.period}개월   ·   최고 ${p.maxRate.toStringAsFixed(2)}%",
                  style: TextStyle(
                      fontSize: 15 * _scale,
                      color: AppTokens.weak,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => goToDetail(p),
                      icon: Icon(Icons.open_in_new, size: 18 * _scale),
                      label: Text("상세보기",
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15 * _scale)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12 * _scale),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  SizedBox(width: 10 * _scale),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => showInterestCalculator(context, p),
                      icon: Icon(Icons.calculate, size: 18 * _scale),
                      label: Text("이자 계산",
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15 * _scale)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12 * _scale),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// ===== 세퍼레이터 라인 스타일의 KV Row =====
class DotKVRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlightValue;
  final double scale;
  const DotKVRow({
    super.key,
    required this.label,
    required this.value,
    this.highlightValue = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w600,
                color: AppTokens.ink)),
        const SizedBox(width: 8),
        const Expanded(child: _DottedDivider()),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 15 * scale,
            fontWeight: highlightValue ? FontWeight.w900 : FontWeight.w700,
            color: highlightValue ? AppTokens.accent : AppTokens.ink,
          ),
        ),
      ],
    );
  }
}

class _DottedDivider extends StatelessWidget {
  const _DottedDivider();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: _DotsPainter(thick: 1.2, color: const Color(0xFFCAD3DF)),
        size: const Size(double.infinity, 1));
  }
}

class _DottedTrack extends StatelessWidget {
  final double horizontalInset;
  const _DottedTrack({required this.horizontalInset});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: CustomPaint(
        painter: _DotsPainter(thick: 1.2, color: const Color(0xFFCAD3DF)),
        child: const SizedBox(height: 2),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final double thick;
  final Color color;
  const _DotsPainter({this.thick = 1, this.color = const Color(0xFFE5E8EB)});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick;
    const dot = 3.0;
    const space = 4.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dot, y), paint);
      x += dot + space;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SliderWithLine extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderWithLine({
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  static const double _thumbRadius = 10.0;
  static const double _stroke = 3.0;
  static const double kTrackInset = _thumbRadius + (_stroke / 2);

  @override
  Widget build(BuildContext context) {
    final factor = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          const Positioned.fill(
              child: _DottedTrack(horizontalInset: kTrackInset)),
          Positioned.fill(
            child: CustomPaint(
              painter: _ActiveLinePainter(
                factor: factor,
                horizontalInset: kTrackInset,
                color: AppTokens.accent,
                strokeWidth: _stroke,
              ),
            ),
          ),
          Positioned.fill(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: _thumbRadius),
                thumbColor: AppTokens.accent,
                overlayColor: AppTokens.accent.withOpacity(.12),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                label: "${value.toInt()} 개월",
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveLinePainter extends CustomPainter {
  final double factor;
  final double horizontalInset;
  final Color color;
  final double strokeWidth;

  const _ActiveLinePainter({
    required this.factor,
    required this.horizontalInset,
    required this.color,
    this.strokeWidth = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = horizontalInset;
    final right = size.width - horizontalInset;
    final usable = (right - left).clamp(0.0, size.width);
    final thumbCenterX = (left + usable * factor).clamp(left, right);
    final y = size.height / 2;

    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final startX = left;
    final endX = (thumbCenterX - strokeWidth / 2).clamp(left, right);

    if (endX > startX) {
      canvas.drawLine(Offset(startX, y), Offset(endX, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ActiveLinePainter old) =>
      old.factor != factor ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.horizontalInset != horizontalInset;
}

/// 탭 애니메이션
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
            borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

/// ===== Won 코인 위젯(₩) — 큰/작게 두 개 사용
class _WonCoin extends StatelessWidget {
  final double size; // 지름(px)
  const _WonCoin({required this.size});

  @override
  Widget build(BuildContext context) {
    // 금색 그라디언트 + 테두리 + 약한 그림자
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE082), // 밝은 골드
            Color(0xFFFFC107), // 기본 골드
            Color(0xFFFFB300), // 진한 골드
          ],
        ),
        border: Border.all(color: const Color(0xFFFFD54F), width: size * 0.06),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '₩',
        style: TextStyle(
          fontSize: size * 0.52,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF5D4037), // 브론즈 브라운
          height: 1.0,
        ),
      ),
    );
  }
}

// 축소 가로 카드
class _PastelServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color bg1;
  final Color bg2;
  final IconData bigIcon;
  final String hashtag;
  final String rateText;
  final IconData cornerIcon;
  final bool showCornerIcon;
  final double titleFontSize;
  final double hashtagFontSize;
  final double bottomLeftFontSize;
  final double bottomRightFontSize;
  final double width;
  final double height;

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
    this.width = 250,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    const accent = AppTokens.accent;
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
              colors: [bg1, bg2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: AppTokens.cardShadow,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (showCornerIcon)
              Positioned(
                right: 14,
                top: 10,
                child: Icon(bigIcon,
                    size: 86, color: Colors.black.withOpacity(0.10)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2937))),
                  const SizedBox(height: 6),
                  // ★ 해시태그 + 동전 2개(큰/작은)
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 큰 코인
                      _WonCoin(size: hashtagFontSize + 8),
                      const SizedBox(width: 3),
                      // 작은 코인
                      _WonCoin(size: hashtagFontSize + 3),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: bottomLeftFontSize,
                              fontWeight: FontWeight.w800,
                              color: Colors.black.withOpacity(0.60))),
                      Text("최고 ${rateText.split(' ').last}",
                          style: TextStyle(
                              fontSize: bottomRightFontSize,
                              fontWeight: FontWeight.w900,
                              color: accent)),
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
}
