// lib/pages/my_reviews_page.dart
import 'package:flutter/material.dart';
import 'package:reframe/service/review_service.dart';
import 'package:reframe/model/review.dart';
import 'package:reframe/pages/review/review_page.dart';

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  late Future<List<MyReview>> _future;
  bool _loading = true;
  String? _error;
  List<MyReview> _items = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MyReview>> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ReviewService.fetchMyReviews();
      if (mounted) setState(() => _items = list);
      return list;
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
      rethrow;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  // 평균점수(소수1자리), 총개수
  double get _avg {
    if (_items.isEmpty) return 0;
    final sum = _items.fold<int>(0, (s, r) => s + (r.rating ?? 0));
    return sum / _items.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 리뷰'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 그라데이션 헤더
          const _GradientHeader(
            title: '내가 쓴 리뷰',
            subtitle: '상품별로 내가 남긴 평가와 후기를 한눈에 확인해요.',
          ),

          // 평균/총개수 요약 배너
          _SummaryBanner(avg: _avg, count: _items.length),

          // 목록
          Expanded(
            child: FutureBuilder<List<MyReview>>(
              future: _future,
              builder: (context, snap) {
                if (_loading && snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_error != null) {
                  return _ErrorView(message: '오류: $_error', onRetry: _reload);
                }
                if (_items.isEmpty) {
                  return _EmptyView(
                    onWrite: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('상품 상세에서 리뷰를 작성할 수 있어요.')),
                      );
                    },
                  );
                }
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final it = _items[i];
                      return _ReviewCard(
                        productName: it.productName,
                        rating: it.rating ?? 0,
                        content: it.content,
                        createdAtLabel: _relative(it.createdAt),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewPage(
                                productId: it.productId,
                                productName: it.productName,
                              ),
                            ),
                          );
                          _reload(); // 돌아오면 동기화
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 상대시간 표기 (초/밀리초/문자열/DateTime 대응)
  String _relative(dynamic v) {
    DateTime? dt;
    if (v is DateTime) dt = v;
    if (v is String) {
      try {
        dt = DateTime.parse(v);
      } catch (_) {}
    }
    if (v is int) {
      final isSec = v < 10 * 1000 * 1000 * 1000;
      dt = DateTime.fromMillisecondsSinceEpoch(isSec ? v * 1000 : v);
    }
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

/* ───────── Gradient Header ───────── */
class _GradientHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _GradientHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF2962FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('내가 쓴 리뷰',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text(
            '상품별로 내가 남긴 평가와 후기를 한눈에 확인해요.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }
}

/* ───────── Summary Banner (평균/총개수, 심플버전) ───────── */
class _SummaryBanner extends StatelessWidget {
  final double avg;
  final int count;
  const _SummaryBanner({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    final a = (avg.isNaN || avg.isInfinite) ? 0 : avg;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded, color: Color(0xFF304FFE)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 0
                  ? '표시할 리뷰가 없습니다'
                  : '평균 ★ ${a.toStringAsFixed(1)} · 총 $count개',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────── Review Card ───────── */
class _ReviewCard extends StatelessWidget {
  final String productName;
  final int rating; // 0~5
  final String content;
  final String createdAtLabel;
  final VoidCallback onTap;

  const _ReviewCard({
    required this.productName,
    required this.rating,
    required this.content,
    required this.createdAtLabel,
    required this.onTap,
  });

  static const _chipBg = Color(0xFFEFF4FF);
  static const _chipText = Color(0xFF1E40AF);
  static const _dateText = Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Chip(label: '평점 $rating점', bg: _chipBg, fg: _chipText),
                        const SizedBox(width: 8),
                        _StarRow(rating: rating),
                        const SizedBox(width: 8),
                        Text(
                          createdAtLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _dateText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 22, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────── Shared Chip ───────── */
class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Chip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style:
          TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/* ───────── Star Row ───────── */
class _StarRow extends StatelessWidget {
  final int rating; // 0~5
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            size: 14,
            color: Colors.amber,
          ),
        );
      }),
    );
  }
}

/* ───────── Empty / Error Views ───────── */
class _EmptyView extends StatelessWidget {
  final VoidCallback onWrite;
  const _EmptyView({required this.onWrite});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('아직 내가 작성한 리뷰가 없어요.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text('상품 상세 화면에서 리뷰를 작성해보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onWrite,
              icon: const Icon(Icons.rate_review_rounded),
              label: const Text('리뷰 작성 안내'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
