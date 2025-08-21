import 'package:flutter/material.dart';
import 'package:reframe/constants/color.dart';
import 'package:reframe/model/product_input_format.dart';
import 'package:reframe/pages/enroll/appbar.dart';
import 'package:reframe/pages/enroll/enroll_second.dart';
import 'package:reframe/pages/enroll/pdf_view_page.dart';

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
      _ConsentItem(kind: ConsentKind.pdf, title: '[상품명] 상품 설명서', required: true, pdfUrl: '$apiBaseUrl/uploads/terms/$_termFileName.pdf'),
      _ConsentItem(kind: ConsentKind.pdf, title: '[상품명] 이용약관', required: true, pdfUrl: '$apiBaseUrl/uploads/manuals/$_manualFileName.pdf'),
      _ConsentItem(kind: ConsentKind.pdf, title: '예금거래기본약관 동의', required: true, pdfUrl: '$apiBaseUrl/uploads/common/%E1%84%8B%E1%85%A8%E1%84%80%E1%85%B3%E1%86%B7%E1%84%80%E1%85%A5%E1%84%85%E1%85%A2%E1%84%80%E1%85%B5%E1%84%87%E1%85%A9%E1%86%AB%E1%84%8B%E1%85%A3%E1%86%A8%E1%84%80%E1%85%AA%E1%86%AB.pdf'),
      ...(_category == "적금"
          ? [
        _ConsentItem(
          kind: ConsentKind.pdf,
          title: '적립식예금약관 동의',
          required: true,
          pdfUrl:
          '$apiBaseUrl/uploads/common/%EC%A0%81%EB%A6%BD%EC%8B%9D%20%EC%98%88%EA%B8%88%20%EC%95%BD%EA%B4%80.pdf',
        )
      ]
          : [
        _ConsentItem(
          kind: ConsentKind.pdf,
          title: '거치식예금약관 동의',
          required: true,
          pdfUrl:
          '$apiBaseUrl/uploads/common/%E1%84%80%E1%85%A5%E1%84%8E%E1%85%B5%E1%84%89%E1%85%B5%E1%86%A8%20%E1%84%8B%E1%85%A8%E1%84%80%E1%85%B3%E1%86%B7%20%E1%84%8B%E1%85%A3%E1%86%A8%E1%84%80%E1%85%AA%E1%86%AB.pdf',
        )
      ]),
      // _ConsentItem(kind: ConsentKind.pdf, title: '자동이체(송금) 약관 동의', required: true, pdfUrl: '$apiBaseUrl/uploads/common/%E1%84%8C%E1%85%A1%E1%84%83%E1%85%A9%E1%86%BC%E1%84%8B%E1%85%B5%E1%84%8E%E1%85%A6(%E1%84%89%E1%85%A9%E1%86%BC%E1%84%80%E1%85%B3%E1%86%B7)%20%E1%84%8B%E1%85%A3%E1%86%A8%E1%84%80%E1%85%AA%E1%86%AB.pdf'),
      // _ConsentItem(kind: ConsentKind.pdf, title: '비과세종합저축 특약 동의', required: true, pdfUrl: '$apiBaseUrl/ntsa.pdf'),
      _ConsentItem(
          kind: ConsentKind.info,
          title: '예금자 보호법 확인',
          required: true,
          infoText: "본인이 가입하는 금융상품의 예금자보호여부 및 보호한도 (원금과 소정의 이자를 합하여 1인당 5천만원)에 대하여 설명을 보고, 충분히 이해하였음을 확인합니다."
      ),
      _ConsentItem(
          kind: ConsentKind.info,
          title: '차명거래금지에 관한 설명',
          required: true,
          infoText: "[금융실명거래 및 비밀보장에 관한 법률] 제3조 제3항에 따라 누구든지 불법재산의 은닉, 자금세탁행위, 공중협박자금 조달행위 및 강제집행의 면탈, 그 밖의 탈법행위를 목적으로 타인의 실명으로 금융거래를 하여서는 안되며, 이를 위반 시 5년 이하의 징역 또는 5천만원 이하의 벌금에 처해질 수 있습니다. 본인은 위 내용을 안내 받고, 충분히 이해하였음을 확인합니다."
      ),
      _ConsentItem(
        kind: ConsentKind.info,
        title: '은행상품 구속행위 규제제도 안내',
        required: true,
        infoText: "개인사업자 또는 신용점수가 낮은 개인인 경우, 금융소비자보호법(제 20조)상 구속행위 여부 판정에 따라 신규일 이후 1개월 이내 본인명의 대출거래가 제한될 수 있습니다.",
      ),
    ];

    super.initState();
  }

  bool get _allChecked => _items.where((e) => e.required).every((e) => e.checked == true);

  void _nextStep() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => SecondStepPage(
        product: widget.product,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor2,
      appBar: buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _items.length + 1, // ✅ 타이틀까지 포함
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '상품 가입을 위해\n아래의 사항을 꼭 숙지해주세요.',
                              style: TextStyle(fontSize: 24, height: 1.35, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                    );
                  }

                  final item = _items[index - 1]; // ✅ -1 해서 실제 데이터 접근

                  if (item.kind == ConsentKind.pdf) {
                    return _ConsentTile(
                      title: item.title,
                      checked: item.checked,
                      trailingChevron: true,
                      onTap: () async {
                        final confirmed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PdfViewerPage(title: item.title, pdfUrl: item.pdfUrl ?? ''),
                          ),
                        );
                        if (confirmed == true) {
                          setState(() => item.checked = true);
                        }
                      },
                      onCheckboxTapped: () {
                        if (item.checked) {
                          setState(() => item.checked = false);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('문서를 열람하고 하단의 확인 버튼을 눌러주세요.')),
                          );
                        }
                      },
                    );
                  }

                  return _ConsentTile(
                    title: item.title,
                    checked: item.checked,
                    onTap: () => setState(() => item.checked = !item.checked),
                    onCheckboxTapped: () => setState(() => item.checked = !item.checked),
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
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '네, 확인했습니다.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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

class _ConsentTile extends StatelessWidget {
  final String title;
  final bool checked;
  final String? infoText; // info 항목의 본문(기본 노출)
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onCheckboxTapped,
                  child: Icon(
                    checked ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (trailingChevron)
                  const Icon(Icons.chevron_right),
              ],
            ),
            if (infoText != null) ...[
              const SizedBox(height: 10),
              Text(
                infoText!,
                style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.45),
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
    return Container(
      color: Colors.white,
      padding:
      EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: primaryColor,
            disabledBackgroundColor: const Color(0xFFD0D0D0),
          ),
          child: Text(
            '다음',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800
            )
          ),
        ),
      ),
    );
  }
}

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
    this.checked = false, // 초기 체크박스: 모두 비어있음
  });
}
