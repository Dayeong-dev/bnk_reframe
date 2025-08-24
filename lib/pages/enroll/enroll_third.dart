import 'package:flutter/material.dart';
import 'package:reframe/constants/number_format.dart';
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/model/enroll_form.dart';
import 'package:reframe/pages/enroll/appbar.dart';
import 'package:reframe/model/group_type.dart';
import 'package:reframe/service/enroll_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// ==============
/// Toss 스타일 토큰
/// ==============
class TossTokens {
  static const Color primary = Color(0xFF3182F6);
  static const Color bg = Colors.white;
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E8EB);
  static const Color textStrong = Color(0xFF111827);
  static const Color text = Color(0xFF374151);
  static const Color textWeak = Color(0xFF6B7280);
  static const Color fieldFill = Color(0xFFF2F4F6);
  static const Color disabled = Color(0xFFD1D5DB);

  static const double r10 = 10;
  static const double r12 = 12;
}

const int kLastDay = 99; // '말일' 표기용

class ThirdStepPage extends StatefulWidget {
  const ThirdStepPage({
    super.key,
    required this.product,
    required this.enrollForm,
  });

  final DepositProduct product;
  final EnrollForm enrollForm;

  @override
  State<ThirdStepPage> createState() => _ThirdStepPageState();
}

class _ThirdStepPageState extends State<ThirdStepPage> {
  Future<void> _logStep({required String stage}) {
    final Map<String, Object> params = <String, Object>{
      'funnel_id': 'deposit_apply_v1',
      'step_index': 3,
      'step_name': '최종확인',
      'stage': stage,
      'product_id': widget.product.productId.toString(),
    };
    final amount = widget.enrollForm.paymentAmount;
    if (amount != null) params['amount'] = amount;
    final months = widget.enrollForm.periodMonths;
    if (months != null) params['months'] = months;

    return FirebaseAnalytics.instance.logEvent(
      name: 'bnk_apply_step',
      parameters: params,
    );
  }

  @override
  void initState() {
    super.initState();
    _logStep(stage: 'view');
  }

  Future<void> _submit() async {
    await _logStep(stage: 'submit');

    if (widget.enrollForm.paymentAmount != null) {
      widget.enrollForm.paymentAmount =
          widget.enrollForm.paymentAmount! * 10000;
    }
    await addApplication(
      widget.product.productId,
      widget.enrollForm,
      context,
    );
  }

  String _fmtTransfer(int? d) {
    if (d == null) return '-';
    if (d == kLastDay) return '매달 말일';
    return '매달 ${d}일';
  }

  String _fmtMoneyFrom10k(int? v) {
    if (v == null) return '-';
    return '${money.format(v * 10000)}원';
  }

  String _orDash(String? v) => (v == null || v.isEmpty) ? '-' : v;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: TossTokens.bg,
      colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: TossTokens.primary,
            onPrimary: Colors.white,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TossTokens.card,
        foregroundColor: TossTokens.textStrong,
        elevation: 0,
        centerTitle: true,
      ),
      dividerColor: TossTokens.border,
    );

    final rows = <_KV>[
      _KV('상품명', widget.product.name),
      if (widget.enrollForm.paymentAmount != null)
        _KV('납입 금액', _fmtMoneyFrom10k(widget.enrollForm.paymentAmount)),
      if (widget.enrollForm.periodMonths != null)
        _KV('납입 기간', '${widget.enrollForm.periodMonths}개월'),
      if (widget.enrollForm.transferDate != null)
        _KV('이체일', _fmtTransfer(widget.enrollForm.transferDate)),
      if (widget.enrollForm.fromAccountNumber != null)
        _KV('출금 계좌', _orDash(widget.enrollForm.fromAccountNumber)),
      if (widget.enrollForm.maturityAccountNumber != null)
        _KV('만기 시 입금 계좌', _orDash(widget.enrollForm.maturityAccountNumber)),
      if (widget.enrollForm.groupType != null)
        _KV('모임 구분', groupType[widget.enrollForm.groupType!] ?? '-'),
      if (widget.enrollForm.groupName != null)
        _KV('모임 이름', widget.enrollForm.groupName!),
    ];

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: buildAppBar(context),
        body: SafeArea(
          child: Column(
            children: [
              // 상단 제목 (padding 아래로 조금 늘림)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '상품을 가입하시겠습니까?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: TossTokens.textStrong,
                    ),
                  ),
                ),
              ),

              // 내용 스크롤 영역
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    _InfoCard(rows: rows),
                    const SizedBox(height: 20),
                    _NoticeCard(
                      items: const [
                        '실제 기본(우대)이율의 적용은 제공받은 약관 및 상품설명서에 따릅니다.',
                        '본 상품 해지 시 원리금은 연결계좌(신규시 사용된 출금계좌)로만 입금 가능하며, 영업점에서 해지 시 연결계좌가 한도제한계좌인 경우 금융거래목적을 입증하는 서류를 지참해야 해지가 가능합니다.',
                      ],
                    ),
                    const SizedBox(height: 40), // ✅ 버튼과 간격 최소화
                  ],
                ),
              ),

              // 하단 버튼
              Container(
                color: TossTokens.card,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TossTokens.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TossTokens.r12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '네! 가입하겠습니다.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// Key-Value Row
/// ===============================
class _KV {
  final String k;
  final String v;
  _KV(this.k, this.v);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<_KV> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TossTokens.card,
        borderRadius: BorderRadius.circular(TossTokens.r12),
        border: Border.all(color: TossTokens.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _KeyValueRow(k: rows[i].k, v: rows[i].v),
            if (i != rows.length - 1)
              const Divider(height: 16, color: TossTokens.border),
          ],
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.k, required this.v});
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: const TextStyle(
                color: TossTokens.textWeak,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: TossTokens.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TossTokens.fieldFill,
        borderRadius: BorderRadius.circular(TossTokens.r12),
        border: Border.all(color: TossTokens.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in items) ...[
            Text(
              t,
              style: const TextStyle(
                color: TossTokens.textWeak,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
