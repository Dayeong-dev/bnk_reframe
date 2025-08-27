import 'package:flutter/material.dart';
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/pages/deposit/deposit_detail_page.dart';
import 'package:reframe/service/deposit_service.dart' as DepositService;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:reframe/service/analytics_service.dart';
import 'package:reframe/service/subscriber_service.dart'; // ← 가입자수 API

/// 예적금 목록 (아이콘 자동 추천 + HOT 배지)
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

  // 가입자수(고유 사용자 수) 캐시: productId -> distinctUsers
  final Map<int, int> _subscriberCountByProduct = {};

// 디버그 스위치: true면 가입자수 기반 HOT, false면 기존 조회수 폴백(테스트용)
  bool _useSubscriberHot = true;

// 디버그 로그 on/off
  bool _debugHot = true;

  Future<void> _rebuildHotBySubscribers() async {
    if (!_useSubscriberHot) return;

    final ids = allProducts
        .map((e) => e.productId)
        .where((id) => id != null)
        .map((id) => id!)
        .toList();

    if (_debugHot) debugPrint('[HOT] 가입자수 수집 대상: ${ids.length}개');

    // 너무 많은 동시 요청 방지용 배치
    const batchSize = 10;
    _subscriberCountByProduct.clear();

    for (int i = 0; i < ids.length; i += batchSize) {
      final batch = ids.sublist(i, (i + batchSize).clamp(0, ids.length));
      if (_debugHot) {
        debugPrint('[HOT] 배치 ${i ~/ batchSize + 1} 요청 (size=${batch.length})');
      }

      await Future.wait(batch.map((pid) async {
        try {
          final distinct = await SubscriberService.fetchDistinctUsers(pid);
          _subscriberCountByProduct[pid] = distinct;
          if (_debugHot) {
            debugPrint('[HOT] OK product=$pid, distinct=$distinct');
          }
        } catch (e) {
          if (_debugHot) {
            debugPrint('[HOT] FAIL product=$pid, error=$e');
          }
        }
      }));
    }

    // 내림차순 정렬 → TOP10 뽑기
    final sorted = _subscriberCountByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top10 = sorted.take(10).map((e) => e.key.toString()).toSet();

    // 가입자수 데이터가 전무하면 안전하게 HOT 비우기(또는 필요시 조회수 폴백 켜도 됨)
    if (top10.isEmpty) {
      if (_debugHot) debugPrint('[HOT] 가입자수 데이터 없음 → HOT 비움');
      setState(() => _hotIds = <String>{});
      return;
    }

    setState(() {
      _hotIds = top10;
    });
    if (_debugHot) debugPrint('[HOT] 가입자수 기반 TOP10: $_hotIds');
  }

  // 🔥 전체 TOP10 id(문자열로 통일) — 로컬에서 계산
  Set<String> _hotIds = <String>{};
  bool _isHot(DepositProduct item) {
    final idStr = '${item.productId}';
    if (idStr.isEmpty || idStr == 'null') return false;
    return _hotIds.contains(idStr);
  }

  static const _brand = Color(0xFF304FFE);
  static const _bg = Colors.white; // 전체 배경 흰색

  late final PageController _pageController;

  // Analytics
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  String? _lastImpressionSig;

  String _productTypeOf(DepositProduct e) {
    final c = (e.category ?? '').trim();
    return c == '입출금자유' ? '입출금' : (c.isEmpty ? '기타' : c);
  }

  Future<void> _logCategoryView(int index) async {
    final cat = categories[index];
    await _analytics.logEvent(
      name: 'category_view',
      parameters: {'category': cat, 'view_mode': _gridMode ? 'grid' : 'list'},
    );
  }

  Future<void> _logSearch(String query) async {
    if (query.trim().isEmpty) return;
    await _analytics.logEvent(
      name: 'search',
      parameters: {'q': query.trim(), 'category': categories[selectedIndex]},
    );
  }

  // [beobjin] 20250825 17:36 -  AnalyticsService.logSelectProduct() 로 대체함.
  Future<void> _logProductClick(
    DepositProduct item,
    int index, {
    required String source,
  }) async {
    await _analytics.logEvent(
      name: 'product_list_click',
      parameters: {
        'product_id': '${item.productId}',
        'product_type': _productTypeOf(item),
        'category': item.category ?? '',
        'pos': index + 1,
        'source': source,
      },
    );
  }

  void _scheduleImpressionLog(List<DepositProduct> visible, int pageIndex) {
    final ids = visible.map((e) => e.productId).map((v) => '$v').join(',');
    final sig = '$pageIndex|${_gridMode ? 'grid' : 'list'}|$ids';
    if (_lastImpressionSig == sig) return;
    _lastImpressionSig = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shortCsv = visible.take(20).map((e) => '${e.productId}').join(',');
      await _analytics.logEvent(
        name: 'product_list_impression',
        parameters: {
          'category': categories[pageIndex],
          'variant': _gridMode ? 'grid' : 'list',
          'count': visible.length,
          'items': shortCsv,
        },
      );
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

      // 🔥 전체 기준 TOP10 (가입자수 기반)
      await _rebuildHotBySubscribers();

      _applyFilter();
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('목록을 불러오지 못했어요: $e')));
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
      result.sort((a, b) => (b.viewCount ?? 0).compareTo(a.viewCount ?? 0));
    } else {
      result.sort((a, b) => (b.maxRate).compareTo(a.maxRate));
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
                      _logSearch(searchQuery);
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

  // ---------- 카테고리/정렬/뷰 ----------
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
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // [좌] 검색결과 [우] 정렬 + 뷰토글
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
      onTap: () async {
        // [beobjin] 20250825 17:36 -  AnalyticsService.logSelectProduct() 로 대체함.
        await _logProductClick(item, index, source: 'grid');
        // await AnalyticsService.logSelectProduct(
        //   productId: item.productId,
        //   name: item.name,
        //   category: item.category,
        //   listName: 'deposit_list',
        // );
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
                color: Color(0x14000000), blurRadius: 5, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== 상단 썸네일 영역 =====
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 75,
                    child: Align(
                      alignment: const Alignment(0, 0.70),
                      child: RoundProductIcon(product: item, size: 56),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 8,
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (_isHot(item))
                    const Positioned(top: 8, right: 8, child: _HotTextBadge()),
                ],
              ),
            ),

            // ===== 본문 =====
            Padding(
              // ✅ 상/하 동일 패딩으로 통일 (12,10,12,10 → 12,10,12,10 권장)
              //   * 지금 코드 하단에 SizedBox(6)가 있었는데, 아래에서 제거해 상/하 완전 대칭
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 32,
                    child: _AutoVCenterTitle(
                      text: name,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      strutStyle: const StrutStyle(
                          forceStrutHeight: true, height: 1.20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _purposeChipsOneLine(item),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Text(
                        '최고 ${item.maxRate.toStringAsFixed(2)}%',
                        softWrap: false,
                        style: const TextStyle(
                            color: _brand,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '기본 ${item.minRate.toStringAsFixed(2)}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),

                  // 🚫 하단 추가 여백 제거(기존 const SizedBox(height: 6))
                ],
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
        onTap: () async {
          // [beobjin] 20250825 17:36 -  AnalyticsService.logSelectProduct() 로 대체함.
          await _logProductClick(item, index, source: 'list');
          // await AnalyticsService.logSelectProduct(
          //   productId: item.productId,
          //   name: item.name,
          //   category: item.category,
          //   listName: 'deposit_list', // 필요시 리스트명 변경
          // );
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 순위 + 메달(리스트는 기존 유지)
              SizedBox(
                width: 50,
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
                    if (rank <= 3) MedalRibbon(rank: rank, size: 20),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              RoundProductIcon(product: item, size: 40),
              const SizedBox(width: 12),

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

              SizedBox(
                width: 84,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isHot(item)) const _HotTextBadge(),
                    const SizedBox(height: 4),
                    Text(
                      '최고 ${item.maxRate.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        color: _brand,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '기본 ${item.minRate.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
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
  }

  // ---------- 하단 “더보기/간략히” ----------
  Widget _moreLessArea(int totalForPage) {
    final total = totalForPage;

    final canMore = total > itemsToShow;
    final canLess = (_gridMode ? 10 : 7) < itemsToShow;
    if (!canMore && !canLess) return const SizedBox.shrink();

    final List<Widget> controls = [];
    if (canMore) {
      controls.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.expand_more, size: 18),
            label: const Text('더보기',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              setState(() {
                itemsToShow =
                    (itemsToShow + (_gridMode ? 8 : 5)).clamp(0, total);
              });
            },
          ),
        ),
      );
    }
    if (canLess) {
      controls.add(
        TextButton.icon(
          icon: const Icon(Icons.expand_less),
          label: const Text('간략히 보기'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black54,
            minimumSize: const Size.fromHeight(40),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => setState(() => itemsToShow = _gridMode ? 8 : 6),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            ...controls.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: w,
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCurrent = filteredProducts.length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('예적금 목록'),
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
                      _logCategoryView(i);
                    },
                    itemCount: categories.length,
                    itemBuilder: (context, pageIndex) {
                      final pageList = _computeFiltered(pageIndex);
                      final visible = pageList.take(itemsToShow).toList();

                      _scheduleImpressionLog(visible, pageIndex);

                      return RefreshIndicator(
                        onRefresh: _loadProducts,
                        color: _brand,
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

  // ⛳️ 기존 _buildGridForPage 통으로 교체
  Widget _buildGridForPage(List<DepositProduct> visible, int totalForPage) {
    // 레이아웃 여백/간격은 그대로
    const crossAxisCount = 2;
    const hPad = 12.0;
    const vPadTop = 8.0;
    const vPadBottom = 4.0;
    const crossAxisSpacing = 10.0;
    const mainAxisSpacing = 10.0;

    // ✅ 카드 "고정 높이"로 누적 오차 제거 (필요시 192~200 사이로 미세조정)
    const double kGridTileExtent = 188;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(hPad, vPadTop, hPad, vPadBottom),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _gridCard(visible[i], i),
              childCount: visible.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              // ✅ 핵심: 고정 높이로 지정
              mainAxisExtent: kGridTileExtent,
            ),
          ),
        ),
        SliverToBoxAdapter(child: _moreLessArea(totalForPage)),
      ],
    );
  }
}

/// ✅ 제목 자동 세로 정렬 위젯
/// - 1줄: 세로 중앙(centerLeft)
/// - 2줄 이상: 위쪽(topLeft)
class _AutoVCenterTitle extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final StrutStyle? strutStyle;

  const _AutoVCenterTitle({
    required this.text,
    required this.style,
    this.maxLines = 2,
    this.strutStyle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // TextPainter로 실제 라인 수 측정
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        strutStyle: strutStyle,
        ellipsis: '…',
      )..layout(maxWidth: c.maxWidth);

      final lines = painter.computeLineMetrics().length;
      final align = (lines <= 1) ? Alignment.centerLeft : Alignment.topLeft;

      return Align(
        alignment: align,
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
          strutStyle: strutStyle,
        ),
      );
    });
  }
}

/// 메달/리본 등 유틸(변경 없음)
class MedalRibbon extends StatelessWidget {
  final int rank;
  final double size;
  const MedalRibbon({super.key, required this.rank, this.size = 20});

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
          size: Size(size * 0.75, size * 0.34),
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
    this.overlap = 0.8,
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
          ..isAntiAlias = true);
    canvas.drawPath(
        right,
        Paint()
          ..color = rightColor
          ..isAntiAlias = true);
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

/// HOT 텍스트 배지(배경 없음)
class _HotTextBadge extends StatelessWidget {
  const _HotTextBadge();

  @override
  Widget build(BuildContext context) {
    return Text(
      '🔥 HOT',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Colors.redAccent,
        shadows: const [
          Shadow(color: Colors.white, blurRadius: 2, offset: Offset(0, 0)),
        ],
      ),
    );
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
    if (cat.contains('예금')) {
      return _IconMeta(Icons.account_balance_rounded, const Color(0xFF3D5AFE));
    }
    if (cat.contains('적금')) {
      return _IconMeta(Icons.savings_rounded, const Color(0xFF2E7D32));
    }
    if (cat.contains('입출금')) {
      return _IconMeta(
        Icons.account_balance_wallet_rounded,
        const Color(0xFF6D4C41),
      );
    }
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
        color: Color(0xFFEC4899)),
    _IconRule(
        keys: ['모임', '공동', '동호회', '동아리'],
        icon: Icons.groups_rounded,
        color: Color(0xFF0EA5E9)),
    _IconRule(
        keys: ['출석', '매일', '체크', '도장'],
        icon: Icons.event_available,
        color: Color(0xFF6366F1)),
    _IconRule(
        keys: ['연금', '노후', '퇴직'],
        icon: Icons.payments_rounded,
        color: Color(0xFF14B8A6)),
    _IconRule(
        keys: ['주택', '전세', '집', '부동산'],
        icon: Icons.home_rounded,
        color: Color(0xFF7C3AED)),
    _IconRule(
        keys: ['자동차', '차량', '카', '모빌리티'],
        icon: Icons.directions_car_filled_rounded,
        color: Color(0xFFF59E0B)),
    _IconRule(
        keys: ['여행', '해외', '트래블'],
        icon: Icons.flight_takeoff_rounded,
        color: Color(0xFF06B6D4)),
    _IconRule(
        keys: ['청년', '첫월급', '사회초년생', '신입'],
        icon: Icons.rocket_launch_rounded,
        color: Color(0xFF22C55E)),
    _IconRule(
        keys: ['지역', '상생', '로컬', '동네'],
        icon: Icons.handshake_rounded,
        color: Color(0xFF10B981)),
    _IconRule(
        keys: ['사랑', '천사', '기부', '나눔'],
        icon: Icons.volunteer_activism_rounded,
        color: Color(0xFFE11D48)),
    _IconRule(
        keys: ['건강', '헬스', '의료'],
        icon: Icons.favorite_rounded,
        color: Color(0xFFEF4444)),
    _IconRule(
        keys: ['교육', '등록금', '장학'],
        icon: Icons.school_rounded,
        color: Color(0xFF3B82F6)),
    _IconRule(
        keys: ['결혼', '웨딩', '신혼'],
        icon: Icons.ring_volume_rounded,
        color: Color(0xFFFB7185)),
    _IconRule(
        keys: ['펫', '반려', '애완'],
        icon: Icons.pets_rounded,
        color: Color(0xFF8B5CF6)),
    _IconRule(
        keys: ['군인', '병사', '국방', '장병'],
        icon: Icons.military_tech_rounded,
        color: Color(0xFF64748B)),
    _IconRule(
        keys: ['환경', '친환경', '그린'],
        icon: Icons.eco_rounded,
        color: Color(0xFF16A34A)),
    _IconRule(
        keys: ['쇼핑', '소비', '포인트'],
        icon: Icons.local_mall_rounded,
        color: Color(0xFF0EA5E9)),
    _IconRule(
        keys: ['보험'],
        icon: Icons.verified_user_rounded,
        color: Color(0xFF0284C7)),
    _IconRule(
        keys: ['자이언츠', '야구', '롯데'],
        icon: Icons.sports_baseball_rounded,
        color: Color(0xFFF97316)),
    _IconRule(
        keys: ['예금'],
        icon: Icons.account_balance_rounded,
        color: Color(0xFF3D5AFE)),
    _IconRule(
        keys: ['적금', '저축'],
        icon: Icons.savings_rounded,
        color: Color(0xFF2E7D32)),
    _IconRule(
        keys: ['입출금', '자유'],
        icon: Icons.account_balance_wallet_rounded,
        color: Color(0xFF6D4C41)),
  ];

  Color _seedColor(String seed) {
    if (seed.isEmpty) seed = 'seed';
    final code =
        seed.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final hue = (code % 360).toDouble();
    final hsl = HSLColor.fromAHSL(1, hue, 0.58, 0.55);
    return hsl.toColor();
  }
}

class _IconRule {
  final List<String> keys;
  final IconData icon;
  final Color color;
  const _IconRule(
      {required this.keys, required this.icon, required this.color});
  bool matches(String text) => keys.any((k) => text.contains(k));
}

class _IconMeta {
  final IconData icon;
  final Color color;
  const _IconMeta(this.icon, this.color);
}
