import 'dart:async';
import 'package:flutter/material.dart';
import 'qna_api_service.dart';
import 'qna_model.dart';
import 'qna_form_page.dart';
import 'qna_detail_page.dart';

class QnaListPage extends StatefulWidget {
  final QnaApiService api;
  final bool openComposerOnStart; // ← 추가

  const QnaListPage({
    super.key,
    required this.api,
    this.openComposerOnStart = false,
  });

  @override
  State<QnaListPage> createState() => _QnaListPageState();
}

class _QnaListPageState extends State<QnaListPage> {
  late Future<List<Qna>> _future;
  bool _openingComposer = false; // 중복 오픈 방지

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchMyQnaList();

    // 진입 즉시 문의쓰기 오픈(옵션)
    if (widget.openComposerOnStart) {
      // 첫 프레임 이후에 열어야 안전
      scheduleMicrotask(_openComposer);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.api.fetchMyQnaList();
    });
  }

  Future<void> _openComposer() async {
    if (_openingComposer) return;
    _openingComposer = true;
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QnaFormPage(
          api: widget.api,
          cameFromList: true, // ← 추가: 목록에서 왔다고 표시
        ),
      ),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('문의내역'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: '문의쓰기',
            onPressed: _openComposer,
          ),
        ],
      ),
      body: FutureBuilder<List<Qna>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('오류: ${snap.error}'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('등록된 문의가 없습니다.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openComposer,
                    icon: const Icon(Icons.edit),
                    label: const Text('문의쓰기'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final q = items[i];
                return ListTile(
                  title: Text(q.title),
                  subtitle: Text('${q.category} · ${q.status}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QnaDetailPage(api: widget.api, qnaId: q.qnaId),
                      ),
                    );
                    _reload();
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        icon: const Icon(Icons.edit),
        label: const Text('문의하기'),
      ),
    );
  }
}
