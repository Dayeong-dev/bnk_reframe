import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 햅틱
import 'package:reframe/constants/color.dart';
import 'package:reframe/model/product_input_format.dart';
import 'package:reframe/pages/enroll/appbar.dart';
import 'package:reframe/pages/enroll/enroll_second.dart';
import 'package:reframe/pages/enroll/pdf_view_page.dart';

import 'package:firebase_analytics/firebase_analytics.dart'; // Analytics
import '../../constants/api_constants.dart';
import '../../model/deposit_product.dart';

enum ConsentKind { pdf, info }

class FirstStepPage extends StatefulWidget {
  final VoidCallback? onNext;
  final DepositProduct product;

  const FirstStepPage({super.key, this.onNext, required this.product});

  @override
  State<FirstStepPage> createState() => _FirstStepPageState();
}

class _FirstStepPageState extends State<FirstStepPage> {
  // 퍼널 로깅
  Future<void> _logStep({
    required int stepIndex,
    required String stepName,
    required String stage, // "view" | "submit"
  }) {
    return FirebaseAnalytics.instance.logEvent(
      name: 'bnk_apply_step',
      parameters: {
        'funnel_id': 'deposit_apply_v1',
        'step_index': stepIndex,
        'step_name': stepName,
        'stage': stage,
        'product_id': widget.product.productId.toString(),
      },
    );
  }

  late String _termFileName;
  late String _manualFileName;
  late String _category;

  late List<_ConsentItem> _items;

  @override
  void initState() {
    _termFileName = widget.product.term?.filename ?? "term";
    _manualFileName = widget.product.manual?.filename ?? "manual";
    _category = widget.product.category ?? "기타";

    _items = [
      _ConsentItem(
        kind: ConsentKind.pdf,
        title: '${widget.product.name} 상품 설명서',
        required: true,
        pdfUrl: '$apiBaseUrl/uploads/manuals/$_manualFileName.pdf',
      ),
      _ConsentItem(
        kind: ConsentKind.pdf,
        title: '${widget.product.name} 이용약관',
        required: true,
        pdfUrl: '$apiBaseUrl/uploads/terms/$_termFileName.pdf',
      ),
      _ConsentItem(
        kind: ConsentKind.pdf,
        title: '예금거래기본약관 동의',
        required: true,
        pdfUrl: '$apiBaseUrl/uploads/common/예금거래기본약관.pdf',
      ),
      ...(_category == "적금"
          ? [
              _ConsentItem(
                kind: ConsentKind.pdf,
                title: '적립식예금약관 동의',
                required: true,
                pdfUrl: '$apiBaseUrl/uploads/common/적립식 예금 약관.pdf',
              )
            ]
          : _category == "예금"
              ? [
                  _ConsentItem(
                    kind: ConsentKind.pdf,
                    title: '거치식예금약관 동의',
                    required: true,
                    pdfUrl: '$apiBaseUrl/uploads/common/거치식 예금 약관.pdf',
                  )
                ]
              : [
                  _ConsentItem(
                    kind: ConsentKind.pdf,
                    title: '입출금이 자유로운 예금 약관 동의',
                    required: true,
                    pdfUrl: '$apiBaseUrl/uploads/common/입출금이 자유로운 예금 약관.pdf',
                  )
                ]),
      _ConsentItem(
        kind: ConsentKind.info,
        title: '예금자 보호법 확인',
        required: true,
        infoText:
            "본인이 가입하는 금융상품의 예금자보호여부 및 보호한도 (원금과 소정의 이자를 합하여 1인당 5천만원)에 대하여 설명을 보고, 충분히 이해하였음을 확인합니다.",
      ),
      _ConsentItem(
        kind: ConsentKind.info,
        title: '차명거래금지에 관한 설명',
        required: true,
        infoText:
            "[금융실명거래 및 비밀보장에 관한 법률] 제3조 제3항에 따라 누구든지 불법재산의 은닉, 자금세탁행위, 공중협박자금 조달행위 및 강제집행의 면탈, 그 밖의 탈법행위를 목적으로 타인의 실명으로 금융거래를 하여서는 안되며, 이를 위반 시 5년 이하의 징역 또는 5천만원 이하의 벌금에 처해질 수 있습니다. 본인은 위 내용을 안내 받고, 충분히 이해하였음을 확인합니다.",
      ),
      _ConsentItem(
        kind: ConsentKind.info,
        title: '은행상품 구속행위 규제제도 안내',
        required: true,
        infoText:
            "개인사업자 또는 신용점수가 낮은 개인인 경우, 금융소비자보호법(제 20조)상 구속행위 여부 판정에 따라 신규일 이후 1개월 이내 본인명의 대출거래가 제한될 수 있습니다.",
      ),
    ];

    _logStep(stepIndex: 1, stepName: '약관동의', stage: 'view');

    super.initState();
  }

  // 유틸 getter
  List<_ConsentItem> get _pdfItems =>
      _items.where((e) => e.kind == ConsentKind.pdf && e.required).toList();

  bool get _allPdfChecked => _pdfItems.every((e) => e.checked);

  Future<void> _runPdfReviewFlow() async {
    for (final item in _pdfItems.where((e) => !e.checked)) {
      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(
            title: item.title,
            pdfUrl: item.pdfUrl ?? '',
          ),
        ),
      );
      if (confirmed == true) {
        setState(() => item.checked = true);
      } else {
        break;
      }
    }
  }

  bool get _allChecked =>
      _items.where((e) => e.required).every((e) => e.checked == true);

  void _nextStep() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecondStepPage(product: widget.product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildAppBar(context: context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _items.length + 2,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _HeaderSection(productName: widget.product.name),
                    );
                  }

                  // index == 1 : PDF 전체 확인 마스터 타일
                  if (index == 1) {
                    return _ConsentTile(
                      title: 'PDF 연동 문서 전체 확인',
                      checked: _allPdfChecked,
                      trailingChevron: false,
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        if (_allPdfChecked) {
                          // 전부 해제 허용 (원치 않으면 이 분기 제거)
                          setState(() {
                            for (final i in _pdfItems) i.checked = false;
                          });
                        } else {
                          await _runPdfReviewFlow();
                        }
                      },
                      onCheckboxTapped: () async {
                        HapticFeedback.selectionClick();
                        if (_allPdfChecked) {
                          setState(() {
                            for (final i in _pdfItems) i.checked = false;
                          });
                        } else {
                          await _runPdfReviewFlow();
                        }
                      },
                      // infoText를 넣어 사용자에게 “전체 확인 시 문서가 순차로 열립니다” 안내해도 좋아요
                      infoText: '필수 PDF 문서를 순서대로 열람 후 하단에서 확인을 눌러야 동의 처리됩니다.',
                    );
                  }

                  // 이하 기존 아이템들은 인덱스 보정(+1)
                  final item = _items[index - 2];

                  return _ConsentTile(
                    title: item.title,
                    checked: item.checked,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => item.checked = !item.checked);
                    },
                    onCheckboxTapped: () {
                      HapticFeedback.selectionClick();
                      setState(() => item.checked = !item.checked);
                    },
                    infoText: item.infoText,
                    trailingChevron: false,
                  );
                },
              ),
            ),
            _BottomButton(
              enabled: _allChecked,
              onPressed: () async {
                final ok = await _showConfirmSheet(context);
                if (ok == true) widget.onNext?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmSheet(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              const Text(
                '상품의 중요 내용을\n충분히 읽고 이해하셨나요?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    await _logStep(
                        stepIndex: 1, stepName: '약관동의', stage: 'submit');
                    _nextStep();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '네, 확인했습니다.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================== UI 위젯 ==================

class _HeaderSection extends StatelessWidget {
  final String productName;
  const _HeaderSection({required this.productName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 22,
              height: 1.35,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: Colors.black87,
            ),
            children: [
              const TextSpan(text: '상품 가입을 위해\n'),
              TextSpan(
                text: '아래의 사항', // ✅ 이 부분만 블루
                style: TextStyle(color: primary),
              ),
              const TextSpan(text: '을 꼭 숙지해주세요.'),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ConsentTile extends StatelessWidget {
  final String title;
  final bool checked;
  final String? infoText;
  final bool trailingChevron;
  final VoidCallback onTap;
  final VoidCallback onCheckboxTapped;

  const _ConsentTile({
    required this.title,
    required this.checked,
    required this.onTap,
    required this.onCheckboxTapped,
    this.infoText,
    this.trailingChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primary = theme.colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        decoration: BoxDecoration(
          color: checked ? primary.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: checked ? primary.withOpacity(0.28) : Colors.black12,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onCheckboxTapped,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 140),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      checked ? Icons.check_box : Icons.check_box_outline_blank,
                      key: ValueKey(checked),
                      size: 26,
                      color: checked ? primary : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      letterSpacing: -0.2,
                      color: checked ? primary : Colors.black87,
                    ),
                  ),
                ),
                if (trailingChevron)
                  const Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
            if (infoText != null) ...[
              const SizedBox(height: 10),
              Text(
                infoText!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _BottomButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            disabledBackgroundColor: const Color(0xFFD0D0D0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child:
              const Text('다음', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

// ================== 데이터 모델 ==================

class _ConsentItem {
  final ConsentKind kind;
  final String title;
  final bool required;
  final String? pdfUrl;
  final String? infoText;
  bool checked;

  _ConsentItem({
    required this.kind,
    required this.title,
    required this.required,
    this.pdfUrl,
    this.infoText,
    this.checked = false,
  });
}
