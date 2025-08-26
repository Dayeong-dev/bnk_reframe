// lib/pages/enroll/enroll_second.dart
import 'dart:ui' show ImageFilter;
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

import '../../service/enroll_service.dart';

const int kLastDay = 99; // '말일' 표시용
const double kRadius = 12;

// ✅ 공통 레이아웃/타이포 토큰(폰트 키움 + 입력박스 통일폭)
const double kTitleSize = 18;
const double kSubSize = 15;
const double kBodySize = 15;
const double kFieldWidth = 128; // 우측 입력박스 폭 통일
const double kDialogRadius = 14;

/// =======================================================
/// 2단계: 상품 설정 페이지
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
  late Future<void> _bootstrapFuture;

  // 변경 감지
  bool _dirty = false;
  void _markDirty() => _dirty = true;

  // 기간/금액 기본 범위
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

  @override
  void initState() {
    super.initState();

    _accountsFuture = fetchAccounts(AccountType.demand);
    _termOptions = _parseTermLists(widget.product.termList);
    _bootstrapFuture = _bootstrap();
  }

  // ====== 부트스트랩 (서버 포맷 + 드래프트 로드) ======
  Future<void> _bootstrap() async {
    final result = await getProductInputFormat(widget.product.productId);
    _productInput = result;

    _minMonths = widget.product.minPeriodMonths ?? _minMonths;
    _maxMonths = widget.product.maxPeriodMonths ?? _maxMonths;

    try {
      final draft = await getDraft(widget.product.productId);
      _applyDraft(draft);
    } catch (_) {
      if (result.input1 && _data.periodMonths == null) {
        _data.periodMonths = _isTermList
            ? (_termOptions.isNotEmpty ? _termOptions.first : 6)
            : _minMonths;
      }
      if (result.input2 && _data.paymentAmount == null) {
        _data.paymentAmount = _minAmount;
      }
    }

    if (!_viewLogged) {
      _viewLogged = true;
      await _logStep(stage: 'view');
    }
    setState(() {});
  }

  void _applyDraft(EnrollForm draft) {
    _data.periodMonths = draft.periodMonths ?? _data.periodMonths;
    _data.paymentAmount = draft.paymentAmount ?? _data.paymentAmount;
    _data.transferDate = draft.transferDate ?? _data.transferDate;
    _data.fromAccountId = draft.fromAccountId ?? _data.fromAccountId;
    _data.fromAccountNumber =
        draft.fromAccountNumber ?? _data.fromAccountNumber;
    _data.maturityAccountId =
        draft.maturityAccountId ?? _data.maturityAccountId;
    _data.maturityAccountNumber =
        draft.maturityAccountNumber ?? _data.maturityAccountNumber;
    _data.groupName = draft.groupName ?? _data.groupName;
    _data.groupType = draft.groupType ?? _data.groupType;

    if (_data.fromAccountNumber != null)
      _fromAccountName = _data.fromAccountNumber!;
    if (_data.maturityAccountNumber != null)
      _maturityAccountName = _data.maturityAccountNumber!;
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
        SnackBar(content: Text(errs.first)),
      );
      return;
    }

    await _logStep(
      stage: 'submit',
      amount: _data.paymentAmount,
      months: _data.periodMonths,
    );

    if (!mounted) return;
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
    final theme = Theme.of(context);
    final accounts = await _accountsFuture;
    return await showModalBottomSheet<Account?>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kDialogRadius),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.3),
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
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: kTitleSize,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: accounts.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (_, i) {
                        final acc = accounts[i];
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 6),
                          title: Text(
                            '${acc.bankName ?? ''} ${acc.accountNumber ?? ''}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: kBodySize,
                            ),
                          ),
                          subtitle: Text(
                            '잔액: ${acc.balance}원',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: kSubSize - 1,
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: theme.colorScheme.onSurfaceVariant),
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

  // ====== 나가기 확인 (blur + 둥근 모달)
  Future<bool> _confirmExit() async {
    if (!_dirty) return true; // 변경 없으면 바로 나감

    final ok = await showFrostedConfirmDialog<bool>(
      context: context,
      title: '나가기',
      message: '작성한 내용을 저장하고 나가시겠습니까?',
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            // TODO: 저장 안함 처리
            Navigator.pop(ctx, true);
          },
          child: const Text('저장 안함'),
        ),
        ElevatedButton(
          onPressed: () async {
            // TODO: 임시저장 처리
            Navigator.pop(ctx, true);
          },
          child: const Text('저장 후 나가기'),
        ),
      ],
    );
    return ok ?? false;
  }

  // ====== 빌드 ======
  @override
  Widget build(BuildContext context) {
    // WillPopScope: 앱바 back/제스처/하드웨어 back 모두 인터셉트
    return WillPopScope(
      onWillPop: () async => _confirmExit(),
      child: Scaffold(
        appBar: buildAppBar(
          context: context,
          enrollForm: _data,
          productId: widget.product.productId,
        ),
        bottomNavigationBar:
            _BottomButton(enabled: _canSubmit, onPressed: _nextStep),
        body: FutureBuilder(
          future: _bootstrapFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('입력 포맷을 불러오지 못했습니다.'));
            }

            final p = _productInput!;
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
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                children: [
                  // 제목
                  Text(
                    widget.product.name.isNotEmpty
                        ? widget.product.name
                        : '상품 설정',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                  ),
                  const SizedBox(height: 25),

                  if (!hasAnySection)
                    SectionCard(
                      title: '설정 항목이 없습니다',
                      subtitle: '상품 설정 항목이 없어 바로 다음 단계로 진행할 수 있습니다.',
                      child: Text(
                        '하단의 [다음] 버튼을 눌러주세요.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: kBodySize),
                      ),
                    ),

                  if (p.input1)
                    (_isTermList
                        ? TermListSection(
                            options: _termOptions,
                            value: _data.periodMonths ?? _minMonths,
                            onChanged: (v) => setState(() {
                              _data.periodMonths = v;
                              _markDirty();
                            }),
                          )
                        : PeriodSection(
                            value: _data.periodMonths ?? _minMonths,
                            min: _minMonths,
                            max: _maxMonths,
                            onChanged: (v) => setState(() {
                              _data.periodMonths = v;
                              _markDirty();
                            }),
                          )),
                  if (p.input1) const SizedBox(height: 12),

                  if (p.input2) ...[
                    AmountSection(
                      value: _data.paymentAmount ?? _minAmount,
                      min: _minAmount,
                      max: _maxAmount,
                      onChanged: (v) => setState(() {
                        _data.paymentAmount = v;
                        _markDirty();
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (p.input3) ...[
                    CupertinoMonthlyWheel(
                      initialAnchor: _data.transferDate,
                      onChanged: (firstDebitDate, anchor) {
                        setState(() {
                          _data.transferDate = anchor;
                          _markDirty();
                        });
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
                            _markDirty();
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
                        final account = await _pickAccount('만기 시 입금 계좌 선택');
                        if (account != null) {
                          _data.maturityAccountId = _toIntId(account.id);
                          _data.maturityAccountNumber = account.accountNumber;
                          setState(() {
                            _maturityAccountName =
                                '${account.bankName} ${account.accountNumber}';
                            _markDirty();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (p.input7) ...[
                    GroupNameSection(
                      value: _data.groupName ?? '',
                      onChanged: (v) => setState(() {
                        _data.groupName = v;
                        _markDirty();
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (p.input8)
                    GroupTypeSection(
                      selectedCode: _data.groupType ?? '',
                      onChanged: (code, label) => setState(() {
                        _data.groupType = code;
                        _markDirty();
                      }),
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
/// 하단 CTA 버튼 (Material)
/// =======================================================
class _BottomButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _BottomButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        color: theme.cardColor,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadius),
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
/// 공용 섹션 카드 (Material)
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
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: kTitleSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: kSubSize,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// =======================================================
/// 유틸/배지
/// =======================================================
String _fmtK(DateTime d) {
  const wk = ['월', '화', '수', '목', '금', '토', '일'];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}.${two(d.month)}.${two(d.day)}(${wk[d.weekday - 1]})';
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.primary = false, super.key});
  final String text;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = primary
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceVariant;
    final fg = primary
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 12,
          color: fg,
          fontWeight: FontWeight.w800,
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(.5),
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_outlined,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '첫 이체일: ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: kBodySize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: _fmtK(firstDate),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: kBodySize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isThisMonth ? '이번달 납입' : '다음달 납입',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: kSubSize - 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _Badge(isThisMonth ? '이번달' : '다음달', primary: !isThisMonth),
        ],
      ),
    );
  }
}

/// =======================================================
/// 공통: 아주 컴팩트한 숫자 입력칸(단위 포함) — 폭 통일
/// =======================================================
class CompactNumberField extends StatelessWidget {
  const CompactNumberField({
    super.key,
    required this.controller,
    required this.hint,
    required this.suffix,
    this.width = kFieldWidth,
    this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final String suffix;
  final double width;
  final void Function(String value)? onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: TextFormField(
        focusNode: focusNode,
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixText: suffix,
          suffixStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: kBodySize,
          ),
        ),
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.right,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }
}

/// =======================================================
/// 섹션: 납입 기간 — 한 행(슬라이더 | 우측 숫자 박스) 정렬 통일
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

  int? calcDivisions(double min, double max, double step) {
    if (max <= min || step <= 0) return null;
    final count = ((max - min) / step).floor();
    return count >= 1 ? count : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      title: '납입 기간',
      subtitle: '원하는 기간을 선택하세요',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.outline.withOpacity(.3),
                thumbColor: theme.colorScheme.primary,
                overlayColor: theme.colorScheme.primary.withOpacity(.12),
                trackHeight: 4,
                valueIndicatorColor: theme.colorScheme.primary,
              ),
              child: Slider(
                value: widget.value.toDouble(),
                min: widget.min.toDouble(),
                max: widget.max.toDouble(),
                divisions: widget.divisions ??
                    calcDivisions(
                        widget.min.toDouble(), widget.max.toDouble(), 1),
                onChanged: (v) => widget.onChanged(v.round()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CompactNumberField(
            controller: _controller,
            focusNode: _focus,
            hint: '개월',
            suffix: '개월',
            width: kFieldWidth,
            onChanged: (v) {
              if (v.isEmpty) return;
              final n = int.tryParse(v);
              if (n == null) return;
              if (n >= widget.min && n <= widget.max) {
                widget.onChanged(n);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// 섹션: 납입 금액 — 한 줄 (텍스트 | 입력박스)
/// =======================================================
class AmountSection extends StatefulWidget {
  const AmountSection({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final int value; // 만원
  final int min;
  final int max;
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
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('납입 금액',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: kTitleSize,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 4),
                Text('월 납입 금액(만원)을 입력하세요',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: kSubSize,
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
          ),
          CompactNumberField(
            controller: _controller,
            focusNode: _focus,
            hint: '금액',
            suffix: '만원',
            width: kFieldWidth,
            onChanged: (v) {
              if (v.isEmpty) return;
              final n = int.tryParse(v);
              if (n == null) return;
              if (n >= widget.min && n <= widget.max) {
                widget.onChanged(n);
              }
            },
          ),
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
    this.initialAnchor,
  });

  final void Function(DateTime firstDebitDate, int anchor)? onChanged;
  final bool useAllDays31;
  final int? initialAnchor;

  @override
  State<CupertinoMonthlyWheel> createState() => _CupertinoMonthlyWheelState();
}

class _CupertinoMonthlyWheelState extends State<CupertinoMonthlyWheel> {
  int? _anchor;
  DateTime? _firstDebitDate;

  @override
  void initState() {
    super.initState();
    if (widget.initialAnchor != null) {
      _anchor = widget.initialAnchor;
      _firstDebitDate = _computeFirst(_anchor!);
    }
  }

  @override
  void didUpdateWidget(covariant CupertinoMonthlyWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAnchor != widget.initialAnchor) {
      setState(() {
        _anchor = widget.initialAnchor;
        _firstDebitDate = (_anchor == null) ? null : _computeFirst(_anchor!);
      });
    }
  }

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
    final theme = Theme.of(context);
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
      useRootNavigator: true,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius)),
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
                    Text('이체일 선택',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: kTitleSize,
                        )),
                    const SizedBox(height: 8),
                    Text(
                      '1~28일 또는 말일 중에서 선택하세요',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: kSubSize,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: CupertinoPicker(
                        itemExtent: 44,
                        scrollController: FixedExtentScrollController(
                          initialItem: initialIndex,
                        ),
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(kRadius),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(kRadius),
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
    final theme = Theme.of(context);
    final isThisMonth = (_firstDebitDate?.month == DateTime.now().month &&
        _firstDebitDate?.year == DateTime.now().year);

    return SectionCard(
      title: '납입 일정',
      subtitle: '이체일만 고르면, 규칙에 따라 이번달/다음달이 자동 결정돼요',
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () {
          FocusScope.of(context).unfocus();
          _openWheel();
        },
        child: Row(
          children: [
            Icon(Icons.event_available_outlined,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _firstDebitDate == null
                    ? '날짜를 선택해주세요.'
                    : '${_fmtK(_firstDebitDate!)} • ${isThisMonth ? '이번달' : '다음달'} 납입',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: kBodySize,
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
                side: BorderSide(color: theme.colorScheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadius),
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
          counterText: '',
        ),
        style: const TextStyle(fontSize: 16),
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
    final theme = Theme.of(context);
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

          final bg = selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceVariant;
          final fg = selected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface;
          final border =
              selected ? theme.colorScheme.primary : theme.colorScheme.outline;

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _select(code, label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: border),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fg,
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
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: kSubSize,
    );
    final selectedStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: kBodySize,
    );
    final placeholderStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: kBodySize,
    );

    return SectionCard(
      title: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtitle, style: subtitleStyle),
                    const SizedBox(height: 4),
                    Text(
                      selectedId ?? '선택해주세요',
                      style:
                          selectedId == null ? placeholderStyle : selectedStyle,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
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
    final theme = Theme.of(context);
    return SectionCard(
      title: '납입 기간',
      subtitle: '아래 기간 중 하나를 선택하세요',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((m) {
          final selected = value == m;
          final bg = selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceVariant;
          final fg = selected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface;
          final border =
              selected ? theme.colorScheme.primary : theme.colorScheme.outline;

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onChanged(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$m개월',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: fg,
                  fontSize: 14,
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
/// 재사용: 전체 화면 흐림 + 둥근 확인 다이얼로그
/// =======================================================
Future<T?> showFrostedConfirmDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  required List<Widget> Function(BuildContext ctx) actionsBuilder,
}) {
  final theme = Theme.of(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'dismiss',
    barrierColor: Colors.transparent, // 실제 어둡게/블러는 아래 컨테이너에서
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, a1, a2) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, __, ___) {
      final opacity = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      final scale = Tween<double>(begin: .98, end: 1.0)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack));

      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: FadeTransition(
                opacity: opacity,
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: scale,
              child: Material(
                color: theme.cardColor,
                elevation: 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kDialogRadius),
                ),
                clipBehavior: Clip.antiAlias, // 라운드 확실히 적용
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 280, maxWidth: 360),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: actionsBuilder(ctx)
                                .map((w) => Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: w,
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
