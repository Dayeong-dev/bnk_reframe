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

class _DepositListPageState extends State<DepositListPage> {
  List<DepositProduct> allProducts = [];
  List<DepositProduct> filteredProducts = [];

  final List<String> categories = ['전체', '예금', '적금', '입출금'];
  int selectedIndex = 0;
  int itemsToShow = 4;
  String searchQuery = '';
  String sortOption = '조회수'; // or '금리'

  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ✅ 여기! 전달받은 카테고리 초기화
    selectedIndex = categories.indexOf(widget.initialCategory);
    if (selectedIndex == -1) selectedIndex = 0;

    loadProducts(); // 전체 목록 불러오고 필터링
  }

  void loadProducts() async {
    final list = await DepositService.fetchAllProducts();
    setState(() {
      allProducts = list;
      filterList();
    });
  }

  void filterList() {
    String selectedCategory = categories[selectedIndex];
    List<DepositProduct> result = allProducts;

    if (selectedCategory != '전체') {
      result = result.where((item) {
        if (selectedCategory == '입출금') {
          // "입출금자유", "입출금 자유형" 등 포함되도록
          return item.category == '입출금자유';
        }
        return item.category == selectedCategory;
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      result = result
          .where(
            (item) =>
                item.name.contains(searchQuery) ||
                item.summary.contains(searchQuery),
          )
          .toList();
    }

    // 정렬
    if (sortOption == '조회수') {
      result.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    } else if (sortOption == '금리') {
      result.sort((a, b) => b.maxRate.compareTo(a.maxRate));
    }

    setState(() {
      filteredProducts = result;
      itemsToShow = 4;
    });
  }

  void toggleSortOption() {
    setState(() {
      sortOption = (sortOption == '조회수') ? '금리' : '조회수';
      filterList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('예적금 목록')),
      body: Column(
        children: [
          // 배너
          Container(
            height: 180,
            color: Colors.grey[300],
            alignment: Alignment.center,
            child: const Text('사진 or 슬라이더', style: TextStyle(fontSize: 18)),
          ),

          // 자세히 보기 버튼
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('자세히 알아보기'),
            ),
          ),

          // 카테고리 버튼
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: List.generate(categories.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(categories[index]),
                    selected: selectedIndex == index,
                    onSelected: (_) {
                      setState(() {
                        selectedIndex = index;
                        filterList();
                        _pageController.jumpToPage(index);
                      });
                    },
                  ),
                );
              }),
            ),
          ),

          // 검색창 + 정렬 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      searchQuery = value;
                      filterList();
                    },
                    onChanged: (text) {
                      searchQuery = text;
                      filterList();
                    },
                    decoration: InputDecoration(
                      hintText: '상품명 또는 키워드 검색',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                searchQuery = '';
                                filterList();
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: toggleSortOption,
                  icon: const Icon(Icons.sort),
                  label: Text('$sortOption순'),
                ),
              ],
            ),
          ),

          // 슬라이드 페이지뷰
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: categories.length,
              onPageChanged: (index) {
                setState(() {
                  selectedIndex = index;
                  filterList();
                });
              },
              itemBuilder: (context, pageIndex) {
                final list = filteredProducts.take(itemsToShow).toList();
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      elevation: 2,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DepositDetailPage(productId: item.productId),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name.replaceAll('<br>', '\n'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.summary.replaceAll('<br>', '\n'),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '최고금리: ${item.maxRate}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '기본금리: ${item.minRate}%',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      '가입기간: ${item.period}개월',
                                      style: const TextStyle(fontSize: 12),
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
                );
              },
            ),
          ),

          // 더보기 버튼
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  itemsToShow += 4;
                });
              },
              child: const Text('더보기'),
            ),
          ),

          // 간략히 보기 버튼
          if (itemsToShow > 4)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    itemsToShow = 4;
                  });
                },
                child: const Text('간략히 보기'),
              ),
            ),

          // 전체상품 초기화 버튼
          if (!isKeyboardVisible)
            Padding(
              padding: const EdgeInsets.all(10),
              child: ElevatedButton(
                onPressed: () {
                  _searchController.clear();
                  searchQuery = '';
                  selectedIndex = 0;
                  _pageController.jumpToPage(0);
                  filterList();
                },
                child: const Text('전체상품 보기'),
              ),
            ),
        ],
      ),
    );
  }
}
