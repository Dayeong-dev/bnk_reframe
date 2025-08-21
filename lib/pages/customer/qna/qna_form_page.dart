import 'package:flutter/material.dart';
import 'qna_api_service.dart';
import 'qna_list_page.dart';

class QnaFormPage extends StatefulWidget {
  final QnaApiService api;
  final int? qnaId; // null이면 생성
  final String? initialCategory;
  final String? initialTitle;
  final String? initialContent;

  /// 목록에서 폼을 연 경우 true. 저장 후 pop(true)로 돌아가 목록 갱신.
  /// false면 저장 후 QnaListPage로 "교체" 진입.
  final bool cameFromList;

  const QnaFormPage({
    super.key,
    required this.api,
    this.qnaId,
    this.initialCategory,
    this.initialTitle,
    this.initialContent,
    this.cameFromList = false,
  });

  @override
  State<QnaFormPage> createState() => _QnaFormPageState();
}

class _QnaFormPageState extends State<QnaFormPage> {
  final _formKey = GlobalKey<FormState>();

  // 앱 카테고리: 예적금/기타만
  static const _allowedCategories = ['예적금', '기타'];

  late String _category;
  late TextEditingController _title;
  late TextEditingController _content;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final initCat = widget.initialCategory;
    _category = (initCat != null && _allowedCategories.contains(initCat))
        ? initCat
        : _allowedCategories.first;
    _title = TextEditingController(text: widget.initialTitle ?? '');
    _content = TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      if (widget.qnaId == null) {
        await widget.api.create(
          category: _category,
          title: _title.text.trim(),
          content: _content.text.trim(),
        );
      } else {
        await widget.api.update(
          qnaId: widget.qnaId!,
          category: _category,
          title: _title.text.trim(),
          content: _content.text.trim(),
        );
      }

      if (!mounted) return;
      if (widget.cameFromList) {
        // 리스트에서 열었으면 되돌아가며 true 반환 → 목록 리로드
        Navigator.pop(context, true);
      } else {
        // 단독으로 폼을 열었으면 저장 후 목록으로 "교체"
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QnaListPage(
              api: widget.api,
              openComposerOnStart: false, // 다시 자동열림 방지
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.qnaId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '문의 수정' : '문의 등록')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _category,
                items: _allowedCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
                decoration: const InputDecoration(labelText: '카테고리'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: '제목'),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? '제목을 입력해 주세요' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _content,
                minLines: 5,
                maxLines: 12,
                decoration: const InputDecoration(labelText: '내용'),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? '내용을 입력해 주세요' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.save),
                label: Text(_submitting ? '저장 중...' : '저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
