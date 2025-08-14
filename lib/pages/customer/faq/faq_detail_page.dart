import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../service/faq_api.dart';
import '../../../model/faq.dart';
import '../../../store/faq_store.dart';

class FaqDetailPage extends StatefulWidget {
  final int faqId;
  final Faq? initial;
  const FaqDetailPage({super.key, required this.faqId, this.initial});

  @override
  State<FaqDetailPage> createState() => _FaqDetailPageState();
}

class _FaqDetailPageState extends State<FaqDetailPage> {
  late FaqApi _api;
  Future<Faq>? _future;
  bool _bound = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bound) return;
    _api = context.read<FaqStore>().api; // 또는 context.read<FaqApi>()
    _future = _api.fetchFaqDetail(widget.faqId);
    _bound = true;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _api.fetchFaqDetail(widget.faqId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ 상세 보기')),
      body: FutureBuilder<Faq>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasError) {
            if (widget.initial != null) {
              return _DetailBody(faq: widget.initial!, isStale: true, onBack: () => Navigator.pop(context), onRefresh: _refresh);
            }
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(message: '오류: ${snap.error}', onRetry: _refresh);
          }
          return _DetailBody(faq: snap.data!, onBack: () => Navigator.pop(context), onRefresh: _refresh);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Faq faq;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  final bool isStale;
  const _DetailBody({required this.faq, required this.onBack, required this.onRefresh, this.isStale = false});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (isStale)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: const [Icon(Icons.info_outline, size: 16), SizedBox(width: 6), Text('최신 내용 로딩 중...')]),
            ),
          _row('글번호', '${faq.faqId}'),
          _row('제목', faq.question ?? ''),
          _row('카테고리', faq.category ?? ''),
          if ((faq.status ?? '').isNotEmpty) _row('상태', faq.status!),
          const SizedBox(height: 8),
          const Text('답변', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(faq.answer ?? ''),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerRight, child: OutlinedButton(onPressed: onBack, child: const Text('목록으로 돌아가기'))),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('다시 시도')),
        ]),
      ),
    );
  }
}
