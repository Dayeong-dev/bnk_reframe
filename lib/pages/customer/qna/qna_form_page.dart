import 'package:flutter/material.dart';
import 'qna_api_service.dart';
import 'qna_list_page.dart';

class QnaFormPage extends StatefulWidget {
  final QnaApiService api;
  final int? qnaId; // null이면 생성
  final String? initialCategory; // '예적금' | '기타'
  final String? initialTitle;
  final String? initialContent;
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

  // 1) 카테고리(예적금/기타)
  static const _categories = ['예적금', '기타'];

  // 2) 카테고리별 "문의 유형" 하드코딩 옵션
  static const Map<String, List<String>> _typeOptions = {
    '예적금': [
      '금리 문의',
      '이자/과세',
      '자동이체·납입',
      '중도/만기 해지',
      '비대면 계좌개설',
      '가입조건/예치한도',
    ],
    '기타': [
      '앱 오류/버그',
      '로그인/인증',
      '알림/푸시',
      '개인정보/보안',
      '상담/일반 문의',
      '기타',
    ],
  };

  late String _category;
  String? _qnaType; // 문의 유형
  late TextEditingController _title;
  late TextEditingController _content;
  bool _submitting = false;
  String? _typeErrorText; // 유형 미선택 시 에러 표시

  @override
  void initState() {
    super.initState();
    final init = widget.initialCategory;
    _category = _categories.contains(init) ? init! : _categories.first;
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
    // 문의 유형 필수 체크
    if (_qnaType == null) {
      setState(() => _typeErrorText = '문의 유형을 선택해 주세요');
      // 살짝 스크롤 올려서 유형 필드를 보여줌
      Scrollable.ensureVisible(_typeFieldKey.currentContext!,
          duration: const Duration(milliseconds: 220), alignment: .1);
      return;
    }
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
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                QnaListPage(api: widget.api, openComposerOnStart: false),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  final GlobalKey _typeFieldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    const borderGrey = Color(0xFFE5E7EB);
    const labelGrey = Color(0xFF6B7280);
    const selectedBorder = Colors.black87;

    final types = _typeOptions[_category] ?? const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('1:1 문의'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.3,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ── 1) 카테고리 세그먼트 ──────────────────────────────
            _SegmentGrid(
              items: _categories,
              selected: _category,
              onChanged: (v) {
                setState(() {
                  _category = v;
                  _qnaType = null; // 카테고리 바뀌면 유형 초기화
                  _typeErrorText = null; // 에러 메시지도 초기화
                });
              },
            ),
            const SizedBox(height: 20),

            // ── 2) 문의 유형 (모달 시트 선택기) ────────────────────
            Text('문의 유형', style: TextStyle(fontSize: 13, color: labelGrey)),
            const SizedBox(height: 8),
            _TypePickerField(
              key: _typeFieldKey,
              value: _qnaType,
              options: types,
              hint: '문의의 유형을 선택해 주세요.',
              borderGrey: borderGrey,
              selectedBorder: selectedBorder,
              errorText: _typeErrorText,
              onChanged: (v) => setState(() {
                _qnaType = v;
                _typeErrorText = null;
              }),
            ),

            const SizedBox(height: 20),

            // ── 3) 제목 ──────────────────────────────────────────
            Text('제목', style: TextStyle(fontSize: 13, color: labelGrey)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _title,
              decoration: _boxInputDecoration(
                hint: '제목을 입력해 주세요.',
                borderGrey: borderGrey,
                selectedBorder: selectedBorder,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '제목을 입력해 주세요' : null,
            ),

            const SizedBox(height: 20),

            // ── 4) 내용 ──────────────────────────────────────────
            Text('내용', style: TextStyle(fontSize: 13, color: labelGrey)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _content,
              minLines: 6,
              maxLines: 12,
              decoration: _boxInputDecoration(
                hint: '문의 내용을 입력해 주세요.',
                borderGrey: borderGrey,
                selectedBorder: selectedBorder,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '내용을 입력해 주세요' : null,
            ),

            const SizedBox(height: 24),

            // ── 저장 버튼 ────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('등록하기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 공통: 상자형 인풋 데코 (라운드 + 보더)
  InputDecoration _boxInputDecoration({
    required String hint,
    required Color borderGrey,
    required Color selectedBorder,
  }) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: selectedBorder, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}

/* ───────── 세그먼트 그리드(2열) : 예적금/기타 ───────── */
class _SegmentGrid extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onChanged;

  const _SegmentGrid({
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF5F6F8);
    const border = Color(0xFFE5E7EB);
    const selBorder = Colors.black87;
    const selText = Colors.black;
    const text = Color(0xFF9CA3AF);

    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2; // 가로 간격 12 기준 2칸
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((label) {
            final isSel = label == selected;
            return SizedBox(
              width: w,
              height: 64,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(label),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSel ? Colors.white : bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? selBorder : border,
                      width: isSel ? 1.6 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                      color: isSel ? selText : text,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/* ───────── 모달 시트 기반 "문의 유형" 선택 필드 ─────────
   - Dropdown이 아니라 bottom sheet를 열어 ListView를 표시.
   - 리스트/폼이 들썩이지 않고, 선택 후 즉시 반영.
*/
class _TypePickerField extends StatelessWidget {
  final String? value;
  final List<String> options;
  final String hint;
  final String? errorText;
  final Color borderGrey;
  final Color selectedBorder;
  final ValueChanged<String> onChanged;

  const _TypePickerField({
    super.key,
    required this.value,
    required this.options,
    required this.hint,
    required this.borderGrey,
    required this.selectedBorder,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    final borderColor = errorText == null ? borderGrey : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              constraints: const BoxConstraints(maxHeight: 420),
              builder: (_) => _TypeBottomSheet(
                title: hint,
                options: options,
                selected: value,
              ),
            );
            if (selected != null) {
              onChanged(selected);
            }
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value! : hint,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                      color: hasValue ? Colors.black : const Color(0xFF9CA3AF),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _TypeBottomSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? selected;

  const _TypeBottomSheet({
    required this.title,
    required this.options,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
              shrinkWrap: true,
              itemBuilder: (_, i) {
                final opt = options[i];
                final isSel = opt == selected;
                return ListTile(
                  title: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: isSel
                      ? const Icon(Icons.check_rounded, color: Colors.black)
                      : null,
                  onTap: () => Navigator.pop(context, opt),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: options.length,
            ),
          ),
        ],
      ),
    );
  }
}
