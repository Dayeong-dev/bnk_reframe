import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../store/faq_store.dart';
import '../../../model/faq.dart';
import '../../../service/faq_api.dart';
import 'faq_detail_page.dart';

class FaqListPage extends StatefulWidget {
  const FaqListPage({super.key});
  @override
  State<FaqListPage> createState() => _FaqListPageState();
}

class _FaqListPageState extends State<FaqListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    // 첫 프레임 이후 초기 로드 + 화면이 안 차면 자동 추가 로드
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<FaqStore>().init();
      _maybeAutoloadMore();
    });

    // 끝 근처 도달 시 다음 페이지 로드
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        context.read<FaqStore>().loadNext();
      }
    });

    // 검색 텍스트 변경 → 즉시 검색
    _searchCtrl.addListener(() {
      context.read<FaqStore>().onSearchChanged(_searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// 목록 높이가 화면을 못 채우면 자동으로 다음 페이지를 더 불러오는 헬퍼
  Future<void> _maybeAutoloadMore() async {
    // 약간 대기해 레이아웃/스크롤 측정 안정화
    await Future.delayed(const Duration(milliseconds: 50));
    if (!_scroll.hasClients) return;

    final store = context.read<FaqStore>();
    int safety = 3; // 과도한 호출 방지: 최대 3번만 연속으로 더 받기
    while (_scroll.position.maxScrollExtent <= 0 &&
        !store.isLast &&
        !store.isLoading &&
        safety-- > 0) {
      await store.loadNext();
      await Future.delayed(const Duration(milliseconds: 30));
      if (!_scroll.hasClients) break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FaqStore>();

    // 외부 상태와 텍스트필드 동기화(루프 방지)
    if (_searchCtrl.text != store.search) {
      _searchCtrl.text = store.search;
      _searchCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchCtrl.text.length),
      );
    }

    const headerCount = 4; // 안내/검색/카테고리/테이블헤더 = 4개
    final itemCount = headerCount + store.items.length + 1; // +1: 로딩/끝 표시

    return Scaffold(
      appBar: AppBar(title: const Text('자주 묻는 질문')),
      body: RefreshIndicator(
        onRefresh: () async {
          await store.refresh();
          _maybeAutoloadMore();
        },
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // 0: 안내 문구
            if (index == 0) {
              return Center(
                child: Column(
                  children: const [
                    Text('자주 문의하시는 상담 내용을 모았습니다.'),
                    SizedBox(height: 4),
                    Text('해결되지 않는 문의는 1:1 문의나 챗봇을 이용해 주세요.'),
                  ],
                ),
              );
            }

            // 1: 검색 + 자동완성
            if (index == 1) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue tev) {
                    if (tev.text.isEmpty) return const Iterable<String>.empty();
                    return store.suggestions.where((s) => s.contains(tev.text));
                  },
                  onSelected: (val) => _searchCtrl.text = val,
                  fieldViewBuilder: (context, _i1, _i2, _i3) {
                    return TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      decoration: const InputDecoration(
                        hintText: '검색어를 입력하세요...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                ),
              );
            }

            // 2: 카테고리 칩
            if (index == 2) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: store.categories.map((cat) {
                    final selected = store.category == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) => store.onCategoryChanged(cat),
                    );
                  }).toList(),
                ),
              );
            }

            // 3: 테이블 헤더
            if (index == 3) {
              return Container(
                margin: const EdgeInsets.only(top: 12),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Row(
                  children: const [
                    SizedBox(
                        width: 60,
                        child: Text('글번호', textAlign: TextAlign.center)),
                    SizedBox(
                        width: 100,
                        child: Text('구분', textAlign: TextAlign.center)),
                    Expanded(child: Text('제목')),
                  ],
                ),
              );
            }

            // 마지막: 로딩/끝
            if (index == itemCount - 1) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: store.isLoading
                      ? const CircularProgressIndicator()
                      : store.isLast
                          ? const Text('더 이상 항목이 없습니다')
                          : const SizedBox.shrink(),
                ),
              );
            }

            // 나머지: 실제 FAQ 행들
            final faqIndex = index - headerCount;
            final faq = store.items[faqIndex];
            return _FaqRow(faq: faq);
          },
        ),
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  final Faq faq;
  const _FaqRow({required this.faq});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // 현재 스코프의 Api/Store 인스턴스를 상세 라우트에도 그대로 주입
        final api = context.read<FaqApi>();
        final store = context.read<FaqStore>();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiProvider(
              providers: [
                Provider<FaqApi>.value(value: api),
                ChangeNotifierProvider<FaqStore>.value(value: store),
              ],
              child: FaqDetailPage(faqId: faq.faqId, initial: faq),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(width: 0.3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text('${faq.faqId}', textAlign: TextAlign.center),
            ),
            SizedBox(
              width: 100,
              child: Text(faq.category ?? '', textAlign: TextAlign.center),
            ),
            Expanded(
              child: Text(
                faq.question ?? '',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
