import 'package:flutter/material.dart';
import 'package:reframe/constants/color.dart';
import 'package:reframe/constants/number_format.dart';
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/model/enroll_form.dart';
import 'package:reframe/pages/enroll/appbar.dart';
import 'package:reframe/model/group_type.dart';
import 'package:reframe/pages/enroll/success_enroll.dart';
import 'package:reframe/service/enroll_service.dart';

import 'package:firebase_analytics/firebase_analytics.dart'; // ★ 추가: Analytics

class ThirdStepPage extends StatefulWidget {
  const ThirdStepPage({
    super.key,
    required this.product,
    required this.enrollForm
  });

  final DepositProduct product;
  final EnrollForm enrollForm;

  @override
  State<ThirdStepPage> createState() => _ThirdStepPageState();
}

class _ThirdStepPageState extends State<ThirdStepPage> {

  // ★ 교체: 퍼널 로깅 헬퍼 (ThirdStepPage)
  Future<void> _logStep({required String stage}) {
    // 값이 전부 non-null인 맵으로 선언
    final Map<String, Object> params = <String, Object>{
      'funnel_id': 'deposit_apply_v1',
      'step_index': 3,
      'step_name': '최종확인',
      'stage': stage, // "view" | "submit"
      'product_id': widget.product.productId.toString(),
    };

    final amount = widget.enrollForm.paymentAmount; // int?
    if (amount != null) {
      params['amount'] = amount; // Object로 안전
    }

    final months = widget.enrollForm.periodMonths; // int?
    if (months != null) {
      params['months'] = months;
    }

    return FirebaseAnalytics.instance.logEvent(
      name: 'bnk_apply_step',
      parameters: params, // <- 이제 타입 일치(Map<String, Object>?)
    );
  }


  @override
  void initState() {
    _logStep(stage: 'view');
    super.initState();
  }

  Future<void> _submit() async {
    await _logStep(stage: 'submit');

    if(widget.enrollForm.paymentAmount != null) {
      widget.enrollForm.paymentAmount = widget.enrollForm.paymentAmount! * 10000;
    }
    await addApplication(widget.product.productId, widget.enrollForm, context);
  }

  TableRow _buildTableRow({required String title, required String value}) {
    return TableRow(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w800
            )
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Align(
            alignment: Alignment.topRight,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              )
            ),
          ),
        )
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor2,
      appBar: buildAppBar(context),
      body: Center(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Text(
                '상품을 가입하시겠습니까?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow()
                ],
                borderRadius: BorderRadius.all(Radius.circular(8))
              ),
              child: Column(
                children: [
                  Table(
                    columnWidths: const <int, TableColumnWidth>{
                      0: IntrinsicColumnWidth(),
                      1: FlexColumnWidth(),
                    },
                    children: [
                      _buildTableRow(
                          title: '상품명',
                          value: widget.product.name,
                      ),
                      if(widget.enrollForm.paymentAmount != null)
                        _buildTableRow(
                            title: '납입 금액',
                            value: '${money.format(widget.enrollForm.paymentAmount! * 10000)}원'
                        ),
                      if(widget.enrollForm.periodMonths != null)
                        _buildTableRow(
                            title: '납입 기간',
                            value: '${widget.enrollForm.periodMonths}개월'
                        ),
                      if(widget.enrollForm.transferDate != null)
                        _buildTableRow(
                            title: '이체일',
                            value: '매달 ${widget.enrollForm.transferDate!}일'
                        ),
                      if(widget.enrollForm.fromAccountId != null)
                        _buildTableRow(
                            title: '출금 계좌',
                            value: widget.enrollForm.fromAccountNumber.toString()
                        ),
                      if(widget.enrollForm.maturityAccountId != null)
                        _buildTableRow(
                            title: '만기 시 입금 계좌',
                            value: widget.enrollForm.maturityAccountNumber.toString()
                        ),
                      if(widget.enrollForm.groupType != null)
                        _buildTableRow(
                            title: '모임 구분',
                            value: groupType[widget.enrollForm.groupType!]!
                        ),
                      if(widget.enrollForm.groupName != null)
                        _buildTableRow(
                            title: '모임 이름',
                            value: widget.enrollForm.groupName!
                        ),
                    ],
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      thickness: 1,
                      height: 1,
                      color: Colors.grey[200]
                    )
                  ),
                  Text(
                    "실제 기본(우대)이율의 적용은 제공받은 약관 및 상품설명서에 따릅니다.",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "본 상품 해지 시 원리금은 연결계좌(신규시 사용된 출금계좌)로만 입금 가능하며, 영업점에서 해지 시 연결계좌가 한도제한계좌인 경우 금융거래목적을 입증하는 서류를 지참해야 해지가 가능합니다.",
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12
                    ),)
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                    "네! 가입하겠습니다.",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800
                    )
                )
              ),
            )
          ],
        ),
      ),
    );
  }
}
