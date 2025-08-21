import 'package:flutter/material.dart';
import 'qna_api_service.dart';
import 'qna_model.dart';
import 'qna_form_page.dart';
import 'qna_detail_page.dart';

class QnaListPage extends StatefulWidget {
  final QnaApiService api;
  // true면 진입 즉시 “폼으로 교체(pushReplacement)”하여 리스트를 거치지 않게 함
  final bool openComposerOnStart;

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
  bool _openingComposer = false; // 중복 열림 방지

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchMyQnaList();

    if (widget.openComposerOnStart) {
      // 리스트를 스택에 남기지 않고 곧바로 폼으로 "교체"
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => QnaFormPage(
              api: widget.api,
              cameFromList: false, // 폼에서 뒤로가면 바로 이전 페이지(MorePage)로
            ),
            fullscreenDialog: true,
          ),
        );
      });
    }
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.api.fetchMyQnaList();
    });
  }

  Future<void> _openComposerFromList() async {
    if (_openingComposer) return;
    _openingComposer = true;
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QnaFormPage(
          api: widget.api,
          cameFromList: true, // 저장 후 pop(true)로 돌아와 목록 갱신
        ),
        fullscreenDialog: true,
      ),
    );
    _openingComposer = false;
    if (created == true && mounted) _reload();
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
            onPressed: _openComposerFromList,
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
                    onPressed: _openComposerFromList,
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
                        builder: (_) =>
                            QnaDetailPage(api: widget.api, qnaId: q.qnaId),
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
        onPressed: _openComposerFromList,
        icon: const Icon(Icons.edit),
        label: const Text('문의하기'),
      ),
    );
  }
}
