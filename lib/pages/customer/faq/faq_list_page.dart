import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../store/faq_store.dart';
import '../../../model/faq.dart';
import '../../../service/faq_api.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<FaqStore>().init();
      _maybeAutoloadMore();
    });

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        context.read<FaqStore>().loadNext();
      }
    });

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

  Future<void> _maybeAutoloadMore() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (!_scroll.hasClients) return;

    final store = context.read<FaqStore>();
    int safety = 3;
    while (_scroll.position.maxScrollExtent <= 0 &&
        !(store.isLast) &&
        !(store.isLoading) &&
        safety-- > 0) {
      await store.loadNext();
      await Future.delayed(const Duration(milliseconds: 30));
      if (!_scroll.hasClients) break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FaqStore>();
    final cs = Theme.of(context).colorScheme;

    final items = store.items ?? <Faq>[];
    final currentCategory = store.category ?? '';
    final currentSearch = store.search ?? '';

    if (_searchCtrl.text != currentSearch) {
      _searchCtrl.text = currentSearch;
      _searchCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchCtrl.text.length));
    }

    const headerCount = 4;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom + 8;

    final chips = const <_ChipItem>[
      _ChipItem(label: '전체', value: ''),
      _ChipItem(label: '예적금', value: '예금'),
      _ChipItem(label: '기타', value: '기타'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('자주 묻는 질문'), centerTitle: true),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await store.refresh();
            _maybeAutoloadMore();
          },
          child: ListView.builder(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPad),
            itemCount: headerCount + items.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _Header(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                );
              }

              if (index == 1) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      const Text(
                        '카테고리',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InlineChips(
                          items: chips,
                          selectedValue: currentCategory,
                          onSelected: (value) =>
                              store.onCategoryChanged(value ?? ''),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (index == 2) return const SizedBox.shrink();

              if (index == 3) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    '질문 TOP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onBackground.withOpacity(.9),
                    ),
                  ),
                );
              }

              if (index == headerCount && items.isEmpty && !store.isLoading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      '결과가 없습니다.',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }

              final lastIndex = headerCount + items.length;
              if (index == lastIndex) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: store.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              }

              final faqIndex = index - headerCount;
              final faq = items[faqIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FaqRow(faq: faq, onOpen: _openFaqDialog),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── 중앙 모달 다이얼로그 열기 (현재 Provider 인스턴스 주입) ────────────────
  void _openFaqDialog(BuildContext context, Faq faq) {
    final store = context.read<FaqStore>();
    final api = store.api; // 또는 context.read<FaqApi>();

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<FaqStore>.value(value: store),
          Provider<FaqApi>.value(value: api),
        ],
        child: _FaqQADialog(faqId: faq.faqId, initial: faq),
      ),
    );
  }
}

/* ───────── 헤더: 보라+파랑 그라데이션, 검색 버튼 테두리 제거 ───────── */
class _Header extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const _Header({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 84),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFF2962FF)], // 밝은 보라+파랑
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Transform.translate(
            offset: const Offset(0, 20),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'FAQ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '해결되지 않는 문의는 1:1 문의나 챗봇을 이용해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: -28,
          child: _SearchBar(controller: controller, focusNode: focusNode),
        ),
      ],
    ).paddingOnly(bottom: 40);
  }
}

/* ───────── 검색바 ───────── */
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const _SearchBar({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2962FF);
    return Material(
      elevation: 8,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 52,
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: '키워드를 검색해 보세요.',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: blue),
              onPressed: () => FocusScope.of(context).unfocus(),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────── 카테고리 칩 ───────── */
class _ChipItem {
  final String label;
  final String value;
  const _ChipItem({required this.label, required this.value});
}

class _InlineChips extends StatelessWidget {
  final List<_ChipItem> items;
  final String selectedValue;
  final ValueChanged<String?> onSelected;

  const _InlineChips({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  static const _baseGrey = Color(0xFFF1F3F5);
  static const _selectedGrey = Color(0xFFD0D4DA);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((it) {
          final isSel = selectedValue == it.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelected(it.value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? _selectedGrey : _baseGrey,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  it.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/* ───────── FAQ 행 (onTap → 중앙 모달) ───────── */
class _FaqRow extends StatelessWidget {
  final Faq faq;
  final void Function(BuildContext, Faq) onOpen;
  const _FaqRow({required this.faq, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onOpen(context, faq),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceVariant.withOpacity(.8),
              ),
              child: Text(
                'Q',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface.withOpacity(.55),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                faq.question ?? '제목 없음',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────── 중앙 Q/A 다이얼로그 (상단 여백↑, X는 위로, 우측여백 제거) ───────── */
class _FaqQADialog extends StatefulWidget {
  final int faqId;
  final Faq? initial;
  const _FaqQADialog({required this.faqId, this.initial});

  @override
  State<_FaqQADialog> createState() => _FaqQADialogState();
}

class _FaqQADialogState extends State<_FaqQADialog> {
  Future<Faq>? _future;
  late FaqApi _api;
  bool _bound = false;

  // 파스텔 블루 팔레트
  static const _chipBlue = Color(0xFF81D4FA); // 카테고리 칩
  static const _labelBlue = Color(0xFF2962FF); // 'A' 라벨
  static const _bubbleBlue = Color(0xFFEAF4FF); // 답변 말풍선 배경

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bound) return;
    _api = context.read<FaqApi>(); // 또는 context.read<FaqStore>().api
    _future = _api.fetchFaqDetail(widget.faqId);
    _bound = true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 280,
          maxWidth: 560,
          maxHeight: 560, // 길면 내부 스크롤
        ),
        child: FutureBuilder<Faq>(
          future: _future,
          builder: (context, snap) {
            final isLoading =
                snap.connectionState != ConnectionState.done && !snap.hasError;
            final faq = snap.data ?? widget.initial;

            return Stack(
              children: [
                // 상단 여백을 넉넉히 주고(텍스트 위로 공간 확보), 좌우는 동일 패딩
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      20, 36, 20, 30), // ▲ top 36, right 20 (reserve 제거)
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1) Q + (질문 + 배지) : 배지는 질문 텍스트 시작선에 정확히 맞춤
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Q',
                              style: TextStyle(
                                fontSize: 20, // ← Q 라벨 크기
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (faq?.question ?? '').trim().isNotEmpty
                                        ? (faq?.question ?? '')
                                        : (isLoading ? '불러오는 중…' : '제목 없음'),
                                    style: const TextStyle(
                                      fontSize: 18, // ← 질문 폰트 크기
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                    softWrap: true,
                                    overflow: TextOverflow.visible, // 잘림 방지
                                  ),
                                  const SizedBox(height: 8),
                                  if ((faq?.category ?? '').isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _chipBlue,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 4),
                                        ],
                                      ),
                                      child: Text(
                                        faq!.category!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 2) A 라벨을 Q와 같은 세로선(왼쪽)에 두고, 오른쪽에 답변 말풍선
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'A',
                              style: TextStyle(
                                color: _labelBlue,
                                fontSize: 18, // ← A 라벨 크기
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                decoration: BoxDecoration(
                                  color: _bubbleBlue,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: isLoading && (faq?.answer ?? '').isEmpty
                                    ? const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8),
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        (faq?.answer ?? '').trim().isNotEmpty
                                            ? (faq?.answer ?? '')
                                            : '등록된 답변이 없습니다.',
                                        style: const TextStyle(
                                          fontSize: 15.5, // ← 답변 폰트 크기
                                          height: 1.55,
                                          color: Color(0xFF1F2937),
                                        ),
                                        softWrap: true,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // X 버튼을 "본문 위쪽(헤더 영역)"으로 올려 겹침 이슈 제거
                Positioned(
                  top: 6, // 텍스트 위쪽
                  right: 6,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87),
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ───────── 헬퍼 ───────── */
extension _Below on Widget {
  Widget paddingOnly(
      {double left = 0, double top = 0, double right = 0, double bottom = 0}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(left, top, right, bottom),
      child: this,
    );
  }
}
