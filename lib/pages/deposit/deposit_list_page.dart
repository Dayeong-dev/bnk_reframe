import 'package:flutter/material.dart';
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/pages/deposit/deposit_detail_page.dart';
import 'package:reframe/service/deposit_service.dart' as DepositService;
import 'package:firebase_analytics/firebase_analytics.dart';

/// 예적금 목록 (아이콘 자동 추천 버전)
class DepositListPage extends StatefulWidget {
  final String initialCategory;
  const DepositListPage({super.key, this.initialCategory = '전체'});

  @override
  State<DepositListPage> createState() => _DepositListPageState();
}

class _DepositListPageState extends State<DepositListPage>
    with TickerProviderStateMixin {
  final List<String> categories = ['전체', '예금', '적금', '입출금'];
  int selectedIndex = 0;
  String sortOption = '인기순';

  List<DepositProduct> allProducts = [];
  List<DepositProduct> filteredProducts = [];

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  int itemsToShow = 12;
  bool _loading = true;
  bool _gridMode = false;

  static const _brand = Color(0xFF304FFE);
  static const _bg = Color(0xFFF5F7FA);

  late final PageController _pageController;

  // ① Analytics 인스턴스
final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

// ② 리스트 노출(임프레션) 중복 방지용 SIG
String? _lastImpressionSig;

// ③ 상품 타입(카테고리 보정) 유틸
String _productTypeOf(DepositProduct e) {
  final c = (e.category ?? '').trim();
  return c == '입출금자유' ? '입출금' : (c.isEmpty ? '기타' : c);
}

// ④ 로깅 함수들
Future<void> _logCategoryView(int index) async {
  final cat = categories[index];
  await _analytics.logEvent(name: 'category_view', parameters: {
    'category': cat,                         // 전체/예금/적금/입출금
    'view_mode': _gridMode ? 'grid' : 'list' // 현재 보기 방식
  });
}

Future<void> _logSearch(String query) async {
  if (query.trim().isEmpty) return;
  await _analytics.logEvent(name: 'search', parameters: {
    'q': query.trim(),
    'category': categories[selectedIndex],
  });
}

Future<void> _logProductClick(DepositProduct item, int index, {required String source}) async {
  // 목록에서 상세로 들어가기 직전 클릭 이벤트
  await _analytics.logEvent(name: 'product_list_click', parameters: {
    'product_id': '${item.productId}',
    'product_type': _productTypeOf(item),
    'category': item.category ?? '',
    'pos': index + 1,                        // 현재 화면 내 노출 순번(1-base)
    'source': source,                        // grid | list
  });
}

void _scheduleImpressionLog(List<DepositProduct> visible, int pageIndex) {
  // 현재 화면에 보이는 상품 묶음 임프레션(중복 방지)
  final ids = visible.map((e) => e.productId).map((v) => '$v').join(',');
  final sig = '$pageIndex|${_gridMode ? 'grid' : 'list'}|$ids';
  if (_lastImpressionSig == sig) return; // 같은 화면 구성이라면 재전송 X
  _lastImpressionSig = sig;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // 최대 20개까지만 CSV로 전송(길이 방어)
    final shortCsv = visible.take(20).map((e) => '${e.productId}').join(',');
    await _analytics.logEvent(name: 'product_list_impression', parameters: {
      'category': categories[pageIndex],
      'variant': _gridMode ? 'grid' : 'list',
      'count': visible.length,
      'items': shortCsv, // "123,456,789,..."
    });
  });
}


  @override
  void initState() {
    super.initState();
    selectedIndex = categories.indexOf(widget.initialCategory);
    if (selectedIndex < 0) selectedIndex = 0;
    _pageController = PageController(initialPage: selectedIndex);
    _loadProducts();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final list = await DepositService.fetchAllProducts();
      setState(() {
        allProducts = list;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('목록을 불러오지 못했어요: $e')));
    }
  }

  // ---------- 필터/정렬 ----------
  List<DepositProduct> _computeFiltered(int catIndex) {
    List<DepositProduct> result = [...allProducts];

    final cat = categories[catIndex];
    if (cat != '전체') {
      if (cat == '입출금') {
        result = result.where((e) => (e.category ?? '') == '입출금자유').toList();
      } else {
        result = result.where((e) => (e.category ?? '') == cat).toList();
      }
    }

    final q = searchQuery.toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((e) {
        final n = (e.name ?? '').replaceAll('<br>', '\n').toLowerCase();
        final s = (e.summary ?? '').replaceAll('<br>', '\n').toLowerCase();
        return n.contains(q) || s.contains(q);
      }).toList();
    }

    if (sortOption == '인기순') {
      result.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    } else {
      result.sort((a, b) => b.maxRate.compareTo(a.maxRate));
    }
    return result;
  }

  void _applyFilter() {
    final result = _computeFiltered(selectedIndex);
    setState(() {
      filteredProducts = result;
      itemsToShow = _gridMode ? 8 : 6;
    });
  }

  // ---------- 검색바 ----------
  PreferredSizeWidget _searchBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(Icons.search, color: _brand, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) {
                      searchQuery = v.trim();
                      _applyFilter();
                      _logSearch(searchQuery); // ← 추가
                    },
                    onSubmitted: (v) {
                      searchQuery = v.trim();
                      _applyFilter();
                    },
                    decoration: const InputDecoration(
                      hintText: '상품명 또는 키워드 검색',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    splashRadius: 18,
                    icon: const Icon(Icons.close, color: Colors.black38),
                    onPressed: () {
                      _searchController.clear();
                      searchQuery = '';
                      _applyFilter();
                      FocusScope.of(context).unfocus();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- (변경) 카테고리/정렬/뷰 ----------
  Widget _topControls(int totalCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 카테고리 칩
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = selectedIndex == i;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: selected ? _brand : Colors.white,
                      border: Border.all(
                        color: selected ? _brand : Colors.black26,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      categories[i],
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // [좌] 검색결과 [우] 정렬 텍스트 + 단일 토글 아이콘
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '검색 결과: $totalCount건',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      if (searchQuery.isNotEmpty) ...[
                        const TextSpan(
                          text: ' · ',
                          style: TextStyle(color: Colors.black26),
                        ),
                        TextSpan(
                          text: '"$searchQuery"',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _textSortButton(
                label: '인기순',
                active: sortOption == '인기순',
                onTap: () {
                  if (sortOption != '인기순') {
                    setState(() => sortOption = '인기순');
                    _applyFilter();
                  }
                },
              ),
              const SizedBox(width: 12),
              _textSortButton(
                label: '금리순',
                active: sortOption == '금리순',
                onTap: () {
                  if (sortOption != '금리순') {
                    setState(() => sortOption = '금리순');
                    _applyFilter();
                  }
                },
              ),
              const SizedBox(width: 10),
              _singleViewToggle(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textSortButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? _brand : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _singleViewToggle() {
    final icon = _gridMode ? Icons.view_list_rounded : Icons.grid_view_rounded;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _gridMode = !_gridMode);
        _applyFilter();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Icon(icon, size: 22, color: _brand),
      ),
    );
  }

  // ---------- 해시태그 유틸 ----------
  List<String> _purposesOf(DepositProduct e) {
    final p = e.purpose;
    if (p is List) {
      return (p as List<dynamic>)
          .map((x) => x.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    } else if (p is String) {
      final parts = p.split(RegExp(r'[,\n\r\t ]+'));
      return parts.where((t) => t.trim().isNotEmpty).toList();
    }
    return [];
  }

  Widget _chip(String raw) {
    final txt = raw.startsWith('#') ? raw : '#$raw';
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _brand.withOpacity(0.25)),
      ),
      alignment: Alignment.center,
      child: Text(txt, style: const TextStyle(fontSize: 11.5, color: _brand)),
    );
  }

  Widget _purposeChipsCompact(DepositProduct e) {
    final tags = _purposesOf(e);
    if (tags.isEmpty) return const SizedBox.shrink();
    final shown = tags.take(2).toList();
    final more = tags.length - shown.length;

    return SizedBox(
      height: 22,
      child: Row(
        children: [
          ...shown.map(_chip),
          if (more > 0)
            Container(
              height: 22,
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _brand.withOpacity(0.25)),
              ),
              alignment: Alignment.center,
              child: Text(
                '+$more',
                style: const TextStyle(fontSize: 11.5, color: _brand),
              ),
            ),
        ],
      ),
    );
  }

  Widget _purposeChipsOneLine(DepositProduct e) {
    final tags = _purposesOf(e);
    if (tags.isEmpty) return const SizedBox(height: 0);

    return SizedBox(
      height: 22,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length.clamp(0, 10),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => _chip(tags[i]),
      ),
    );
  }

  // ---------- GRID 카드 ----------
  Widget _gridCard(DepositProduct item, int index) {
    final name = (item.name ?? '').replaceAll('<br>', '\n');

    return InkWell(
      // onTap: () => Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (_) => DepositDetailPage(productId: item.productId),
      //     settings: const RouteSettings(name: '/deposit/detail'),
      //   ),
      // ),
      onTap: () async {
        // 클릭 로깅 → 상세 이동
        await _logProductClick(item, index, source: 'grid');
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DepositDetailPage(productId: item.productId),
            settings: const RouteSettings(name: '/deposit/detail'),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  SizedBox(
                    height: 86,
                    child: Center(
                      child: RoundProductIcon(product: item, size: 58),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 38,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        strutStyle: const StrutStyle(
                          forceStrutHeight: true,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _purposeChipsOneLine(item),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _RatePill(
                          text: '최고 ${item.maxRate.toStringAsFixed(2)}%',
                          brand: _brand,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '기본 ${item.minRate.toStringAsFixed(2)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- LIST 카드 ----------
  Widget _listCard(DepositProduct item, int index) {
    final rank = index + 1;
    final name = (item.name ?? '').replaceAll('<br>', '\n');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // onTap: () => Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) => DepositDetailPage(productId: item.productId),
        //     settings: const RouteSettings(name: '/deposit/detail'),
        //   ),
        // ),
        onTap: () async {
          await _logProductClick(item, index, source: 'list');
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DepositDetailPage(productId: item.productId),
              settings: const RouteSettings(name: '/deposit/detail'),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 순위 + 메달
                  SizedBox(
                    width: 50, // 필요하면 32~40으로 줄여도 OK
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$rank',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (rank <= 3) MedalRibbon(rank: rank, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 자동 추천 아이콘 배지
                  RoundProductIcon(product: item, size: 40),
                  const SizedBox(width: 12),

                  // 제목 + 해시태그
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _purposeChipsCompact(item),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 오른쪽 금리 (🔻 폭을 줄인 버전)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 72,
                    ), // ← 여기만 줄이면 됨
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '최고 ${item.maxRate.toStringAsFixed(2)}%',
                          style: const TextStyle(
                            color: _brand,
                            fontSize: 13, // 14 → 13
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2), // 4 → 2
                        Text(
                          '기본 ${item.minRate.toStringAsFixed(2)}%',
                          style: const TextStyle(
                            fontSize: 11, // 12 → 11
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 더보기/간략히 ----------
  Widget _moreLessArea(int totalForPage) {
    final total = totalForPage;
    final showing = itemsToShow.clamp(0, total);
    final items = <Widget>[];

    if (total > itemsToShow) {
      items.add(
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              itemsToShow = (itemsToShow + (_gridMode ? 8 : 5)).clamp(0, total);
            });
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.expand_more, size: 18, color: _brand),
                SizedBox(width: 6),
                Text(
                  '더 보기',
                  style: TextStyle(fontWeight: FontWeight.w600, color: _brand),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if ((_gridMode ? 10 : 7) < itemsToShow) {
      items.add(
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => itemsToShow = _gridMode ? 8 : 6),
          child: const Padding(
            padding: EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.expand_less, size: 16, color: Colors.black45),
                SizedBox(width: 6),
                Text('간략히 보기', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const Divider(height: 1),
        ...items,
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$showing/$total',
            style: const TextStyle(fontSize: 12, color: Colors.black38),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCurrent = filteredProducts.length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('예적금 목록'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black87,
        bottom: _searchBar(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _topControls(totalCurrent),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) {
                      setState(() {
                        selectedIndex = i;
                        itemsToShow = _gridMode ? 8 : 6;
                      });
                      _applyFilter();
                      _logCategoryView(i); // ← 추가
                    },
                    itemCount: categories.length,
                    itemBuilder: (context, pageIndex) {
                      final pageList = _computeFiltered(pageIndex);
                      final visible = pageList.take(itemsToShow).toList();

                      // 현재 페이지 화면에 실제로 보이는 상품 리스트 임프레션(중복 방지됨)
                      _scheduleImpressionLog(visible, pageIndex);

                      return RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: _gridMode
                            ? _buildGridForPage(visible, pageList.length)
                            : _buildListForPage(visible, pageList.length),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildListForPage(List<DepositProduct> visible, int totalForPage) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visible.length + 1,
      itemBuilder: (_, i) {
        if (i == visible.length) return _moreLessArea(totalForPage);
        return _listCard(visible[i], i);
      },
    );
  }

  Widget _buildGridForPage(List<DepositProduct> visible, int totalForPage) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _gridCard(visible[i], i),
              childCount: visible.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
          ),
        ),
        SliverToBoxAdapter(child: _moreLessArea(totalForPage)),
      ],
    );
  }
}

/// “최고 금리” 미니 칩 (텍스트 길이만큼)
class _RatePill extends StatelessWidget {
  final String text;
  final Color brand;
  const _RatePill({required this.text, required this.brand});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IntrinsicWidth(
        child: Container(
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [brand.withOpacity(0.10), brand.withOpacity(0.04)],
            ),
            border: Border.all(color: brand.withOpacity(0.18), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: brand,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  text,
                  style: TextStyle(
                    color: brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 메달 리본 (1:금 / 2:은 / 3:동)
class MedalRibbon extends StatelessWidget {
  final int rank;
  final double size;
  const MedalRibbon({super.key, required this.rank, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(rank);
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: style.circleColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: style.borderColor, width: 1),
          ),
          child: Icon(Icons.star, color: Colors.white, size: size * 0.55),
        ),
        CustomPaint(
          size: Size(size * 0.65, size * 0.22),
          painter: _OverlappedFlatBowPainter(
            style.ribbonLeft,
            style.ribbonRight,
          ),
        ),
      ],
    );
  }

  _MedalFlatStyle _styleFor(int r) {
    if (r == 1) {
      return _MedalFlatStyle(
        circleColors: const [Color(0xFFFFE082), Color(0xFFFFC107)],
        borderColor: const Color(0xFFFFB300),
        ribbonLeft: const Color(0xFFF0D46A),
        ribbonRight: const Color(0xFFE5C45A),
      );
    } else if (r == 2) {
      return _MedalFlatStyle(
        circleColors: const [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
        borderColor: const Color(0xFF9E9E9E),
        ribbonLeft: const Color(0xFFDADADA),
        ribbonRight: const Color(0xFFCFCFCF),
      );
    } else {
      return _MedalFlatStyle(
        circleColors: const [Color(0xFFE1A869), Color(0xFFCD7F32)],
        borderColor: const Color(0xFFB36A2E),
        ribbonLeft: const Color(0xFFD7A571),
        ribbonRight: const Color(0xFFCB9259),
      );
    }
  }
}

class _OverlappedFlatBowPainter extends CustomPainter {
  final Color leftColor;
  final Color rightColor;
  final double overlap;

  _OverlappedFlatBowPainter(
    this.leftColor,
    this.rightColor, {
    this.overlap = 0.7,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final double leftApexX = w * (0.5 + overlap / 2);
    final double rightApexX = w * (0.5 - overlap / 2);

    final left = Path()
      ..moveTo(leftApexX, h * 0.5)
      ..lineTo(0, 0)
      ..lineTo(0, h)
      ..close();
    final right = Path()
      ..moveTo(rightApexX, h * 0.5)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(
      left,
      Paint()
        ..color = leftColor
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      right,
      Paint()
        ..color = rightColor
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MedalFlatStyle {
  final List<Color> circleColors;
  final Color borderColor;
  final Color ribbonLeft;
  final Color ribbonRight;
  _MedalFlatStyle({
    required this.circleColors,
    required this.borderColor,
    required this.ribbonLeft,
    required this.ribbonRight,
  });
}

/// =====================
/// 아이콘 자동 추천 배지
/// =====================
class SmartProductBadge extends StatelessWidget {
  final DepositProduct product;
  final double size;
  final double radius;

  const SmartProductBadge({
    super.key,
    required this.product,
    this.size = 56,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final info = _combinedText(product);
    final icon = _pickIcon(info);
    final color = _seedColor(
      product.productId?.toString() ?? product.name ?? '',
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(.95), color.withOpacity(.75)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: size * 0.55),
    );
  }

  IconData _pickIcon(String text) {
    if (_has(text, ['육아', '아이', '아기', '가족'])) return Icons.child_friendly;
    if (_has(text, ['모임', '공동', '동호회'])) return Icons.groups_rounded;
    if (_has(text, ['출석', '매일', '체크', '출첵'])) return Icons.event_available;
    if (_has(text, ['연금', '퇴직'])) return Icons.payments_rounded;
    if (_has(text, ['주택', '전세', '집', '부동산'])) return Icons.home_rounded;
    if (_has(text, ['자동차', '차량', '카']))
      return Icons.directions_car_filled_rounded;
    if (_has(text, ['여행', '트래블'])) return Icons.flight_takeoff_rounded;
    if (_has(text, ['청년', '사회초년생', '첫월급'])) return Icons.rocket_launch_rounded;
    if (_has(text, ['지역', '상생', '로컬'])) return Icons.handshake_rounded;
    if (_has(text, ['사랑', '천사', '기부', '나눔']))
      return Icons.volunteer_activism_rounded;

    if (_has(text, ['예금'])) return Icons.account_balance_rounded;
    if (_has(text, ['적금', '저축'])) return Icons.savings_rounded;
    if (_has(text, ['입출금', '자유'])) return Icons.account_balance_wallet_rounded;

    if (_has(text, ['자이언츠', '롯데', '야구'])) return Icons.sports_baseball_rounded;

    return Icons.account_circle_rounded;
  }

  bool _has(String haystack, List<String> needles) =>
      needles.any((k) => haystack.contains(k));

  String _combinedText(DepositProduct p) {
    final name = (p.name ?? '');
    final cat = (p.category ?? '');
    final purposes = _purposesFromAny(p.purpose).join(' ');
    return '$name $cat $purposes'.toLowerCase();
  }

  List<String> _purposesFromAny(dynamic v) {
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    } else if (v is String) {
      return v
          .split(RegExp(r'[,\s]+'))
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  Color _seedColor(String seed) {
    if (seed.isEmpty) seed = 'seed';
    final code = seed.codeUnits.fold<int>(
      0,
      (a, b) => (a * 31 + b) & 0x7fffffff,
    );
    final hue = (code % 360).toDouble();
    final hsl = HSLColor.fromAHSL(1, hue, 0.55, 0.58);
    return hsl.toColor();
  }
}

// 썸네일 스타일 스위치 (emoji / monogram)
enum ThumbStyle { emoji, monogram }

const ThumbStyle _thumbStyle = ThumbStyle.emoji;

Widget _buildThumb(
  DepositProduct product, {
  double size = 56,
  double radius = 10,
}) {
  switch (_thumbStyle) {
    case ThumbStyle.monogram:
      return MonogramThumb(
        text: product.name ?? '',
        size: size,
        radius: radius,
      );
    case ThumbStyle.emoji:
    default:
      return EmojiThumb(product: product, size: size, radius: radius);
  }
}

// 이모지 배지
class EmojiThumb extends StatelessWidget {
  final DepositProduct product;
  final double size;
  final double radius;
  const EmojiThumb({
    super.key,
    required this.product,
    this.size = 56,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = _pickEmoji(product);
    final seed = (product.productId?.toString() ?? product.name ?? 'seed');
    final bg = _seedColor(seed);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg.withOpacity(.95), bg.withOpacity(.75)],
        ),
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(.20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.62),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _mix(DepositProduct p) {
    final name = (p.name ?? '');
    final cat = (p.category ?? '');
    final purpose = _purposesFromAny(p.purpose).join(' ');
    return '$name $cat $purpose'.toLowerCase();
  }

  String _pickEmoji(DepositProduct p) {
    final t = _mix(p);
    if (_has(t, ['육아', '아이', '아기'])) return '🍼';
    if (_has(t, ['천사', '사랑', '기부'])) return '💝';
    if (_has(t, ['모임', '공동'])) return '👥';
    if (_has(t, ['출석', '매일', '체크'])) return '✅';
    if (_has(t, ['연금', '노후', '퇴직'])) return '👴';
    if (_has(t, ['주택', '전세', '집'])) return '🏠';
    if (_has(t, ['자동차', '차량', '카'])) return '🚗';
    if (_has(t, ['여행', '트래블'])) return '✈️';
    if (_has(t, ['지역', '상생'])) return '🤝';
    if (_has(t, ['자이언츠', '야구', '롯데'])) return '⚾️';
    if (_has(t, ['예금'])) return '🏦';
    if (_has(t, ['적금', '저축'])) return '💰';
    if (_has(t, ['입출금', '자유'])) return '💳';
    return '💡';
  }

  bool _has(String haystack, List<String> needles) =>
      needles.any((k) => haystack.contains(k));

  List<String> _purposesFromAny(dynamic v) {
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    } else if (v is String) {
      return v
          .split(RegExp(r'[,\s]+'))
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  Color _seedColor(String seed) {
    final code = seed.codeUnits.fold<int>(
      0,
      (a, b) => (a * 31 + b) & 0x7fffffff,
    );
    final hue = (code % 360).toDouble();
    final hsl = HSLColor.fromAHSL(1, hue, 0.55, 0.58);
    return hsl.toColor();
  }
}

// 모노그램 배지
class MonogramThumb extends StatelessWidget {
  final String text;
  final double size;
  final double radius;
  const MonogramThumb({
    super.key,
    required this.text,
    this.size = 56,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final seed = text.isNotEmpty ? text : 'seed';
    final bg = _seedColor(seed);
    final mono = _initials(text);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: bg,
      ),
      alignment: Alignment.center,
      child: Text(
        mono,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _initials(String s) {
    final t = s.trim();
    if (t.isEmpty) return 'BN';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return t.characters.take(2).toString().toUpperCase();
  }

  Color _seedColor(String seed) {
    final code = seed.codeUnits.fold<int>(
      0,
      (a, b) => (a * 33 + b) & 0x7fffffff,
    );
    final hue = (code % 360).toDouble();
    final hsl = HSLColor.fromAHSL(1, hue, 0.50, 0.55);
    return hsl.toColor();
  }
}

/// 원형 아이콘 배지 (키워드 → 아이콘/색 자동)
class RoundProductIcon extends StatelessWidget {
  final DepositProduct product;
  final double size;
  final double borderWidth;
  const RoundProductIcon({
    super.key,
    required this.product,
    this.size = 56,
    this.borderWidth = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _pickMeta(product);
    final base = meta.color;
    final grad = [base.withOpacity(.95), base.withOpacity(.78)];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
        boxShadow: [
          BoxShadow(
            color: base.withOpacity(.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(.85),
          width: borderWidth,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(meta.icon, color: Colors.white, size: size * 0.52),
    );
  }

  _IconMeta _pickMeta(DepositProduct p) {
    final text = _mix(p);
    final id = (p.productId ?? '').toString();
    if (_overrideById.containsKey(id)) {
      final ov = _overrideById[id]!;
      return _IconMeta(ov.$1, ov.$2);
    }
    for (final r in _rules) {
      if (r.matches(text)) return _IconMeta(r.icon, r.color);
    }
    final cat = (p.category ?? '').toLowerCase();
    if (cat.contains('예금'))
      return _IconMeta(Icons.account_balance_rounded, const Color(0xFF3D5AFE));
    if (cat.contains('적금'))
      return _IconMeta(Icons.savings_rounded, const Color(0xFF2E7D32));
    if (cat.contains('입출금'))
      return _IconMeta(
        Icons.account_balance_wallet_rounded,
        const Color(0xFF6D4C41),
      );
    final color = _seedColor(id.isNotEmpty ? id : (p.name ?? 'seed'));
    return _IconMeta(Icons.category_rounded, color);
  }

  String _mix(DepositProduct p) {
    final name = (p.name ?? '');
    final cat = (p.category ?? '');
    final purpose = _purposesFromAny(p.purpose).join(' ');
    return '$name $cat $purpose'.toLowerCase();
  }

  List<String> _purposesFromAny(dynamic v) {
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    } else if (v is String) {
      return v
          .split(RegExp(r'[,\s]+'))
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  static const Map<String, (IconData, Color)> _overrideById = {};

  static final List<_IconRule> _rules = [
    _IconRule(
      keys: ['육아', '아이', '아기', '보육'],
      icon: Icons.child_friendly,
      color: Color(0xFFEC4899),
    ),
    _IconRule(
      keys: ['모임', '공동', '동호회', '동아리'],
      icon: Icons.groups_rounded,
      color: Color(0xFF0EA5E9),
    ),
    _IconRule(
      keys: ['출석', '매일', '체크', '도장'],
      icon: Icons.event_available,
      color: Color(0xFF6366F1),
    ),
    _IconRule(
      keys: ['연금', '노후', '퇴직'],
      icon: Icons.payments_rounded,
      color: Color(0xFF14B8A6),
    ),
    _IconRule(
      keys: ['주택', '전세', '집', '부동산'],
      icon: Icons.home_rounded,
      color: Color(0xFF7C3AED),
    ),
    _IconRule(
      keys: ['자동차', '차량', '카', '모빌리티'],
      icon: Icons.directions_car_filled_rounded,
      color: Color(0xFFF59E0B),
    ),
    _IconRule(
      keys: ['여행', '해외', '트래블'],
      icon: Icons.flight_takeoff_rounded,
      color: Color(0xFF06B6D4),
    ),
    _IconRule(
      keys: ['청년', '첫월급', '사회초년생', '신입'],
      icon: Icons.rocket_launch_rounded,
      color: Color(0xFF22C55E),
    ),
    _IconRule(
      keys: ['지역', '상생', '로컬', '동네'],
      icon: Icons.handshake_rounded,
      color: Color(0xFF10B981),
    ),
    _IconRule(
      keys: ['사랑', '천사', '기부', '나눔'],
      icon: Icons.volunteer_activism_rounded,
      color: Color(0xFFE11D48),
    ),
    _IconRule(
      keys: ['건강', '헬스', '의료'],
      icon: Icons.favorite_rounded,
      color: Color(0xFFEF4444),
    ),
    _IconRule(
      keys: ['교육', '등록금', '장학'],
      icon: Icons.school_rounded,
      color: Color(0xFF3B82F6),
    ),
    _IconRule(
      keys: ['결혼', '웨딩', '신혼'],
      icon: Icons.ring_volume_rounded,
      color: Color(0xFFFB7185),
    ),
    _IconRule(
      keys: ['펫', '반려', '애완'],
      icon: Icons.pets_rounded,
      color: Color(0xFF8B5CF6),
    ),
    _IconRule(
      keys: ['군인', '병사', '국방', '장병'],
      icon: Icons.military_tech_rounded,
      color: Color(0xFF64748B),
    ),
    _IconRule(
      keys: ['환경', '친환경', '그린'],
      icon: Icons.eco_rounded,
      color: Color(0xFF16A34A),
    ),
    _IconRule(
      keys: ['쇼핑', '소비', '포인트'],
      icon: Icons.local_mall_rounded,
      color: Color(0xFF0EA5E9),
    ),
    _IconRule(
      keys: ['보험'],
      icon: Icons.verified_user_rounded,
      color: Color(0xFF0284C7),
    ),
    _IconRule(
      keys: ['자이언츠', '야구', '롯데'],
      icon: Icons.sports_baseball_rounded,
      color: Color(0xFFF97316),
    ),
    _IconRule(
      keys: ['예금'],
      icon: Icons.account_balance_rounded,
      color: Color(0xFF3D5AFE),
    ),
    _IconRule(
      keys: ['적금', '저축'],
      icon: Icons.savings_rounded,
      color: Color(0xFF2E7D32),
    ),
    _IconRule(
      keys: ['입출금', '자유'],
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF6D4C41),
    ),
  ];

  Color _seedColor(String seed) {
    if (seed.isEmpty) seed = 'seed';
    final code = seed.codeUnits.fold<int>(
      0,
      (a, b) => (a * 31 + b) & 0x7fffffff,
    );
    final hue = (code % 360).toDouble();
    final hsl = HSLColor.fromAHSL(1, hue, 0.58, 0.55);
    return hsl.toColor();
  }
}

class _IconRule {
  final List<String> keys;
  final IconData icon;
  final Color color;
  const _IconRule({
    required this.keys,
    required this.icon,
    required this.color,
  });
  bool matches(String text) => keys.any((k) => text.contains(k));
}

class _IconMeta {
  final IconData icon;
  final Color color;
  const _IconMeta(this.icon, this.color);
}
