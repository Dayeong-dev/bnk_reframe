// lib/pages/review/review_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:reframe/service/review_service.dart';
import 'package:reframe/model/review.dart';

// 실시간(WS)
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart' as ws_io;
import 'package:web_socket_channel/status.dart' as ws_status;

// 엔드포인트
import 'package:reframe/env/app_endpoints.dart';

// 내가 방금 쓴 리뷰 억제용(간단 버퍼)
import 'package:reframe/utils/recent_my_review.dart';

const _brand = Color(0xFF304FFE);
const _badgeBg = Color(0xFFF5F5F5);
const _badgeFg = Color(0xFF424242);

// 화면 공통 좌우 패딩
const double _screenHPad = 20.0;
// 오른쪽 끝열 가이드(배너보다 살짝 안쪽)
const double _rightGuide = 15.0;

enum SortMode { latest, ratingHigh, ratingLow }

class ReviewPage extends StatefulWidget {
  final int productId;
  final String productName;
  final int presenceOthers;

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

  bool _hideMine = false;
  final Set<String> _submittedContents = <String>{};

  // 정렬 드롭다운 앵커
  final GlobalKey _sortBtnKey = GlobalKey();

  // === 실시간(WS) ===
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  int _presenceOthers = 0;

  @override
  void initState() {
    super.initState();
    _presenceOthers = max(widget.presenceOthers, 0);
    _load();
    _connectWs();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _wsSub?.cancel();
    _ws?.sink.close(ws_status.goingAway);
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
      _toast('리뷰 내용을 입력해 주세요.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ReviewService.createReview(
        productId: widget.productId,
        content: content,
        rating: _rating,
      );
      _submittedContents.add(content);
      _controller.clear();
      _focus.unfocus();
      await _load();
      if (!mounted) return;
      _toast('리뷰가 등록되었습니다.');
      Navigator.of(context).maybePop();
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
  bool? _mineFlag(Review r) => r.mine;
  String? _authorIdOf(Review r) => r.authorId;

  bool _isMine(Review r) {
    final flag = _mineFlag(r);
    if (flag != null) return flag;

    final myId = widget.currentUserId?.trim();
    final authorId = _authorIdOf(r)?.trim();
    if (myId != null &&
        myId.isNotEmpty &&
        authorId != null &&
        authorId.isNotEmpty &&
        myId == authorId) {
      return true;
    }
    // 마지막 보조: 방금 올린 동일 내용
    return _submittedContents.contains(r.content.trim());
  }

  // ---------------- 정렬/통계 ----------------
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

  // ---------------- 실시간(WS) ----------------
  void _connectWs() {
    final reviewTopic = 'product.${widget.productId}.reviews';
    final presenceTopic = '$reviewTopic.presence';
    final wsUrl = Uri.parse('${AppEndpoints.wsBase}?topic=$reviewTopic');

    try {
      _ws = ws_io.IOWebSocketChannel.connect(wsUrl.toString());

      _ws!.sink.add(jsonEncode({
        "op": "subscribe",
        "topics": [reviewTopic, presenceTopic],
      }));

      _wsSub = _ws!.stream.listen((raw) {
        try {
          final text = raw is String ? raw : raw.toString();
          final Map<String, dynamic> msg = jsonDecode(text);
          final type = msg['type'] as String?;

          if (type == 'presence') {
            final n = (msg['count'] as num?)?.toInt() ?? 0;
            if (mounted) setState(() => _presenceOthers = max(n - 1, 0));
            return;
          }

          if (type == 'review_created') {
            final snippet =
            _normalizeSnippet((msg['contentSnippet'] as String?) ?? '');
            final rating = (msg['rating'] as num?)?.toInt() ?? 0;

            final suppress = RecentMyReviewBuffer.I.shouldSuppress(
              productId: widget.productId,
              snippetFromServer: snippet,
              rating: rating,
            );
            if (suppress) return;

            _load();
            return;
          }
        } catch (_) {
          // ping 등 무시
        }
      });
    } catch (_) {
      // 연결 실패 무시
    }
  }

  String _normalizeSnippet(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.replaceAll('...', '…');
  }

  // ---------------- 상단 배너 ----------------
  Widget _presenceBanner(int others) {
    if (others <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(_screenHPad, 12, _screenHPad, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility, color: Color(0xFF1565C0)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '현재 다른 사용자가 리뷰를 보고 있습니다.',
              style: TextStyle(
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 공통 위젯 ----------------
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
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _partialStars(double rating, {double size = 20}) {
    final factor = (rating.clamp(0, 5)) / 5.0;
    return SizedBox(
      height: size,
      child: Stack(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
                  (_) => Icon(
                Icons.star_border_rounded,
                size: size,
                color: Colors.white.withOpacity(.7),
              ),
            ),
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: factor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                      (_) => const Icon(Icons.star_rounded,
                      size: 20, color: Colors.amber),
                ),
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

    Widget ratioRow(int star) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '${star}점',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: _roundedBar(ratio(star))),
            const SizedBox(width: 0),
            SizedBox(
              width: 24,
              child: Text(
                '${dist[star]}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white.withOpacity(.95),
                  fontWeight: FontWeight.w700,
                ),
              ),
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
      margin: const EdgeInsets.fromLTRB(_screenHPad, 8, _screenHPad, 8),
      child: Row(
        children: [
          // 좌측: 평균/별/총개수
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
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                _partialStars(_avg, size: 20),
                const SizedBox(height: 4),
                Text(
                  '($total)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
    String label(SortMode m) {
      if (m == SortMode.latest) return '최신순';
      if (m == SortMode.ratingHigh) return '별점 높은 순';
      return '별점 낮은 순';
    }

    final textBtnBase = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      foregroundColor: Colors.black87,
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(_screenHPad, 0, _screenHPad, 6),
      child: Row(
        children: [
          Builder(
            builder: (btnCtx) {
              return TextButton.icon(
                key: _sortBtnKey,
                onPressed: () => _openSortMenu(btnCtx),
                icon: const Icon(Icons.sort, size: 18),
                label: Text(label(_sort)),
                style: textBtnBase.copyWith(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8),
                  ),
                  minimumSize: WidgetStateProperty.all(const Size(0, 0)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () => setState(() => _hideMine = !_hideMine),
            icon:
            Icon(_hideMine ? Icons.visibility_off : Icons.visibility, size: 18),
            label: const Text('내 리뷰 숨기기'),
            style: textBtnBase,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: _rightGuide),
            child: TextButton(
              onPressed: _openComposerSheet,
              style: TextButton.styleFrom(
                foregroundColor: _brand,
                padding:
                const EdgeInsets.only(left: 10, right: 0, top: 10, bottom: 10),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: const Text('리뷰 작성하기'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSortMenu(BuildContext anchorContext) async {
    final renderBox = anchorContext.findRenderObject() as RenderBox?;
    final overlay =
    Navigator.of(anchorContext).overlay!.context.findRenderObject()
    as RenderBox;
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        int localRating = _rating;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        _screenHPad, 16, _screenHPad, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 상품 제목 (점수 라벨 없음)
                        Text(
                          widget.productName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 별점만 표시
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final idx = i + 1;
                            final active = idx <= localRating;
                            return Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 3),
                              child: InkResponse(
                                onTap: () =>
                                    setModalState(() => localRating = idx),
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
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
                            hintText: '리뷰를 작성하세요.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide:
                              BorderSide(color: _brand, width: 1.5),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _submitting
                                ? null
                                : () async {
                              setState(() => _rating = localRating);
                              await _submit();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
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
          ),
        );
      },
    );
  }

  // ---------------- 수정 바텀시트 ----------------
  void _openEditSheet(Review r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        int localRating = r.rating ?? 5;
        final editController = TextEditingController(text: r.content);
        final editFocus = FocusNode();

        bool submitting = false;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                Future<void> doUpdate() async {
                  final newContent = editController.text.trim();
                  if (newContent.isEmpty) {
                    _toast('리뷰 내용을 입력해 주세요');
                    return;
                  }
                  setModalState(() => submitting = true);
                  try {
                    await ReviewService.updateReview(
                      reviewId: r.id,
                      content: newContent,
                      rating: localRating,
                    );
                    // 낙관적 업데이트
                    final idx = _reviews.indexWhere((x) => x.id == r.id);
                    if (idx != -1) {
                      _reviews[idx] = Review(
                        id: r.id,
                        productId: r.productId,
                        content: newContent,
                        rating: localRating,
                        authorName: r.authorName,
                        createdAt: r.createdAt,
                        authorId: r.authorId,
                        mine: r.mine,
                      );
                    }
                    if (mounted) setState(() {});
                    if (mounted) Navigator.of(context).maybePop();
                    _toast('수정되었습니다');
                  } catch (e) {
                    _toast('수정 실패: $e');
                  } finally {
                    setModalState(() => submitting = false);
                  }
                }

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        _screenHPad, 16, _screenHPad, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 상품 제목 (작성 모달과 동일)
                        Text(
                          widget.productName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 별점만 표시 (점수 라벨 없음)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final idx = i + 1;
                            final active = idx <= localRating;
                            return Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 3),
                              child: InkResponse(
                                onTap: () =>
                                    setModalState(() => localRating = idx),
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
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
                          controller: editController,
                          focusNode: editFocus,
                          minLines: 4,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: '리뷰를 수정하세요',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide:
                              BorderSide(color: _brand, width: 1.5),
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
                            onPressed: submitting ? null : doUpdate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: submitting
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                                : const Text('수정 완료'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ---------------- 삭제 확인 다이얼로그 ----------------
  Future<void> _confirmDelete(Review r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        title: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, color: _brand, size: 20),
            SizedBox(width: 8),
            Text(
              '리뷰 삭제',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15, // ↓ 부담 줄이기
              ),
            ),
          ],
        ),
        content: const Text(
          '정말 삭제하시겠어요?',
          style: TextStyle(color: Colors.black87, fontSize: 14),
        ),
        actions: [
          // 테두리 없는 취소 버튼
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('취소'),
          ),
          // 브랜드 컬러 삭제 버튼
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ReviewService.deleteReview(r.id);
      _reviews.removeWhere((x) => x.id == r.id);
      if (mounted) setState(() {});
      _toast('삭제되었습니다');
    } catch (e) {
      _toast('삭제 실패: $e');
    }
  }

  // ---------------- 리뷰 아이템 ----------------
  Widget _reviewItem(Review r) {
    final name = (r.authorName ?? '익명').trim();
    final initial = name.isNotEmpty ? name[0] : '익';
    final created = _relative(r.createdAt);
    final mine = _isMine(r);

    // 이름 옆 작은 버튼: 오른쪽 패딩 0(끝열 맞춤)
    final smallBtn = TextButton.styleFrom(
      padding: const EdgeInsets.only(left: 8, right: 0, top: 4, bottom: 4),
      minimumSize: const Size(40, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: _brand,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(_screenHPad, 10, _screenHPad, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 헤더(아바타/이름/버튼/시간)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: _brand.withOpacity(.12),
                  child: Text(initial,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 + [수정][삭제]
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                        if (mine) ...[
                          TextButton(
                            onPressed: () => _openEditSheet(r),
                            style: smallBtn,
                            child: const Text('수정'),
                          ),
                          TextButton(
                            onPressed: () => _confirmDelete(r),
                            style: smallBtn,
                            child: const Text('삭제'),
                          ),
                        ],
                        // 리뷰 아이템의 오른쪽 끝 가이드 확보
                        const SizedBox(width: _rightGuide),
                      ],
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
                        // 시간(예: 2일 전)도 같은 끝 가이드에 맞춤
                        Padding(
                          padding: const EdgeInsets.only(right: _rightGuide),
                          child: Text(
                            created,
                            style: TextStyle(
                              color: Colors.black54.withOpacity(.9),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 본문은 아바타 하단부터 시작: 36(아바타) + 12(간격) = 48 들여쓰기
          const Padding(
            padding: EdgeInsets.only(left: 48),
            child: _ReviewContent(),
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
      ),
      body: Column(
        children: [
          _presenceBanner(_presenceOthers),
          _header(),
          _controlRow(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              triggerMode: RefreshIndicatorTriggerMode.onEdge,
              notificationPredicate: (n) => n.depth == 0,
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
                itemBuilder: (_, i) => _ReviewItemScope(
                  content: _visibleSorted[i].content,
                  child: _reviewItem(_visibleSorted[i]),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

/// 본문 텍스트 전달용 Scope
class _ReviewItemScope extends InheritedWidget {
  final String content;
  const _ReviewItemScope({
    required this.content,
    required super.child,
  });
  @override
  bool updateShouldNotify(covariant _ReviewItemScope old) =>
      old.content != content;
}

/// 본문 위젯(스타일 고정 + 들여쓰기만 위에서 제어)
class _ReviewContent extends StatelessWidget {
  const _ReviewContent();
  @override
  Widget build(BuildContext context) {
    final scope =
    context.dependOnInheritedWidgetOfExactType<_ReviewItemScope>();
    final text = scope?.content ?? '';
    return Text(
      text,
      style: const TextStyle(fontSize: 15, height: 1.45),
    );
  }
}
