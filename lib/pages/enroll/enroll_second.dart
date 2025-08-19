import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reframe/constants/color.dart';
import 'package:reframe/model/enroll_form.dart';
import 'package:reframe/model/product_input_format.dart';
import 'package:reframe/pages/enroll/appbar.dart';
import 'package:reframe/pages/enroll/enroll_third.dart';
import 'package:reframe/model/group_type.dart';

class SecondStepPage extends StatefulWidget {
  const SecondStepPage({
    super.key,
    required this.productName,
    required this.productInput,
  });

  final String productName;
  final ProductInputFormat productInput;

  @override
  State<SecondStepPage> createState() => _SecondStepPageState();
}

class _SecondStepPageState extends State<SecondStepPage> {
  final _formKey = GlobalKey<FormState>();
  final EnrollForm _data = EnrollForm();

  @override
  void initState() {
    // input1 (납입 기간)
    if (widget.productInput.input1 && _data.periodMonths == null) {
      _data.periodMonths = 12;
    }

    // input2 (납입 금액)
    if (widget.productInput.input2 && _data.paymentAmount == null) {
      _data.paymentAmount = 5;
    }

    super.initState();
  }

  bool _isValidAnchor(int? a) {
    if (a == null) return false;
    if (a == kLastDay) return true;
    return a >= 1 && a <= 31;
  }

  static const int _minMonths = 1;
  static const int _maxMonths = 60;
  static const int _minAmount = 5;     // 만원
  static const int _maxAmount = 1000;  // 만원

  List<String> _validate() {
    final errs = <String>[];

    if (widget.productInput.input1) {
      final v = _data.periodMonths;
      if (v == null || v < _minMonths || v > _maxMonths) {
        errs.add('납입 기간을 ${_minMonths}~${_maxMonths}개월로 선택해 주세요.');
      }
    }

    if (widget.productInput.input2) {
      final v = _data.paymentAmount;
      if (v == null || v < _minAmount || v > _maxAmount) {
        errs.add('납입 금액을 ${_minAmount}~${_maxAmount}만원으로 입력해 주세요.');
      }
    }

    if (widget.productInput.input3) {
      if (!_isValidAnchor(_data.transferDate)) {
        errs.add('이체일(앵커)을 선택해 주세요.');
      }
    }

    if (widget.productInput.fromAccountReq) {
      if (_data.fromAccountId == null || _data.fromAccountId!.isEmpty) {
        errs.add('출금 계좌를 선택해 주세요.');
      }
    }

    if (widget.productInput.maturityAccountReq) {
      if (_data.maturityAccountId == null || _data.maturityAccountId!.isEmpty) {
        errs.add('만기 입금 계좌를 선택해 주세요.');
      }
    }

    if (widget.productInput.input7) {
      final name = _data.groupName?.trim() ?? '';
      if (name.isEmpty) {
        errs.add('모임 이름을 입력해 주세요.');
      } else if (name.length > 20) {
        errs.add('모임 이름은 20자 이내로 입력해 주세요.');
      }
    }

    if (widget.productInput.input8) {
      if (_data.groupType == null || _data.groupType!.isEmpty) {
        errs.add('모임 구분을 선택해 주세요.');
      }
    }
    return errs;
  }

  bool get _canSubmit => _validate().isEmpty;

  void _nextStep() {
    final errs = _validate();
    if (errs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errs.first)),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => ThirdStepPage(productName: '상품명', enrollForm: _data)));
  }

  final  _accounts = const [
    {'id': 'A-1111', 'account_number': '112-1111-1111-11', 'bank_name': '부산은행', 'balance': 300000},
    {'id': 'A-2222', 'account_number': '112-2222-1111-11', 'bank_name': '부산은행', 'balance': 500000},
    {'id': 'A-3333', 'account_number': '112-3333-1111-11', 'bank_name': '부산은행', 'balance': 800000},
  ];

  Future<Map<String, Object>?> _pickAccount(String title) async {
    return await showModalBottomSheet<Map<String, Object>>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._accounts.map((a) => ListTile(
                title: Text('${a['bank_name']!} ${a['account_number']!}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, a),
              )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor2,
      appBar: buildAppBar(context),
      bottomNavigationBar: _BottomButton(enabled: _canSubmit, onPressed: _nextStep),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          children: [
            // 상품 이름
            Text(widget.productName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),

            // 납입 기간
            if (widget.productInput.input1)
              PeriodSection(
                value: _data.periodMonths!,
                min: 1,
                max: 60,
                onChanged: (v) => setState(() => _data.periodMonths = v),
              ),
            const SizedBox(height: 12),

            // 납입 금액
            if (widget.productInput.input2)
              AmountSection(
                value: _data.paymentAmount!,
                min: 5,
                max: 1000,
                onChanged: (v) => setState(() => _data.paymentAmount = v),
              ),
            const SizedBox(height: 12),

            // 납입 일정
            if (widget.productInput.input3)
              CupertinoMonthlyWheel(onChanged: (firstDebitDate, int anchor) {
                setState(() {
                  _data.transferDate = anchor;
                });
              }),
            const SizedBox(height: 12),

            // 출금 계좌
            if (widget.productInput.fromAccountReq)
              AccountPickerSection(
                title: '출금 계좌',
                subtitle: '월 납입 출금 계좌',
                selectedId: _data.fromAccountId,
                onPick: () async {
                  final account = await _pickAccount('출금 계좌 선택');
                  if (account != null) setState(() => _data.fromAccountId = account['id'] as String);
                },
              ),
            const SizedBox(height: 12),

            // 만기 시 입금 계좌
            if (widget.productInput.maturityAccountReq)
              AccountPickerSection(
                title: '만기 계좌',
                subtitle: '만기 입금 계좌',
                selectedId: _data.maturityAccountId,
                onPick: () async {
                  final account = await _pickAccount('만기 시 입금 계좌 선택');
                  if (account != null) setState(() => _data.maturityAccountId = account['id'] as String);
                },
              ),
            const SizedBox(height: 12),

            // 모임 이름
            if (widget.productInput.input7)
              GroupNameSection(
                value: _data.groupName ?? '',
                onChanged: (v) => setState(() => _data.groupName = v),
              ),
            const SizedBox(height: 12),

            // 모임 구분
            if (widget.productInput.input8)
              GroupTypeSection(selectedCode: '', onChanged: (String code, String label) {
                setState(() {
                  _data.groupType = code;
                });;
              }),
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
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding:
        EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: TextStyle(color: Colors.black45)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// 납입 기간 섹션
class PeriodSection extends StatelessWidget {
  const PeriodSection({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.divisions, });

  final int value;  // months
  final int min;
  final int max;
  final int? divisions;

  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value.toString());

    return SectionCard(
      title: '납입 기간',
      subtitle: '원하는 기간을 선택하세요',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions ?? (max - min),
            label: '$value개월',
            inactiveColor: Colors.black12,
            onChanged: (v) => onChanged(v.round()),
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: '개월 수 직접입력',
                      labelStyle: TextStyle(
                          color: Colors.grey[500]
                      ),
                      isDense: true,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black12)
                      ),
                      errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black12)
                      ),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black)
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black)
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= min && n <= max) onChanged(n);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('개월'),
            ],
          ),
        ],
      ),
    );
  }
}

// 납입 금액 섹션
class AmountSection extends StatelessWidget {
  const AmountSection({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.divisions, });

  final int value;  // months
  final int min;
  final int max;
  final int? divisions;

  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value.toString());

    return SectionCard(
      title: '납입 금액',
      subtitle: '납입 금액을 입력하세요',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: '월 납입 금액(원)',
                      hintStyle: TextStyle(
                          color: Colors.grey[500]
                      ),
                      isDense: true,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black12)
                      ),
                      errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black12)
                      ),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black)
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black)
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= min && n <= max) onChanged(n);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('만원'),
            ],
          ),
        ],
      ),
    );
  }
}

// 납입 일정 섹션
const int kLastDay = 99; // '말일' 표시용

class CupertinoMonthlyWheel extends StatefulWidget {
  const CupertinoMonthlyWheel({
    super.key,
    this.onChanged,
    this.useAllDays31 = false, // true면 1~31, false면 1~28 + 말일
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
      if (t.day <= lastThis) return DateTime(t.year, t.month, lastThis); // 오늘이 말일이어도 이번달
      final lastNext = _lastDayOfMonth(t.year, t.month + 1);
      return DateTime(t.year, t.month + 1, lastNext);
    } else {
      if (anchor >= t.day) {
        final lastThis = _lastDayOfMonth(t.year, t.month);
        final day = anchor.clamp(1, lastThis);
        return DateTime(t.year, t.month, day);
      } else {
        final lastNext = _lastDayOfMonth(t.year, t.month + 1);
        final day = anchor.clamp(1, lastNext);
        return DateTime(t.year, t.month + 1, day);
      }
    }
  }

  List<_WheelItem> _dayItems() {
    if (widget.useAllDays31) {
      return List.generate(31, (i) => _WheelItem(i + 1, '${i + 1}일'));
    }
    // 정책 기본: 1~28 + 말일
    return [
      ...List.generate(28, (i) => _WheelItem(i + 1, '${i + 1}일')),
      const _WheelItem(kLastDay, '말일'),
    ];
  }

  String _fmt(DateTime d) {
    const wk = ['월','화','수','목','금','토','일'];
    return '${d.year}.${d.month}.${d.day}(${wk[d.weekday - 1]})';
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
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('이체일 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: CupertinoPicker(
                      itemExtent: 40,
                      scrollController: FixedExtentScrollController(initialItem: initialIndex),
                      onSelectedItemChanged: (i) { tempIndex = i; recompute(); },
                      children: items.map((e) => Center(child: Text(e.label, style: const TextStyle(fontSize: 16)))).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 미리보기
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff2f4f6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.event_available_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text('첫 이체일: ${_fmt(tempFirst)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        (tempFirst.month == _today.month) ? '이번달 납입' : '다음달 납입',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
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
                          child: const Text('확인'),
                        ),
                      ),
                    ],
                  ),
                ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.event_available_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _firstDebitDate == null
                    ? '날짜를 선택해주세요.'
                    : '${_fmt(_firstDebitDate!)} • ${(_firstDebitDate!.month == _today.month) ? '이번달' : '다음달'} 납입',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _openWheel,
              style: FilledButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('선택', style: TextStyle(color: Colors.white)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _WheelItem {
  final int value;
  final String label;
  const _WheelItem(this.value, this.label);
}

// 모임 이름 섹션
class GroupNameSection extends StatefulWidget {

  const GroupNameSection({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<GroupNameSection> createState() => _GroupNameSectionState();
}

class _GroupNameSectionState extends State<GroupNameSection> {
  TextEditingController? controller;

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
        decoration: InputDecoration(
          hintText: '예) 제주도 여행 모임',
          hintStyle: TextStyle(
            color: Colors.grey[500]
          ),
          isDense: true,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black12)
          ),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black12)
          ),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black)
          ),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black)
          ),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

// 모임 구분 섹션
class GroupTypeSection extends StatefulWidget {
  const GroupTypeSection({
    super.key,
    required this.selectedCode,     // 현재 선택 코드 (없으면 null)
    required this.onChanged,        // (code, label?) 콜백
  });

  final String? selectedCode;       // 'CLUB' | 'DATE' | ... | 'ETC' | null
  final void Function(String code, String label) onChanged;

  @override
  State<GroupTypeSection> createState() => _GroupTypeSectionState();
}

class _GroupTypeSectionState extends State<GroupTypeSection> {
  late String? _code = widget.selectedCode;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _select(String code, String label) {
    setState(() => _code = code);
    widget.onChanged(code, label);
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '모임 구분',
      subtitle: '목적에 맞는 구분을 선택하세요',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: groupType.entries.map((e) {
              final code = e.key;
              final label = e.value;
              final selected = _code == code;

              return RawChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => _select(code, label),
                showCheckmark: false,
                labelPadding: const EdgeInsets.all(8),
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black,
                ),
                backgroundColor: Colors.grey[100],
                selectedColor: primaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// 계좌 선택 섹션
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
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(subtitle),
        subtitle: Text(
          selectedId ?? '선택해주세요',
          style: TextStyle(color: selectedId == null ? Colors.grey[600] : Colors.black),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPick,
      ),
    );
  }
}
