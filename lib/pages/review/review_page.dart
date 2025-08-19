import 'dart:async';
import 'package:flutter/material.dart';
import 'package:reframe/service/review_service.dart';
import '../../model/review.dart';

const _brand = Color(0xFF304FFE);

enum SortMode { latest, ratingHigh, ratingLow }

class ReviewPage extends StatefulWidget {
  final int productId;
  final String productName;
  const ReviewPage({super.key, required this.productId, required this.productName});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  bool _loading = false;
  bool _submitting = false;
  List<Review> _reviews = [];

  int _rating = 5; // 작성 기본 별점
  SortMode _sort = SortMode.latest;

  // 내가 쓴 리뷰 숨기기(기본 on)
  bool _hideMine = true;

  // 방금 내가 보낸 내용(휴리스틱용)
  String? _lastSubmittedContent;

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
      _lastSubmittedContent = content; // 방금 쓴 리뷰 메모
      _controller.clear();
      _focus.unfocus();
      await _load();
      if (!mounted) return;
      _toast('리뷰가 등록되었습니다');
    } catch (e) {
      if (!mounted) return;
      _toast('등록 실패: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------------- Helpers ----------------
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // 현재 로그인 유저 이름을 알 수 있으면 여기에 연결(없으면 null 유지)
  String? get _myName => null;

  bool _isMine(Review r) {
    // 1) 이름이 있으면 이름 비교
    final my = _myName?.trim();
    if (my != null && my.isNotEmpty && (r.authorName ?? '').trim() == my) return true;
    // 2) 방금 제출한 내용과 동일하면 내 것으로 간주(즉시 반영용 휴리스틱)
    if (_lastSubmittedContent != null &&
        r.content.trim() == _lastSubmittedContent) return true;
    return false;
  }

  double get _avg {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<int>(0, (s, r) => s + (r.rating ?? 0));
    return sum / _reviews.length;
  }

  List<int> get _dist {
    final d = List<int>.filled(6, 0); // 0~5 (0은 미사용)
    for (final r in _reviews) {
      final rr = (r.rating ?? 0).clamp(0, 5);
      d[rr] += 1;
    }
    return d;
  }

  List<Review> get _visibleSorted {
    // 1) 내 리뷰 숨김
    final base = _hideMine ? _reviews.where((r) => !_isMine(r)).toList()
        : List<Review>.from(_reviews);

    // 2) 정렬
    int cmpDate(Review a, Review b) {
      final da = _toDateTime(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = _toDateTime(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da); // 최신순(desc)
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

  Widget _starRow(int rating, {double size = 16, Color color = Colors.amber}) {
    final r = rating.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(i < r ? Icons.star : Icons.star_border, size: size, color: color);
      }),
    );
  }

  Widget _starPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final idx = i + 1;
        final active = idx <= _rating;
        return IconButton(
          tooltip: '$idx점',
          onPressed: () => setState(() => _rating = idx),
          iconSize: 30,
          icon: Icon(active ? Icons.star : Icons.star_border,
              color: active ? Colors.amber : Colors.grey),
        );
      }),
    );
  }

  // ---------------- Widgets ----------------
  Widget _header() {
    final dist = _dist;
    final total = _reviews.length;
    double ratio(int star) => total == 0 ? 0 : dist[star] / total;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F8BFF), _brand], // 살짝 더 밝게
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // 평균
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_avg.toStringAsFixed(1)}점',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    )),
                const SizedBox(height: 4),
                _starRow(_avg.round(), size: 20, color: Colors.white),
                const SizedBox(height: 6),
                Text('리뷰 $total개',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .9),
                    )),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 분포
          SizedBox(
            width: 140,
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        child: Text('$star★',
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: ratio(star),
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: .25),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 24,
                        child: Text('${dist[star]}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuButton _sortMenu() {
    String label(SortMode m) => switch (m) {
      SortMode.latest => '최신순',
      SortMode.ratingHigh => '별점 높은 순',
      SortMode.ratingLow => '별점 낮은 순',
    };

    IconData mark(SortMode m) =>
        _sort == m ? Icons.radio_button_checked : Icons.radio_button_unchecked;

    return PopupMenuButton(
      tooltip: '정렬/옵션',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value is SortMode) {
          setState(() => _sort = value);
        } else if (value is String && value == 'toggle_hide_mine') {
          setState(() => _hideMine = !_hideMine);
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: SortMode.latest,
          child: Row(
            children: [
              Icon(mark(SortMode.latest), size: 18, color: _brand),
              const SizedBox(width: 8),
              const Text('최신순', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem(
          value: SortMode.ratingHigh,
          child: Row(
            children: [
              Icon(mark(SortMode.ratingHigh), size: 18, color: _brand),
              const SizedBox(width: 8),
              const Text('별점 높은 순', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem(
          value: SortMode.ratingLow,
          child: Row(
            children: [
              Icon(mark(SortMode.ratingLow), size: 18, color: _brand),
              const SizedBox(width: 8),
              const Text('별점 낮은 순', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          value: 'toggle_hide_mine',
          checked: _hideMine,
          child: const Text('내 리뷰 숨기기'),
        ),
      ],
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black12.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black26.withValues(alpha: .3)),
        ),
        child: Row(
          children: const [
            Icon(Icons.sort, size: 18),
            SizedBox(width: 6),
            Text('정렬', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(Review r) {
    final name = (r.authorName ?? '익명').trim();
    final initial = name.isNotEmpty ? name[0] : '익'; // 한 글자 아바타
    final created = _relative(r.createdAt);

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _brand.withValues(alpha: .15),
              child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름 + 별점
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if ((r.rating ?? 0) > 0)
                        _starRow(r.rating ?? 0, size: 14, color: Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    created,
                    style: TextStyle(color: Colors.black54.withValues(alpha: .9), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    r.content,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black12.withValues(alpha: .06))),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _starPicker(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '리뷰를 작성하세요',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _submitting
                    ? const SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Material(
                  color: _brand,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _submit,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.productName} 리뷰'),
        centerTitle: true,
        elevation: 0.5,
        actions: [
          _sortMenu(), // ← 오른쪽 액션에 정렬/옵션
        ],
      ),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _visibleSorted.isEmpty
                  ? const Center(child: Text('아직 리뷰가 없습니다'))
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: _visibleSorted.length,
                itemBuilder: (_, i) => _reviewCard(_visibleSorted[i]),
              ),
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }
}
