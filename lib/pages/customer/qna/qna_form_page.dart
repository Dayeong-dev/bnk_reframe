import 'package:flutter/material.dart';
import 'qna_api_service.dart';

class QnaFormPage extends StatefulWidget {
  final QnaApiService api;
  final int? qnaId; // null이면 생성
  final String? initialCategory;
  final String? initialTitle;
  final String? initialContent;
  const QnaFormPage({
    super.key,
    required this.api,
    this.qnaId,
    this.initialCategory,
    this.initialTitle,
    this.initialContent,
  });

  @override
  State<QnaFormPage> createState() => _QnaFormPageState();
}

class _QnaFormPageState extends State<QnaFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _categories = const ['일반', '상품', '이벤트', '기타'];

  late String _category;
  late TextEditingController _title;
  late TextEditingController _content;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? _categories.first;
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
        await widget.api.create(category: _category, title: _title.text.trim(), content: _content.text.trim());
      } else {
        await widget.api.update(
          qnaId: widget.qnaId!,
          category: _category,
          title: _title.text.trim(),
          content: _content.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
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
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v!),
                decoration: const InputDecoration(labelText: '카테고리'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: '제목'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력해 주세요' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _content,
                minLines: 5,
                maxLines: 12,
                decoration: const InputDecoration(labelText: '내용'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '내용을 입력해 주세요' : null,
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
