import 'package:flutter/material.dart';
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/pages/deposit/deposit_detail_page.dart';
import 'package:reframe/service/deposit_service.dart' as DepositService;

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

  late final PageController _pageController; // ✅ 카테고리 스와이프용

  @override
  void initState() {
    super.initState();
    selectedIndex = categories.indexOf(widget.initialCategory);
    if (selectedIndex < 0) selectedIndex = 0;
    _pageController = PageController(
      initialPage: selectedIndex,
    ); // ✅ 초기 페이지 동기화
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

  /// ✅ 카테고리 인덱스를 인자로 받아 '그 페이지의' 결과를 계산
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

  /// ✅ 현재 선택된 카테고리 기준 결과만 상태에 반영
  void _applyFilter() {
    final result = _computeFiltered(selectedIndex);
    setState(() {
      filteredProducts = result;
      itemsToShow = _gridMode ? 8 : 6;
    });
  }

  // ---------- 공통 UI ----------
  PreferredSizeWidget _searchBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(66),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.search, color: _brand),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) {
                      searchQuery = v.trim();
                      _applyFilter();
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
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _twoLineFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1줄: 카테고리 (전체 / 예금 / 적금 / 입출금)
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
                    // ✅ pill 탭 → 페이지 전환 (애니메이션)
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                    // 페이지 변경 콜백에서 selectedIndex/_applyFilter가 호출됨
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFEFF2FF) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x11000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      categories[i],
                      style: TextStyle(
                        color: selected ? _brand : Colors.black87,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // 2줄: 정렬(인기/금리) + 뷰 전환(리스트/그리드)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Row(
            children: [
              // 정렬 토글
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x11000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ToggleButtons(
                  isSelected: [sortOption == '인기순', sortOption == '금리순'],
                  onPressed: (idx) {
                    setState(() => sortOption = idx == 0 ? '인기순' : '금리순');
                    _applyFilter();
                  },
                  borderRadius: BorderRadius.circular(10),
                  selectedColor: Colors.white,
                  color: Colors.black87,
                  fillColor: _brand,
                  constraints: const BoxConstraints(
                    minHeight: 36,
                    minWidth: 74,
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('인기순'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('금리순'),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // 뷰 전환 (리스트 / 그리드)
              Row(
                children: [
                  _iconPill(
                    icon: Icons.view_list_rounded,
                    onTap: () {
                      if (_gridMode) {
                        setState(() => _gridMode = false);
                        _applyFilter();
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _iconPill(
                    icon: Icons.grid_view_rounded,
                    onTap: () {
                      if (!_gridMode) {
                        setState(() => _gridMode = true);
                        _applyFilter();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _brand),
            const SizedBox(width: 4),
            Text(
              label, // ✅ label 실제 반영
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _brand,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconPill({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: _brand),
      ),
    );
  }

  Text _highlight(
    String source,
    String query, {
    TextStyle? base,
    TextStyle? highlight,
  }) {
    final baseStyle =
        base ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    final hiStyle =
        highlight ??
        const TextStyle(color: _brand, fontWeight: FontWeight.w800);
    if (query.isEmpty) {
      return Text(
        source,
        style: baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    final lowerSrc = source.toLowerCase(), lowerQ = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lowerSrc.indexOf(lowerQ, start);
      if (idx < 0) {
        spans.add(TextSpan(text: source.substring(start), style: baseStyle));
        break;
      }
      if (idx > start) {
        spans.add(
          TextSpan(text: source.substring(start, idx), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: source.substring(idx, idx + query.length),
          style: baseStyle.merge(hiStyle),
        ),
      );
      start = idx + query.length;
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // GRID(콤팩트)
  Widget _gridCard(DepositProduct item, int index) {
    final name = (item.name ?? '').replaceAll('<br>', '\n');
    const titleStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DepositDetailPage(productId: item.productId),
        ),
      ),
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
            // 이미지 + 좌상단 순위
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  SizedBox(
                    height: 90,
                    child: Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          'assets/ani/people.gif',
                          fit: BoxFit.contain,
                        ),
                      ),
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

            // 최고 금리 스트립
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _RateStrip(maxRate: item.maxRate, brand: _brand),
            ),

            // 본문
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      height: 38,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                        strutStyle: const StrutStyle(
                          forceStrutHeight: true,
                          height: 1.25,
                        ),
                      ),
                    ),
                    Text(
                      '기본 ${item.minRate.toStringAsFixed(2)}% · 기간 ${item.period}개월',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // LIST
  Widget _listCard(DepositProduct item, int index) {
    final rank = index + 1;
    final name = (item.name ?? '').replaceAll('<br>', '\n');
    final bool rankOnlyCenter = rank >= 4;
    final TextAlign titleAlign = TextAlign.start;

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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DepositDetailPage(productId: item.productId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 46,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/ani/people.gif',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: titleAlign,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '최고 ${item.maxRate.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      color: _brand,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '기본 ${item.minRate.toStringAsFixed(2)}%',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '기간 ${item.period}개월',
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ 페이지별 total을 받아서 표시
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
    final totalCurrent = filteredProducts.length; // 현재 페이지 결과 수

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                _twoLineFilter(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Row(
                    children: [
                      Text(
                        '검색 결과: $totalCurrent건',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      if (searchQuery.isNotEmpty)
                        Text(
                          '"$searchQuery"',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),

                /// ✅ 본문을 카테고리별 페이지로 구성. 좌우 스와이프 가능.
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) {
                      // 스와이프 → 선택 카테고리 동기화
                      setState(() {
                        selectedIndex = i;
                        // 페이지 바뀌면 보여줄 개수 초기화(모드별 기본값)
                        itemsToShow = _gridMode ? 8 : 6;
                      });
                      _applyFilter();
                    },
                    itemCount: categories.length,
                    itemBuilder: (context, pageIndex) {
                      // 이 페이지의 전체/보여줄 목록 계산
                      final pageList = _computeFiltered(pageIndex);
                      final visible = pageList.take(itemsToShow).toList();

                      // 내부는 기존 레이아웃 재사용 (리스트/그리드)
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

  // ✅ 페이지 전용 빌더(더보기 영역에 페이지 total 전달)
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

/// ====== ‘최고 금리’ 강조 스트립 ======
class _RateStrip extends StatelessWidget {
  final double maxRate;
  final Color brand;
  const _RateStrip({required this.maxRate, required this.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            '최고 ${maxRate.toStringAsFixed(2)}%',
            style: TextStyle(
              color: brand,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// ===== 메달 리본 =====
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

    final lp = Paint()
      ..color = leftColor
      ..isAntiAlias = true;
    final rp = Paint()
      ..color = rightColor
      ..isAntiAlias = true;

    canvas.drawPath(left, lp);
    canvas.drawPath(right, rp);
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
