import 'package:flutter/material.dart';
import 'qna_api_service.dart';
import 'qna_model.dart';
import 'qna_form_page.dart';
import 'qna_detail_page.dart';

class QnaListPage extends StatefulWidget {
  final QnaApiService api;
  const QnaListPage({super.key, required this.api});

  @override
  State<QnaListPage> createState() => _QnaListPageState();
}

class _QnaListPageState extends State<QnaListPage> {
  late Future<List<Qna>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchMyQnaList();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.api.fetchMyQnaList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문의내역')),
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
            return const Center(child: Text('등록된 문의가 없습니다.'));
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
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QnaFormPage(api: widget.api),
            ),
          );
          if (created == true) _reload();
        },
        icon: const Icon(Icons.edit),
        label: const Text('문의하기'),
      ),
    );
  }
}
