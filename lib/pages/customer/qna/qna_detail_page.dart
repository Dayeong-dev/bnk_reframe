// qna_detail_page.dart
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

  bool _deleting = false; // 삭제 진행 상태

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

  // ===== 공통: 상태 라벨/색상 매핑 =====
  // 백엔드 status 값이 'WAIT', 'PENDING', '대기중', 'ANSWERED', 'DONE', 'COMPLETE', '답변완료' 등
  // 어떤 것이 와도 일관된 라벨/색상을 뱃지에 적용
  ({String label, Color bg, Color fg}) _statusChipStyle(String raw) {
    final s = (raw.trim().toUpperCase());
    final isWaiting =
        s == 'WAIT' || s == 'WAITING' || s == 'PENDING' || s == '대기중';
    final isAnswered =
        s == 'ANSWERED' || s == 'DONE' || s == 'COMPLETE' || s == '답변완료';

    if (isAnswered) {
      return (
        label: '답변완료',
        bg: const Color(0xFFE8F5E9),
        fg: const Color(0xFF2E7D32),
      );
    } else if (isWaiting) {
      return (
        label: '대기중',
        bg: const Color(0xFFF1F5F9),
        fg: const Color(0xFF334155),
      );
    }
    // 알 수 없는 값일 때는 중립 스타일
    return (
      label: raw,
      bg: const Color(0xFFF1F5F9),
      fg: const Color(0xFF334155),
    );
  }

  // ===== 리뷰 페이지와 통일된 삭제 다이얼로그 =====
  Future<bool> _showDeleteConfirmDialog() async {
    final primary = Theme.of(context).colorScheme.primary;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              '문의 삭제',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
        content: const Text(
          '이 문의를 삭제하시겠어요?',
          style: TextStyle(color: Colors.black87, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
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
    return ok == true;
  }

  Future<void> _delete() async {
    if (_deleting) return;

    final ok = await _showDeleteConfirmDialog();
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.api.delete(widget.qnaId);

      if (!mounted) return;
      // 삭제 성공: 이전 화면으로 true 전달
      Navigator.of(context).pop(true);
    } catch (e) {
      String msg = '삭제 실패: $e';
      try {
        final m = (e as dynamic).response?.data?['message'];
        if (m is String && m.isNotEmpty) msg = m;
      } catch (_) {}
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _qna;

    return Scaffold(
      appBar: AppBar(
        title: const Text('문의 상세'),
        actions: [
          if (!_loading &&
              _error == null &&
              q != null &&
              (q.answer == null || q.answer!.isEmpty))
            IconButton(
              tooltip: '수정',
              icon: const Icon(Icons.edit_rounded),
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
          _deleting
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: '삭제',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _delete,
                ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: '오류: $_error', onRetry: _load)
              : q == null
                  ? const Center(child: Text('데이터 없음'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          const _GradientHeader(
                            title: '1:1 문의',
                            subtitle: '등록하신 문의의 상세 내용을 확인하세요.',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _QuestionCard(
                              title: q.title,
                              category: q.category,
                              status: q.status, // ✔ 실제 상태 전달
                              content: q.content,
                              statusMapper: _statusChipStyle, // ✔ 스타일 매퍼
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _AnswerCard(
                              answerText: q.answer?.trim().isNotEmpty == true
                                  ? q.answer!.trim()
                                  : null,
                              answerAt: q.moddate,
                            ),
                          ),
                        ],
                      ),
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
        children: const [
          Text(
            '1:1 문의',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '등록하신 문의의 상세 내용을 확인하세요.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────── 질문 카드 ───────── */
class _QuestionCard extends StatelessWidget {
  final String title;
  final String category;
  final String status;
  final String content;

  // 상태 매핑 함수 주입(상세 빌드에서 전달)
  final ({String label, Color bg, Color fg}) Function(String raw) statusMapper;

  const _QuestionCard({
    required this.title,
    required this.category,
    required this.status,
    required this.content,
    required this.statusMapper,
  });

  static const _catBg = Color(0xFFEFF4FF);
  static const _catText = Color(0xFF1E40AF);

  @override
  Widget build(BuildContext context) {
    final mapped = statusMapper(status); // ✔ 상태 라벨/색상 변환

    final cs = Theme.of(context).colorScheme;
    return Material(
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✔ 실제 카테고리/상태 뱃지 표기
            Row(
              children: [
                _Chip(label: category, bg: _catBg, fg: _catText),
                const SizedBox(width: 6),
                _Chip(label: mapped.label, bg: mapped.bg, fg: mapped.fg),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────── 답변 카드 ───────── */
class _AnswerCard extends StatelessWidget {
  final String? answerText;
  final DateTime? answerAt;

  const _AnswerCard({this.answerText, this.answerAt});

  static const _labelBlue = Color(0xFF2962FF);
  static const _bubbleBlue = Color(0xFFEAF4FF);

  @override
  Widget build(BuildContext context) {
    final hasAnswer = (answerText != null && answerText!.isNotEmpty);

    return Material(
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A',
              style: TextStyle(
                color: _labelBlue,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: hasAnswer ? _bubbleBlue : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                hasAnswer ? answerText! : '답변 대기중입니다.',
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.55,
                  color: hasAnswer ? const Color(0xFF1F2937) : Colors.black54,
                ),
              ),
            ),
            if (hasAnswer && answerAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '답변일 • ${_formatDate(answerAt!)}',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }
}

/* ───────── 공용 칩 ───────── */
class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Chip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/* ───────── 오류 뷰 ───────── */
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
