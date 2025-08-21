import 'package:flutter/material.dart';
import 'qna_api_service.dart';
import 'qna_model.dart';
import 'qna_form_page.dart';

class QnaDetailPage extends StatefulWidget {
  final QnaApiService api;
  final int qnaId;
  const QnaDetailPage({super.key, required this.api, required this.qnaId});

  @override
  State<QnaDetailPage> createState() => _QnaDetailPageState();
}

class _QnaDetailPageState extends State<QnaDetailPage> {
  Qna? _qna;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = await widget.api.fetchDetail(widget.qnaId);
      if (mounted) setState(() => _qna = q);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 문의를 삭제하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.delete(widget.qnaId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _qna;
    return Scaffold(
      appBar: AppBar(
        title: const Text('문의 상세'),
        actions: [
          if (q != null && (q.answer == null || q.answer!.isEmpty))
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final saved = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QnaFormPage(
                      api: widget.api,
                      qnaId: q.qnaId,
                      initialCategory: q.category,
                      initialTitle: q.title,
                      initialContent: q.content,
                    ),
                  ),
                );
                if (saved == true) _load();
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _delete,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('오류: $_error'))
          : q == null
          ? const Center(child: Text('데이터 없음'))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(q.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('${q.category} · ${q.status}'),
            const Divider(height: 24),
            Text(q.content),
            const SizedBox(height: 24),
            const Divider(),
            Text('답변', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(q.answer?.isNotEmpty == true ? q.answer! : '답변 대기중입니다.'),
          ],
        ),
      ),
    );
  }
}
