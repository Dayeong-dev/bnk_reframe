import 'package:flutter/material.dart';
import 'qna_api_service.dart';
import 'qna_model.dart';
import 'qna_form_page.dart';
import 'qna_detail_page.dart';

class QnaListPage extends StatefulWidget {
  final QnaApiService api;
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
  bool _openingComposer = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchMyQnaList();

    if (widget.openComposerOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => QnaFormPage(
              api: widget.api,
              cameFromList: false,
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
          cameFromList: true,
        ),
        fullscreenDialog: true,
      ),
    );
    _openingComposer = false;
    if (created == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('문의내역'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          TextButton(
            onPressed: _openComposerFromList,
            child: const Text(
              '문의하기',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const _GradientHeader(
            title: '1:1 문의',
            subtitle: '등록하신 문의의 진행 상태를 확인할 수 있어요.',
          ),
          Expanded(
            child: FutureBuilder<List<Qna>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    message: '오류: ${snap.error}',
                    onRetry: _reload,
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return _EmptyView(onWrite: _openComposerFromList);
                }
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final q = items[i];
                      return _QnaCard(
                        title: q.title,
                        category: q.category,
                        status: q.status,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QnaDetailPage(
                                api: widget.api,
                                qnaId: q.qnaId,
                              ),
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
          ),
        ],
      ),
    );
  }
}

/* ───────── 그라데이션 헤더 ───────── */
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.3,
              )),
        ],
      ),
    );
  }
}

/* ───────── QnA 카드 아이템 ───────── */
class _QnaCard extends StatelessWidget {
  final String title;
  final String category;
  final String status;
  final VoidCallback onTap;

  const _QnaCard({
    required this.title,
    required this.category,
    required this.status,
    required this.onTap,
  });

  static const _chipBg = Color(0xFFEFF4FF);
  static const _chipText = Color(0xFF1E40AF);
  static const _statusBg = Color(0xFFF1F5F9);
  static const _statusText = Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.25)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Chip(label: category, bg: _chipBg, fg: _chipText),
                        const SizedBox(width: 6),
                        _Chip(label: status, bg: _statusBg, fg: _statusText),
                      ],
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

/* ───────── 빈 상태 / 오류 뷰 ───────── */
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
            const Text('등록된 문의가 없습니다.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text('궁금한 점을 남겨주시면 신속히 답변드릴게요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onWrite,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('문의쓰기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
