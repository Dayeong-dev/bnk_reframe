// lib/pages/enroll/enroll_second.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:reframe/constants/color.dart';
import 'package:reframe/model/account.dart';
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/model/enroll_form.dart';
import 'package:reframe/model/product_input_format.dart';
import 'package:reframe/model/group_type.dart';

import 'package:reframe/pages/enroll/appbar.dart';
import 'package:reframe/pages/enroll/enroll_third.dart';

import 'package:reframe/service/account_service.dart';
import 'package:reframe/service/deposit_service.dart';

import 'package:firebase_analytics/firebase_analytics.dart';

/// =======================================================
/// 토스 톤 토큰 (흰 배경 + 파란 포커스)
/// =======================================================
class TossTokens {
  static const Color primary = Color(0xFF3182F6);
  static const Color bg = Colors.white;
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E8EB);
  static const Color fieldFill = Color(0xFFF2F4F6);

  static const Color textStrong = Color(0xFF111827);
  static const Color text = Color(0xFF374151);
  static const Color textWeak = Color(0xFF6B7280);

  static const double r8 = 8;
  static const double r10 = 10;
  static const double r12 = 12;
}

const int kLastDay = 99; // '말일' 표시용

/// =======================================================
/// 2단계: 상품 설정 페이지
///  - 서버 포맷(ProductInputFormat)에 따라 필요한 섹션만 노출
///  - 모든 널/경계값 가드 처리 (흰화면 방지)
/// =======================================================
class SecondStepPage extends StatefulWidget {
  const SecondStepPage({super.key, required this.product});
  final DepositProduct product;

  @override
  State<SecondStepPage> createState() => _SecondStepPageState();
}

class _SecondStepPageState extends State<SecondStepPage> {
  final _formKey = GlobalKey<FormState>();
  final EnrollForm _data = EnrollForm();

  ProductInputFormat? _productInput;
  // ❗️late 대신 nullable + 가드
  Future<ProductInputFormat>? _formatFuture;

  // 기간/금액 범위 (서버 응답 오기 전 기본값)
  int _minMonths = 1;
  int _maxMonths = 60;
  int _minAmount = 5; // 만원
  int _maxAmount = 1000; // 만원

  // UI 표시용 선택 계좌명
  String? _fromAccountName;
  String? _maturityAccountName;

  // TERMLIST 여부/옵션
  late final bool _isTermList =
      (widget.product.termMode?.toUpperCase() == 'TERMLIST');
  List<int> _termOptions = [];

  // 계좌 목록
  late Future<List<Account>> _accountsFuture;

  // 애널리틱스 중복 로깅 방지
  bool _viewLogged = false;

  // ====== 라이프사이클 ======
  @override
  void initState() {
    super.initState();

    _accountsFuture = fetchAccounts(AccountType.demand);
    _termOptions = _parseTermLists(widget.product.termList);

    // ✅ 빌드 전에 안전한 기본값을 깔아둔다 (널 접근/흰화면 방지)
    _data.periodMonths = _isTermList
        ? (_termOptions.isNotEmpty ? _termOptions.first : _minMonths)
        : (widget.product.minPeriodMonths ?? _minMonths);
    _data.paymentAmount = _minAmount;

    _formatFuture = getProductInputFormat(widget.product.productId).then((fmt) {
      // 서버 포맷 기준으로 최종 범위/기본값 보정
      _minMonths = widget.product.minPeriodMonths ?? _minMonths;
      _maxMonths = widget.product.maxPeriodMonths ?? _maxMonths;

      if (fmt.input1) {
        _data.periodMonths = _isTermList
            ? (_termOptions.isNotEmpty
                ? _termOptions.first
                : (_data.periodMonths ?? _minMonths))
            : (_data.periodMonths ?? _minMonths);
      }
      if (fmt.input2) {
        _data.paymentAmount = _data.paymentAmount ?? _minAmount;
      }

      setState(() => _productInput = fmt);

      if (!_viewLogged) {
        _viewLogged = true;
        _logStep(stage: 'view');
      }
      return fmt;
    });
  }

  // ====== 로깅 ======
  Future<void> _logStep({
    required String stage, // "view" | "submit"
    int? amount,
    int? months,
  }) {
    return FirebaseAnalytics.instance.logEvent(
      name: 'bnk_apply_step',
      parameters: {
        'funnel_id': 'deposit_apply_v1',
        'step_index': 2,
        'step_name': '상품설정',
        'stage': stage,
        'product_id': widget.product.productId.toString(),
        if (amount != null) 'amount': amount,
        if (months != null) 'months': months,
      },
    );
  }

  // ====== 유틸 ======
  List<int> _parseTermLists(String? s) {
    if (s == null || s.trim().isEmpty) return [];
    return s
        .split(RegExp(r'[/,\s]+'))
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList()
      ..sort();
  }

  int? _toIntId(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) {
      final d = int.tryParse(v);
      if (d != null) return d;
      final m = RegExp(r'\d+').firstMatch(v);
      if (m != null) return int.tryParse(m.group(0)!);
    }
    return null;
  }

  bool _isValidAnchor(int? a) {
    if (a == null) return false;
    if (a == kLastDay) return true;
    return a >= 1 && a <= 31;
  }

  // ====== 검증 ======
  List<String> _validate(ProductInputFormat f) {
    final errs = <String>[];

    if (f.input1) {
      final v = _data.periodMonths;
      if (v == null || v < _minMonths || v > _maxMonths) {
        errs.add('납입 기간을 ${_minMonths}~${_maxMonths}개월로 선택해 주세요.');
      }
    }
    if (_isTermList && f.input1) {
      final v = _data.periodMonths;
      if (v == null || !_termOptions.contains(v)) {
        errs.add('납입 기간을 목록에서 선택해 주세요.');
      }
    }

    if (f.input2) {
      final v = _data.paymentAmount;
      if (v == null || v < _minAmount || v > _maxAmount) {
        errs.add('납입 금액을 ${_minAmount}~${_maxAmount}만원으로 입력해 주세요.');
      }
    }

    if (f.input3) {
      if (!_isValidAnchor(_data.transferDate)) {
        errs.add('이체일(앵커)을 선택해 주세요.');
      }
    }

    if (f.fromAccountReq && _data.fromAccountId == null) {
      errs.add('출금 계좌를 선택해 주세요.');
    }

    if (f.maturityAccountReq && _data.maturityAccountId == null) {
      errs.add('만기 입금 계좌를 선택해 주세요.');
    }

    if (f.input7) {
      final name = _data.groupName?.trim() ?? '';
      if (name.isEmpty) {
        errs.add('모임 이름을 입력해 주세요.');
      } else if (name.length > 20) {
        errs.add('모임 이름은 20자 이내로 입력해 주세요.');
      }
    }

    if (f.input8) {
      if (_data.groupType == null || _data.groupType!.isEmpty) {
        errs.add('모임 구분을 선택해 주세요.');
      }
    }
    return errs;
  }

  bool get _canSubmit =>
      _productInput != null && _validate(_productInput!).isEmpty;

  // ====== 액션 ======
  void _nextStep() async {
    if (_productInput == null) return;
    final errs = _validate(_productInput!);
    if (errs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errs.first),
          behavior: SnackBarBehavior.floating,
          backgroundColor: TossTokens.text,
        ),
      );
      return;
    }

    await _logStep(
      stage: 'submit',
      amount: _data.paymentAmount,
      months: _data.periodMonths,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThirdStepPage(
          product: widget.product,
          enrollForm: _data,
        ),
      ),
    );
  }

  Future<Account?> _pickAccount(String title) async {
    final accounts = await _accountsFuture;
    return await showModalBottomSheet<Account?>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true, // ← 중첩 네비게이터에서도 확실히 뜸
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: TossTokens.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: TossTokens.textStrong,
                      )),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: accounts.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: TossTokens.border),
                      itemBuilder: (_, i) {
                        final acc = accounts[i];
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 6),
                          title: Text(
                            '${acc.bankName ?? ''} ${acc.accountNumber ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: TossTokens.textStrong,
                            ),
                          ),
                          subtitle: Text(
                            '잔액: ${acc.balance}원',
                            style: const TextStyle(color: TossTokens.textWeak),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: TossTokens.textWeak),
                          onTap: () => Navigator.pop(context, acc),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ====== 빌드 ======
  @override
  Widget build(BuildContext context) {
    // 페이지 전용 라이트 테마(흰 배경 유지)
    final theme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: TossTokens.primary,
            onPrimary: Colors.white,
          ),
      scaffoldBackgroundColor: TossTokens.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: TossTokens.card,
        foregroundColor: TossTokens.textStrong,
        elevation: 0,
        centerTitle: true,
      ),
      dividerColor: TossTokens.border,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: TossTokens.fieldFill,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(TossTokens.r10)),
        ),
      ),
    );

    final fut = _formatFuture; // 널 가드용 로컬

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: TossTokens.bg,
        appBar: buildAppBar(context),
        bottomNavigationBar:
            _BottomButton(enabled: _canSubmit, onPressed: _nextStep),
        body: fut == null
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<ProductInputFormat>(
                future: fut,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return const Center(child: Text('입력 포맷을 불러오지 못했습니다.'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: Text('설정 정보를 찾을 수 없습니다.'));
                  }

                  final p = snap.data!;

                  final hasAnySection = (p.input1 ||
                      p.input2 ||
                      p.input3 ||
                      p.fromAccountReq ||
                      p.maturityAccountReq ||
                      p.input7 ||
                      p.input8);

                  return Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 16),
                      children: [
                        // 제목
                        Text(
                          widget.product.name.isNotEmpty
                              ? widget.product.name
                              : '상품 설정',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: TossTokens.textStrong,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (!hasAnySection)
                          SectionCard(
                            title: '설정 항목이 없습니다',
                            subtitle: '상품 설정 항목이 없어 바로 다음 단계로 진행할 수 있습니다.',
                            child: const Text(
                              '하단의 [다음] 버튼을 눌러주세요.',
                              style: TextStyle(color: TossTokens.text),
                            ),
                          ),

                        if (p.input1)
                          (_isTermList
                              ? TermListSection(
                                  options: _termOptions,
                                  value: _data.periodMonths ?? _minMonths,
                                  onChanged: (v) =>
                                      setState(() => _data.periodMonths = v),
                                )
                              : PeriodSection(
                                  value: _data.periodMonths ?? _minMonths,
                                  min: _minMonths,
                                  max: _maxMonths,
                                  onChanged: (v) =>
                                      setState(() => _data.periodMonths = v),
                                )),
                        if (p.input1) const SizedBox(height: 12),

                        if (p.input2) ...[
                          AmountSection(
                            value: _data.paymentAmount ?? _minAmount,
                            min: _minAmount,
                            max: _maxAmount,
                            onChanged: (v) =>
                                setState(() => _data.paymentAmount = v),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (p.input3) ...[
                          CupertinoMonthlyWheel(
                            onChanged: (firstDebitDate, anchor) {
                              setState(() => _data.transferDate = anchor);
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (p.fromAccountReq) ...[
                          AccountPickerSection(
                            title: '출금 계좌',
                            subtitle: '월 납입 출금 계좌',
                            selectedId: _fromAccountName,
                            onPick: () async {
                              final account = await _pickAccount('출금 계좌 선택');
                              if (account != null) {
                                _data.fromAccountId = _toIntId(account.id);
                                _data.fromAccountNumber = account.accountNumber;
                                setState(() {
                                  _fromAccountName =
                                      '${account.bankName} ${account.accountNumber}';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (p.maturityAccountReq) ...[
                          AccountPickerSection(
                            title: '만기 계좌',
                            subtitle: '만기 입금 계좌',
                            selectedId: _maturityAccountName,
                            onPick: () async {
                              final account =
                                  await _pickAccount('만기 시 입금 계좌 선택');
                              if (account != null) {
                                _data.maturityAccountId = _toIntId(account.id);
                                _data.maturityAccountNumber =
                                    account.accountNumber;
                                setState(() {
                                  _maturityAccountName =
                                      '${account.bankName} ${account.accountNumber}';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (p.input7) ...[
                          GroupNameSection(
                            value: _data.groupName ?? '',
                            onChanged: (v) =>
                                setState(() => _data.groupName = v),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (p.input8)
                          GroupTypeSection(
                            selectedCode: _data.groupType ?? '',
                            onChanged: (code, label) =>
                                setState(() => _data.groupType = code),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// =======================================================
/// 하단 CTA 버튼 (비활성일 때도 토스톤 유지)
/// =======================================================
class _BottomButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _BottomButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: TossTokens.card,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  enabled ? TossTokens.primary : const Color(0xFFDFE7FF),
              foregroundColor: enabled ? Colors.white : const Color(0xFF7C8DB5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TossTokens.r12),
              ),
            ),
            child: const Text(
              '다음',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================================================
/// 공용 섹션 카드
/// =======================================================
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TossTokens.card,
        borderRadius: BorderRadius.circular(TossTokens.r12),
        border: Border.all(color: TossTokens.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: TossTokens.textStrong)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style:
                    const TextStyle(color: TossTokens.textWeak, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// =======================================================
/// 유틸
/// =======================================================
String _fmtK(DateTime d) {
  const wk = ['월', '화', '수', '목', '금', '토', '일'];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}.${two(d.month)}.${two(d.day)}(${wk[d.weekday - 1]})';
}

/// 작은 배지
class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.primary = false, super.key});
  final String text;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary
            ? TossTokens.primary.withOpacity(.12)
            : TossTokens.fieldFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              primary ? TossTokens.primary.withOpacity(.35) : TossTokens.border,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: primary ? TossTokens.primary : TossTokens.text,
        ),
      ),
    );
  }
}

class _DebitPreviewCard extends StatelessWidget {
  const _DebitPreviewCard({
    required this.firstDate,
    required this.isThisMonth,
    super.key,
  });

  final DateTime firstDate;
  final bool isThisMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TossTokens.fieldFill,
        borderRadius: BorderRadius.circular(TossTokens.r12),
        border: Border.all(color: TossTokens.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined,
              size: 20, color: TossTokens.text),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: '첫 이체일: ',
                        style: TextStyle(
                          color: TossTokens.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: _fmtK(firstDate),
                        style: const TextStyle(
                          color: TossTokens.textStrong,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isThisMonth ? '이번달 납입' : '다음달 납입',
                  style:
                      const TextStyle(color: TossTokens.textWeak, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _Badge(isThisMonth ? '이번달' : '다음달', primary: !isThisMonth),
        ],
      ),
    );
  }
}

/// =======================================================
/// 섹션: 납입 기간
/// =======================================================
class PeriodSection extends StatefulWidget {
  const PeriodSection({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.divisions,
  });

  final int value;
  final int min;
  final int max;
  final int? divisions;
  final ValueChanged<int> onChanged;

  @override
  State<PeriodSection> createState() => _PeriodSectionState();
}

class _PeriodSectionState extends State<PeriodSection> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant PeriodSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '납입 기간',
      subtitle: '원하는 기간을 선택하세요',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: TossTokens.primary,
              inactiveTrackColor: TossTokens.border,
              thumbColor: TossTokens.primary,
              overlayColor: TossTokens.primary.withOpacity(0.1),
            ),
            child: Slider(
              value: widget.value.toDouble(),
              min: widget.min.toDouble(),
              max: widget.max.toDouble(),
              divisions: widget.divisions ?? (widget.max - widget.min),
              label: '${widget.value}개월',
              onChanged: (v) => widget.onChanged(v.round()),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  focusNode: _focus,
                  controller: _controller,
                  decoration: const InputDecoration(hintText: '개월 수 직접입력'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= widget.min && n <= widget.max) {
                      widget.onChanged(n);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text('개월', style: TextStyle(color: TossTokens.text)),
            ],
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// 섹션: 납입 금액
/// =======================================================
class AmountSection extends StatefulWidget {
  const AmountSection({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.divisions,
  });

  final int value; // 만원
  final int min;
  final int max;
  final int? divisions;
  final ValueChanged<int> onChanged;

  @override
  State<AmountSection> createState() => _AmountSectionState();
}

class _AmountSectionState extends State<AmountSection> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant AmountSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '납입 금액',
      subtitle: '납입 금액을 입력하세요',
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              focusNode: _focus,
              controller: _controller,
              decoration: const InputDecoration(hintText: '월 납입 금액(만원)'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n >= widget.min && n <= widget.max) {
                  widget.onChanged(n);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          const Text('만원', style: TextStyle(color: TossTokens.text)),
        ],
      ),
    );
  }
}

/// =======================================================
/// 섹션: 납입 일정 (바텀시트 + CupertinoPicker)
/// =======================================================
class CupertinoMonthlyWheel extends StatefulWidget {
  const CupertinoMonthlyWheel({
    super.key,
    this.onChanged,
    this.useAllDays31 = false,
  });

  final void Function(DateTime firstDebitDate, int anchor)? onChanged;
  final bool useAllDays31;

  @override
  State<CupertinoMonthlyWheel> createState() => _CupertinoMonthlyWheelState();
}

class _CupertinoMonthlyWheelState extends State<CupertinoMonthlyWheel> {
  int? _anchor;
  DateTime? _firstDebitDate;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int _lastDayOfMonth(int y, int m) => DateTime(y, m + 1, 0).day;

  DateTime _computeFirst(int anchor) {
    final t = _today;
    if (anchor == kLastDay) {
      final lastThis = _lastDayOfMonth(t.year, t.month);
      if (t.day <= lastThis) return DateTime(t.year, t.month, lastThis);
      final lastNext = _lastDayOfMonth(t.year, t.month + 1);
      return DateTime(t.year, t.month + 1, lastNext);
    } else {
      if (anchor >= t.day) {
        final day = anchor.clamp(1, _lastDayOfMonth(t.year, t.month));
        return DateTime(t.year, t.month, day);
      } else {
        final day = anchor.clamp(1, _lastDayOfMonth(t.year, t.month + 1));
        return DateTime(t.year, t.month + 1, day);
      }
    }
  }

  List<_WheelItem> _dayItems() {
    if (widget.useAllDays31) {
      return List.generate(31, (i) => _WheelItem(i + 1, '${i + 1}일'));
    }
    return [
      ...List.generate(28, (i) => _WheelItem(i + 1, '${i + 1}일')),
      const _WheelItem(kLastDay, '말일'),
    ];
  }

  Future<void> _openWheel() async {
    final items = _dayItems();
    int initialIndex = 0;
    if (_anchor != null) {
      final idx = items.indexWhere((e) => e.value == _anchor);
      if (idx >= 0) initialIndex = idx;
    }
    int tempIndex = initialIndex;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true, // ← 중첩 네비게이터에서도 확실히 뜨게
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: TossTokens.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        int tempAnchor = items[tempIndex].value;
        DateTime tempFirst = _computeFirst(tempAnchor);

        return StatefulBuilder(builder: (ctx, setSheet) {
          void recompute() {
            tempAnchor = items[tempIndex].value;
            tempFirst = _computeFirst(tempAnchor);
            setSheet(() {});
          }

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(ctx).size.height * 0.6,
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(ctx).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('이체일 선택',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: TossTokens.textStrong)),
                    const SizedBox(height: 8),
                    const Text('1~28일 또는 말일 중에서 선택하세요',
                        style: TextStyle(
                            color: TossTokens.textWeak, fontSize: 13)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: CupertinoPicker(
                        itemExtent: 44,
                        scrollController: FixedExtentScrollController(
                            initialItem: initialIndex),
                        onSelectedItemChanged: (i) {
                          tempIndex = i;
                          recompute();
                        },
                        children: items
                            .map((e) => Center(
                                  child: Text(e.label,
                                      style: const TextStyle(fontSize: 16)),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DebitPreviewCard(
                      firstDate: tempFirst,
                      isThisMonth: (tempFirst.month == _today.month &&
                          tempFirst.year == _today.year),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              foregroundColor: TossTokens.text,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(TossTokens.r10),
                              ),
                            ),
                            child: const Text('취소'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final anchor = items[tempIndex].value;
                              final first = _computeFirst(anchor);
                              setState(() {
                                _anchor = anchor;
                                _firstDebitDate = first;
                              });
                              widget.onChanged?.call(first, anchor);
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TossTokens.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(TossTokens.r10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('확인',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '납입 일정',
      subtitle: '이체일만 고르면, 규칙에 따라 이번달/다음달이 자동 결정돼요',
      child: InkWell(
        borderRadius: BorderRadius.circular(TossTokens.r12),
        onTap: () {
          // 어디를 눌러도 시트 오픈 + 포커스 해제
          FocusScope.of(context).unfocus();
          _openWheel();
        },
        child: Row(
          children: [
            const Icon(Icons.event_available_outlined, color: TossTokens.text),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _firstDebitDate == null
                    ? '날짜를 선택해주세요.'
                    : '${_fmtK(_firstDebitDate!)} • ${(_firstDebitDate!.month == DateTime.now().month && _firstDebitDate!.year == DateTime.now().year) ? '이번달' : '다음달'} 납입',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: TossTokens.textStrong,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                _openWheel();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: TossTokens.border),
                foregroundColor: TossTokens.text,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TossTokens.r12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text('선택'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelItem {
  final int value;
  final String label;
  const _WheelItem(this.value, this.label);
}

/// =======================================================
/// 섹션: 모임 이름
/// =======================================================
class GroupNameSection extends StatefulWidget {
  const GroupNameSection({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<GroupNameSection> createState() => _GroupNameSectionState();
}

class _GroupNameSectionState extends State<GroupNameSection> {
  late final TextEditingController controller;

  @override
  void initState() {
    controller = TextEditingController(text: widget.value);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '모임 이름',
      child: TextFormField(
        controller: controller,
        maxLength: 20,
        decoration: const InputDecoration(
          hintText: '예) 제주도 여행 모임',
          counterText: '', // 카운터 숨김
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// =======================================================
/// 섹션: 모임 구분 (칩)
/// =======================================================
class GroupTypeSection extends StatefulWidget {
  const GroupTypeSection({
    super.key,
    required this.selectedCode,
    required this.onChanged,
  });

  final String? selectedCode;
  final void Function(String code, String label) onChanged;

  @override
  State<GroupTypeSection> createState() => _GroupTypeSectionState();
}

class _GroupTypeSectionState extends State<GroupTypeSection> {
  late String? _code = widget.selectedCode;

  void _select(String code, String label) {
    setState(() => _code = code);
    widget.onChanged(code, label);
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '모임 구분',
      subtitle: '목적에 맞는 구분을 선택하세요',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: groupType.entries.map((e) {
          final code = e.key;
          final label = e.value;
          final selected = _code == code;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _select(code, label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? TossTokens.primary : TossTokens.fieldFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? TossTokens.primary : TossTokens.border,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : TossTokens.textStrong,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// =======================================================
/// 섹션: 계좌 선택
/// =======================================================
class AccountPickerSection extends StatelessWidget {
  const AccountPickerSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selectedId,
    required this.onPick,
  });

  final String title;
  final String subtitle;
  final String? selectedId;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(TossTokens.r12),
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtitle,
                        style: const TextStyle(
                            color: TossTokens.textWeak, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      selectedId ?? '선택해주세요',
                      style: TextStyle(
                        color: selectedId == null
                            ? TossTokens.textWeak
                            : TossTokens.textStrong,
                        fontWeight: selectedId == null
                            ? FontWeight.w400
                            : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: TossTokens.textWeak),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================================================
/// 섹션: TERMLIST 기간 선택
/// =======================================================
class TermListSection extends StatelessWidget {
  const TermListSection({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<int> options;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '납입 기간',
      subtitle: '아래 기간 중 하나를 선택하세요',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((m) {
          final selected = value == m;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onChanged(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? TossTokens.primary : TossTokens.fieldFill,
                border: Border.all(
                  color: selected ? TossTokens.primary : TossTokens.border,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$m개월',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : TossTokens.textStrong,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
