import 'dart:async';
import 'package:flutter/material.dart';
import 'package:reframe/service/review_service.dart';
import '../../model/review.dart';

const _brand = Color(0xFF304FFE);
const _badgeBg = Color(0xFFE8F5E9);
const _badgeFg = Color(0xFF2E7D32);

enum SortMode { latest, ratingHigh, ratingLow }

class ReviewPage extends StatefulWidget {
  final int productId;
  final String productName;
  final int presenceOthers;

  /// 로그인 사용자 정보(있으면 ‘내 리뷰’ 정확도↑)
  final String? currentUserId;
  final String? currentUserName;

  const ReviewPage({
    super.key,
    required this.productId,
    required this.productName,
    this.presenceOthers = 0,
    this.currentUserId,
    this.currentUserName,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  // 상태
  final _controller = TextEditingController();
  final _focus = FocusNode();

  bool _loading = false;
  bool _submitting = false;

  List<Review> _reviews = [];
  int _rating = 5;
  SortMode _sort = SortMode.latest;

  // 기본은 보이도록
  bool _hideMine = false;

  // 내가 보낸 내용 누적(재방문 시에도 인식)
  final Set<String> _submittedContents = <String>{};

  // 정렬 드롭다운 앵커
  final GlobalKey _sortBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------------- Data ----------------
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ReviewService.fetchReviews(widget.productId);
      if (!mounted) return;
      setState(() => _reviews = list);
    } catch (e) {
      if (!mounted) return;
      _toast('리뷰 불러오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      _toast('리뷰 내용을 입력해 주세요');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ReviewService.createReview(
        productId: widget.productId,
        content: content,
        rating: _rating,
      );
      _submittedContents.add(content); // 휴리스틱 누적
      _controller.clear();
      _focus.unfocus();
      await _load();
      if (!mounted) return;
      _toast('리뷰가 등록되었습니다');
      Navigator.of(context).maybePop(); // 바텀시트 닫기
    } catch (e) {
      if (!mounted) return;
      _toast('등록 실패: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- ‘내 리뷰’ 판정 ----------------
  String? _authorIdOf(Review r) {
    try {
      final v = (r as dynamic).authorId;
      if (v != null) return '$v';
    } catch (_) {}
    try {
      final v = (r as dynamic).userId;
      if (v != null) return '$v';
    } catch (_) {}
    try {
      final v = (r as dynamic).writerId;
      if (v != null) return '$v';
    } catch (_) {}
    return null;
  }

  bool _isMineFlagOf(Review r) {
    try {
      final v = (r as dynamic).isMine;
      if (v is bool) return v;
    } catch (_) {}
    try {
      final v = (r as dynamic).mine;
      if (v is bool) return v;
    } catch (_) {}
    return false;
  }

  String _norm(String? s) =>
      (s ?? '').replaceAll(RegExp(r'\s+'), '').toLowerCase();

  bool _isMine(Review r) {
    if (_isMineFlagOf(r)) return true; // 서버 플래그 우선

    final myId = widget.currentUserId?.trim();
    final rid = _authorIdOf(r)?.trim();
    final idHit = (myId != null &&
        myId.isNotEmpty &&
        rid != null &&
        rid.isNotEmpty &&
        myId == rid);

    final myName = widget.currentUserName;
    final nameHit = (myName != null && myName.trim().isNotEmpty)
        ? _norm(myName) == _norm(r.authorName)
        : false;

    final recentHit = _submittedContents.contains(r.content.trim());

    return idHit || nameHit || recentHit;
  }

  // ---------------- 정렬/유틸 ----------------
  double get _avg {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<int>(0, (s, r) => s + (r.rating ?? 0));
    return sum / _reviews.length;
  }

  List<int> get _dist {
    final d = List<int>.filled(6, 0); // 0~5
    for (final r in _reviews) {
      final rr = (r.rating ?? 0).clamp(0, 5);
      d[rr] += 1;
    }
    return d;
  }

  List<Review> get _visibleSorted {
    final base = _hideMine
        ? _reviews.where((r) => !_isMine(r)).toList()
        : List<Review>.from(_reviews);

    int cmpDate(Review a, Review b) {
      final da =
          _toDateTime(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db =
          _toDateTime(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    }

    switch (_sort) {
      case SortMode.latest:
        base.sort(cmpDate);
        break;
      case SortMode.ratingHigh:
        base.sort((a, b) {
          final r = (b.rating ?? 0).compareTo(a.rating ?? 0);
          return r != 0 ? r : cmpDate(a, b);
        });
        break;
      case SortMode.ratingLow:
        base.sort((a, b) {
          final r = (a.rating ?? 0).compareTo(b.rating ?? 0);
          return r != 0 ? r : cmpDate(a, b);
        });
        break;
    }
    return base;
  }

  DateTime? _toDateTime(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    if (v is int) {
      final isSec = v < 10 * 1000 * 1000 * 1000;
      return DateTime.fromMillisecondsSinceEpoch(isSec ? v * 1000 : v);
    }
    return null;
  }

  String _relative(dynamic v) {
    final dt = _toDateTime(v);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  // ---------------- 상단 배너 ----------------
  Widget _presenceBanner(int others) {
    if (others <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        children: const [
          Icon(Icons.visibility, color: Color(0xFF1565C0)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '현재 다른 사용자가 리뷰를 보고 있습니다.',
              style: TextStyle(
                  color: Color(0xFF0D47A1), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 공통 위젯: 둥근 분포 막대 ----------------
  Widget _roundedBar(double ratio) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final fill = (ratio.clamp(0, 1.0)) * w;
        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: fill,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999), // 끝단도 둥글게
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------- 공통 위젯: 부분 채워지는 별 ----------------
  Widget _partialStars(double rating, {double size = 20}) {
    final factor = (rating.clamp(0, 5)) / 5.0;
    return SizedBox(
      height: size,
      child: Stack(
        children: [
          // 바탕: 회색 테두리 별 5개
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
                5,
                (_) => Icon(Icons.star_border_rounded,
                    size: size, color: Colors.white.withOpacity(.7))),
          ),
          // 위: 노란 별 5개를 왼쪽에서 factor 만큼만 보여줌
          ClipRect(
            clipBehavior: Clip.hardEdge,
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: factor, // 0.0 ~ 1.0
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    5,
                    (_) => const Icon(Icons.star_rounded,
                        size: 20, color: Colors.amber)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 헤더 ----------------
  Widget _header() {
    final total = _reviews.length;
    final dist = _dist;
    double ratio(int star) => total == 0 ? 0 : dist[star] / total;

    // 오른쪽: ‘둥근 막대 + 숫자’ (간격 좁게)
    Widget ratioRow(int star) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text('${star}점',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 6),
            Expanded(child: _roundedBar(ratio(star))),
            const SizedBox(width: 0), // ← 요청 2: 숫자와 더 촘촘
            SizedBox(
              width: 24,
              child: Text('${dist[star]}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.95),
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), _brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // 좌측: 평균점수 / 부분별 / (총개수)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _avg.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0, // 들뜸 방지
                  ),
                ),
                const SizedBox(height: 2), // ← 요청 3: 숫자-별 간 여백 최소화
                _partialStars(_avg, size: 20), // ← 요청 4: 4.3이면 4.3개 채움
                const SizedBox(height: 4),
                Text('(${total})',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.9),
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 180,
            child: Column(
              children: [
                ratioRow(5),
                ratioRow(4),
                ratioRow(3),
                ratioRow(2),
                ratioRow(1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 컨트롤(정렬/숨기기/작성) ----------------
  Widget _controlRow() {
    String label(SortMode m) => switch (m) {
          SortMode.latest => '최신순',
          SortMode.ratingHigh => '별점 높은 순',
          SortMode.ratingLow => '별점 낮은 순',
        };

    final textBtn = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      foregroundColor: Colors.black87,
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          // 정렬 드롭다운(버튼 바로 아래)
          Builder(
            builder: (btnCtx) {
              return TextButton.icon(
                key: _sortBtnKey,
                onPressed: () => _openSortMenu(btnCtx),
                icon: const Icon(Icons.sort, size: 18),
                label: Text(label(_sort)),
                style: textBtn,
              );
            },
          ),
          const SizedBox(width: 4),
          // 내 리뷰 숨기기
          TextButton.icon(
            onPressed: () => setState(() => _hideMine = !_hideMine),
            icon: Icon(_hideMine ? Icons.visibility_off : Icons.visibility,
                size: 18),
            label: const Text('내 리뷰 숨기기'),
            style: textBtn.copyWith(
              foregroundColor: WidgetStatePropertyAll(
                  _hideMine ? Colors.black87 : Colors.black87),
            ),
          ),
          const Spacer(),
          // 작성은 TextButton 유지
          TextButton(
            onPressed: _openComposerSheet,
            style: TextButton.styleFrom(
              foregroundColor: _brand,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('리뷰 작성하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSortMenu(BuildContext anchorContext) async {
    final renderBox = anchorContext.findRenderObject() as RenderBox?;
    final overlay = Navigator.of(anchorContext)
        .overlay!
        .context
        .findRenderObject() as RenderBox;
    if (renderBox == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final v = await showMenu<SortMode>(
      context: anchorContext,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: const [
        PopupMenuItem(value: SortMode.latest, child: Text('최신순')),
        PopupMenuItem(value: SortMode.ratingHigh, child: Text('별점 높은 순')),
        PopupMenuItem(value: SortMode.ratingLow, child: Text('별점 낮은 순')),
      ],
    );
    if (v != null) setState(() => _sort = v);
  }

  // ---------------- 바텀시트 작성창 ----------------
  void _openComposerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        // 바텀시트 내부에서만 즉시 반영될 로컬 상태
        int localRating = _rating;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: StatefulBuilder(
            // ← ★ 바텀시트 내부 리빌드 전용
            builder: (ctx, setModalState) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 2),
                      Text('$localRating점',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),

                      // 별점 선택: setModalState로 즉시 갱신
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final idx = i + 1;
                          final active = idx <= localRating;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkResponse(
                              onTap: () =>
                                  setModalState(() => localRating = idx),
                              // ↓↓↓ 번짐(리플/하이라이트/호버) 제거
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              radius: 26,
                              child: Icon(
                                active
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 30,
                                color: active ? Colors.amber : Colors.grey,
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        focusNode: _focus,
                        minLines: 4,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: '리뷰를 작성하세요',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: _brand, width: 1.5),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _submitting
                              ? null
                              : () async {
                                  // 부모 상태에도 최종 반영
                                  setState(() => _rating = localRating);
                                  await _submit();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('등록'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------------- 리뷰 아이템 ----------------
  Widget _reviewItem(Review r) {
    final name = (r.authorName ?? '익명').trim();
    final initial = name.isNotEmpty ? name[0] : '익';
    final created = _relative(r.createdAt);
    final mine = _isMine(r);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _brand.withOpacity(.12),
                child: Text(initial,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (i) {
                            final filled = i < (r.rating ?? 0);
                            return Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 14,
                              color: Colors.amber,
                            );
                          }),
                        ),
                        if (mine) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _badgeBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '내 리뷰',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _badgeFg,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          created,
                          style: TextStyle(
                              color: Colors.black54.withOpacity(.9),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            r.content,
            style: const TextStyle(fontSize: 15, height: 1.45),
          ),
        ],
      ),
    );
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.productName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          _presenceBanner(widget.presenceOthers),
          _header(),
          _controlRow(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              triggerMode: RefreshIndicatorTriggerMode.onEdge,
              notificationPredicate: (n) => n.depth == 0, // ← 중복 방지 핵심
              child: _loading
                  ? const Center(child: SizedBox())
                  : (_visibleSorted.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          children: const [
                            SizedBox(height: 160),
                            Center(child: Text('아직 리뷰가 없습니다')),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          itemCount: _visibleSorted.length,
                          itemBuilder: (_, i) => _reviewItem(_visibleSorted[i]),
                        )),
            ),
          ),
        ],
      ),
    );
  }
}
