import 'package:flutter/material.dart';
import 'package:reframe/service/review_service.dart';
import '../../model/review.dart';

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
  List<Review> _reviews = [];

  int _rating = 5; // ★ 기본 5점

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ReviewService.fetchReviews(widget.productId);
      if (!mounted) return;
      setState(() => _reviews = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('리뷰 불러오기 실패: $e')));
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    setState(() => _loading = true);
    try {
      await ReviewService.createReview(
        productId: widget.productId,
        content: content,
        rating: _rating, // ★ 함께 전송
      );
      _controller.clear();
      _focus.unfocus();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('리뷰가 등록되었습니다')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _starPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final idx = i + 1;
        final filled = idx <= _rating;
        return IconButton(
          iconSize: 28,
          onPressed: () => setState(() => _rating = idx),
          icon: Icon(filled ? Icons.star : Icons.star_border),
        );
      }),
    );
  }

  Widget _starRow(int? rating) {
    final r = (rating ?? 0).clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(i < r ? Icons.star : Icons.star_border, size: 16);
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.productName} 리뷰')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _starPicker(),
          ),
          Expanded(
            child: _reviews.isEmpty
                ? const Center(child: Text('아직 리뷰가 없습니다'))
                : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (_, i) {
                final r = _reviews[i];
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(r.authorName ?? '익명'),
                  subtitle: Text(r.content),
                  trailing: _starRow(r.rating), // ★ 별 표시
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: _reviews.length,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '리뷰를 작성하세요',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _loading
                      ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
