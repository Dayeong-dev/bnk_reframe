import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reframe/constants/number_format.dart'; // money.format
import 'package:reframe/model/account.dart';
import 'package:reframe/service/account_service.dart';

class MyServiceTestPage extends StatefulWidget {
  const MyServiceTestPage({super.key});
  @override
  State<MyServiceTestPage> createState() => _MyServiceTestPageState();
}

class _MyServiceTestPageState extends State<MyServiceTestPage> {
  // ===== 서버 데이터 =====
  late Future<List<Account>> _futureAccounts;
  late Future<List<_MonthlyPoint>> _futureTrend;
  late Future<UserProfile> _futureProfile;

  // ===== 상태 =====
  UserProfile? _profile;

  // ===== 적금 목표 (SharedPreferences 저장) =====
  static const _kGoalMapKey = 'saving_goal_map_v2'; // accountKey -> int
  Map<String, int> _goalMap = {};

  // 단일 대시보드에서 보여줄 "선택된 적금계좌" 인덱스
  int _selectedSavingIndex = 0;

  @override
  void initState() {
    super.initState();

    _futureAccounts = fetchAccounts(null);
    _futureProfile = _fetchProfileOrFallback();
    _loadGoalMap();

    _futureTrend = _fetchAssetTrendOrFallback();
  }

  // ===== 프로필(DB에서 이름/생년 가져오기) =====
  Future<UserProfile> _fetchProfileOrFallback() async {
    try {
      final p = await fetchUserProfile(); // ← 실제 API로 연결
      _profile = p;
      return p;
    } catch (_) {
      final p = UserProfile(name: '홍길동', birth: DateTime(1998, 9, 1));
      _profile = p;
      return p;
    } finally {
      if (mounted) setState(() {});
    }
  }

  // ===== Goal Map 저장/로드 =====
  Future<void> _loadGoalMap() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kGoalMapKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _goalMap = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {/* ignore */}
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveGoalMap() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kGoalMapKey, jsonEncode(_goalMap));
  }

  // ===== 총자산 추이 (엔드포인트 없으면 안전한 목데이터) =====
  Future<List<_MonthlyPoint>> _fetchAssetTrendOrFallback() async {
    try {
      final data = await fetchAssetTrend(); // 실제 연결 시 구현
      if (data.isNotEmpty) return data;
      throw Exception('empty trend');
    } catch (_) {
      final accounts = await _futureAccounts;
      final totalNow = _sumCash(accounts) + _sumSavings(accounts);
      final months = _recent6MonthsLabels();

      final rand = math.Random(1129);
      double base = totalNow * 0.92; // 6개월 전을 현재보다 8% 낮게 시작
      final out = <_MonthlyPoint>[];
      for (final m in months) {
        base *= (1.0 + (rand.nextDouble() * 0.02)); // 월 0~2% 증가
        out.add(_MonthlyPoint(month: m, total: base.round()));
      }
      return out;
    }
  }

  // ====== 계좌 합산 유틸 (enum만 사용) ======
  String _typeUpperFromEnum(AccountType? t) {
    if (t == null) return '';
    final s = t.toString(); // e.g. "AccountType.demand"
    final last = s.contains('.') ? s.split('.').last : s;
    return last.toUpperCase(); // "DEMAND"
  }

  bool _isCash(Account a) {
    final key = _typeUpperFromEnum(a.accountType);
    return key == 'DEMAND' || key == 'DEMAND_FREE';
  }

  bool _isSavings(Account a) {
    final key = _typeUpperFromEnum(a.accountType);
    return key == 'PRODUCT' || key == 'SAVINGS';
  }

  int _sumCash(List<Account> list) {
    var sum = 0;
    for (final a in list) {
      final bal = a.balance ?? 0;
      if (_isCash(a)) sum += bal;
    }
    return sum;
  }

  int _sumSavings(List<Account> list) {
    var sum = 0;
    for (final a in list) {
      final bal = a.balance ?? 0;
      if (_isSavings(a)) sum += bal;
    }
    return sum;
  }

  // 계좌별 goal key (accountNumber 우선, 없으면 이름, 최후엔 hash)
  String _accKey(Account a) => (a.accountNumber?.trim().isNotEmpty == true)
      ? a.accountNumber!.trim()
      : (a.accountName?.trim().isNotEmpty == true
          ? 'name:${a.accountName!.trim()}'
          : 'acc_${a.hashCode}');

  // 최근 6개월 라벨 (MM)
  List<String> _recent6MonthsLabels() {
    final now = DateTime.now();
    final out = <String>[];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      out.add(d.month.toString().padLeft(2, '0'));
    }
    return out;
  }

  // ===== 목표 설정 바텀시트 (계좌별) =====
  void _openGoalSheetFor(Account acc) {
    final key = _accKey(acc);
    final currentGoal = _goalMap[key] ?? 0;
    final ctrl = TextEditingController(
        text: currentGoal == 0 ? '' : currentGoal.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withOpacity(0.5),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 16 + MediaQuery.of(c).viewInsets.bottom,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(999))),
                Row(
                  children: [
                    Expanded(
                      child: Text(acc.accountName ?? '적금 목표 설정',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                      hintText: '목표 금액 (원)',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final raw =
                              ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                          final v = int.tryParse(raw) ?? 0;
                          setState(() {
                            if (v <= 0) {
                              _goalMap.remove(key);
                            } else {
                              _goalMap[key] = v;
                            }
                          });
                          _saveGoalMap();
                          Navigator.pop(c);
                        },
                        child: const Text('저장'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _goalMap.remove(key);
                          });
                          _saveGoalMap();
                          Navigator.pop(c);
                        },
                        child: const Text('목표 제거'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== 적금 선택 보조: 좌/우 이동 =====
  void _selectPrevSaving(List<Account> savings) {
    if (savings.isEmpty) return;
    setState(() {
      _selectedSavingIndex =
          (_selectedSavingIndex - 1 + savings.length) % savings.length;
    });
  }

  void _selectNextSaving(List<Account> savings) {
    if (savings.isEmpty) return;
    setState(() {
      _selectedSavingIndex = (_selectedSavingIndex + 1) % savings.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 내비바까지 배경이 자연스럽게 보이도록
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('내 자산 요약'), centerTitle: true),
      body: SafeArea(
        bottom: true,
        child: FutureBuilder<List<Account>>(
          future: _futureAccounts,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorBox(
                message: '계좌 정보를 불러오지 못했습니다.',
                detail: '${snap.error}',
                onRetry: () =>
                    setState(() => _futureAccounts = fetchAccounts(null)),
              );
            }

            final accounts = snap.data ?? [];
            final savings = accounts.where(_isSavings).toList();
            final cashSum = _sumCash(accounts);
            final depositSum = _sumSavings(accounts);
            final total = cashSum + depositSum;

            final safeTotal = total == 0 ? 1 : total;
            final cashRatio = (cashSum / safeTotal).clamp(0.0, 1.0);
            final depositRatio = (depositSum / safeTotal).clamp(0.0, 1.0);

            final name = _profile?.name ?? '홍길동';
            final birth = _profile?.birth ?? DateTime(1998, 9, 1);
            final age = _calcAge(birth);

            final bottomPadding = MediaQuery.of(context).padding.bottom +
                kBottomNavigationBarHeight +
                16;

            // 현재 선택된 적금 인덱스 보정(리스트 변동 대비)
            if (_selectedSavingIndex >= savings.length && savings.isNotEmpty) {
              _selectedSavingIndex = savings.length - 1;
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              children: [
                // ===== 0) 상단 총자산 카드 =====
                _TopSummaryCard(
                  title: '$name님(만 $age세)',
                  total: total,
                  cashRatio: cashRatio,
                  depositRatio: depositRatio,
                  cashSum: cashSum,
                  depositSum: depositSum,
                ),
                const SizedBox(height: 16),

                // ===== 1) 총자산 추이 =====
                FutureBuilder<List<_MonthlyPoint>>(
                  future: _futureTrend,
                  builder: (context, tsnap) {
                    final months = _recent6MonthsLabels();
                    final series = tsnap.data ?? const <_MonthlyPoint>[];
                    final baseValues = series.isEmpty
                        ? List.filled(6, total)
                        : series.map((e) => e.total).toList();

                    // n < 2 가드: 최소 2개로 복제
                    final values = (baseValues.length >= 2)
                        ? baseValues
                        : (baseValues.isEmpty
                            ? [0, 0]
                            : [baseValues.first, baseValues.first]);

                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('총자산 추이 (최근 6개월)',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 240,
                              child: _LineChartAdvanced(
                                labels: months,
                                values: values,
                                lineColor: const Color(0xFF7C88FF),
                              ),
                            ),
                            if (tsnap.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('트렌드 데이터를 불러오지 못해 임시값을 표시합니다.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.red)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // ===== 2) 내 적금 목표 (단일 카드 + 전환) =====
                const _SectionTitle('내 적금 목표'),
                const SizedBox(height: 8),
                if (savings.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('등록된 예·적금 계좌가 없습니다.'),
                    ),
                  )
                else
                  _SingleSavingGoalCard(
                    savings: savings,
                    index: _selectedSavingIndex,
                    goalMap: _goalMap,
                    accKey: _accKey,
                    onTapPrev: () => _selectPrevSaving(savings),
                    onTapNext: () => _selectNextSaving(savings),
                    onOpenSheet: _openGoalSheetFor,
                  ),

                // ===== (요청 3) 벤치마크 위젯 제거됨 =====
              ],
            );
          },
        ),
      ),
    );
  }
}

// ========================= 공용 위젯/그리기 =========================

class _ErrorBox extends StatelessWidget {
  final String message;
  final String? detail;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, this.detail, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
}

class _TopSummaryCard extends StatelessWidget {
  final String title;
  final int total;
  final double cashRatio;
  final double depositRatio;
  final int cashSum;
  final int depositSum;

  const _TopSummaryCard({
    required this.title,
    required this.total,
    required this.cashRatio,
    required this.depositRatio,
    required this.cashSum,
    required this.depositSum,
  });

  @override
  Widget build(BuildContext context) {
    const cashColor = Color(0xFF40C4FF);
    const depositColor = Color(0xFF7C88FF);
    const barBg = Color(0xFFEBEDF0);

    String pct(double v) => '${(v * 100).toStringAsFixed(0)}%';

    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(radius: 16, child: Icon(Icons.person)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 10),
            Text('${money.format(total)} 원',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 16,
                child: Stack(children: [
                  Container(color: barBg),
                  FractionallySizedBox(
                      widthFactor: cashRatio,
                      child: Container(color: cashColor)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: depositRatio,
                      alignment: Alignment.centerRight,
                      child: Container(color: depositColor),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Text('현금성 ${pct(cashRatio)}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              const Text('·', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text('예·적금 ${pct(depositRatio)}',
                  style: const TextStyle(fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 14, runSpacing: 4, children: [
              _LegendDot(color: cashColor, label: '현금성', amount: cashSum),
              _LegendDot(
                  color: depositColor, label: '예·적금', amount: depositSum),
            ]),
          ],
        ),
      ),
    );
  }
}

// ===== 단일 적금 목표 카드(전환 UI 포함) =====
class _SingleSavingGoalCard extends StatelessWidget {
  final List<Account> savings;
  final int index;
  final Map<String, int> goalMap;
  final String Function(Account) accKey;
  final VoidCallback onTapPrev;
  final VoidCallback onTapNext;
  final void Function(Account) onOpenSheet;

  const _SingleSavingGoalCard({
    required this.savings,
    required this.index,
    required this.goalMap,
    required this.accKey,
    required this.onTapPrev,
    required this.onTapNext,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    final acc = savings[index];
    final bal = acc.balance ?? 0;
    final key = accKey(acc);
    final goal = goalMap[key] ?? 0;
    final ratio = goal <= 0 ? 0.0 : (bal / goal).clamp(0.0, 1.0);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            // 상단: 좌우 이동 + 드롭다운으로 계좌 전환
            Row(
              children: [
                IconButton(
                  tooltip: '이전',
                  onPressed: onTapPrev,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: _SavingDropdown(
                    savings: savings,
                    selectedIndex: index,
                    onChangedIndex: (i) {
                      // 외부 setState를 쓰지 않으므로 Navigator trick 없이
                      // 부모가 setState 하도록 요구되면 구조를 상태ful로 옮길 수 있음.
                      // 여기서는 간단히 하도록, onChangedIndex는 상위에서 처리하는게 이상적.
                      // 다만 지금 한 파일에서 바로 쓰려면, InkWell 가이드로만 구성.
                    },
                  ),
                ),
                IconButton(
                  tooltip: '다음',
                  onPressed: onTapNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: _GaugeProgressAnimated(
                    ratio: ratio,
                    color: const Color(0xFF7C88FF),
                    label: '진행률',
                    duration: const Duration(milliseconds: 700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(acc.accountName ?? '예·적금',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        goal <= 0
                            ? '목표를 설정해 주세요'
                            : '${money.format(bal)} 원 / ${money.format(goal)} 원',
                        style: TextStyle(
                            fontSize: 12, color: Colors.black.withOpacity(.6)),
                      ),
                      const SizedBox(height: 8),
                      _LinearProgressAnimated(
                        ratio: ratio,
                        color: const Color(0xFF7C88FF),
                        height: 10,
                        duration: const Duration(milliseconds: 600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.flag),
                  label: const Text('설정'),
                  onPressed: () => onOpenSheet(acc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 드롭다운(표시만 담당, 선택 변경은 상위에서 처리 권장)
class _SavingDropdown extends StatelessWidget {
  final List<Account> savings;
  final int selectedIndex;
  final void Function(int) onChangedIndex;
  const _SavingDropdown({
    required this.savings,
    required this.selectedIndex,
    required this.onChangedIndex,
  });
  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      isExpanded: true,
      value: selectedIndex,
      items: [
        for (int i = 0; i < savings.length; i++)
          DropdownMenuItem(
            value: i,
            child: Text(
              savings[i].accountName ?? '예·적금 ${i + 1}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        // 현재 파일 구조에서는 상위 setState 접근이 어려우므로, 간단히
        // SnackBar로 안내만 하고 좌우 버튼 사용을 권장.
        // 필요 시 이 드롭다운을 Stateful로 승격해 콜백 연결하면 됨.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('좌/우 버튼으로 계좌를 전환하세요. (드롭다운 즉시전환은 추후 연결)'),
            duration: Duration(milliseconds: 900),
          ),
        );
        onChangedIndex(v);
      },
    );
  }
}

// 반원 게이지 (애니메이션 지원)
class _GaugeProgressAnimated extends StatelessWidget {
  final double ratio;
  final Color color;
  final String label;
  final Duration duration;
  const _GaugeProgressAnimated({
    required this.ratio,
    required this.color,
    required this.label,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, value, __) {
        return CustomPaint(
          painter: _GaugePainter(ratio: value, color: color),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${(value * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ]),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double ratio;
  final Color color;
  _GaugePainter({required this.ratio, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 8;
    final bg = Paint()
      ..color = const Color(0xFFEFF1F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final start = math.pi; // 왼쪽부터
    const sweepAll = math.pi;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), start, sweepAll, false, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start,
        sweepAll * ratio.clamp(0, 1), false, fg);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.ratio != ratio || old.color != color;
}

// 선형 진행바 (애니메이션 지원)
class _LinearProgressAnimated extends StatelessWidget {
  final double ratio; // 0.0 ~ 1.0
  final Color color;
  final double height;
  final Duration duration;

  const _LinearProgressAnimated({
    required this.ratio,
    required this.color,
    this.height = 10,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Container(color: const Color(0xFFE9ECF1)), // 배경 트랙
                FractionallySizedBox(
                  widthFactor: v,
                  child: Container(color: color), // 진행 구간
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 범례
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final int amount;
  const _LegendDot(
      {required this.color, required this.label, required this.amount});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('$label  ${money.format(amount)}원',
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

// ========================= 라인차트(깔끔한 단위 Y축) =========================

class _LineChartAdvanced extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final Color lineColor;
  const _LineChartAdvanced(
      {required this.labels, required this.values, required this.lineColor});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartAdvancedPainter(
          labels: labels, values: values, lineColor: lineColor),
      child: Container(),
    );
  }
}

class _LineChartAdvancedPainter extends CustomPainter {
  final List<String> labels;
  final List<int> values;
  final Color lineColor;
  _LineChartAdvancedPainter(
      {required this.labels, required this.values, required this.lineColor});

  // 10만 / 100만 / 1000만 … 같은 "깔끔한 단위"를 자동 선택
  int _pickNiceStep(int minV, int maxV) {
    final span = (maxV - minV).abs();
    // span이 너무 작아도 최소 단위 유지
    const candidates = <int>[
      100000, // 10만
      200000,
      500000,
      1000000, // 100만
      2000000,
      5000000,
      10000000, // 1000만
      20000000,
      50000000,
      100000000, // 1억
      200000000,
      500000000,
      1000000000, // 10억
    ];
    // 목표: 4~6칸 사이로 보이게 적당한 step 선택
    for (final s in candidates) {
      final tickCount = (span / s).ceil();
      if (tickCount >= 4 && tickCount <= 6) return s;
    }
    // 못 찾으면 span을 5등분
    final approx = (span / 5).clamp(1, 1 << 31).toInt();
    // approx를 가장 가까운 candidate로 올림
    for (final s in candidates) {
      if (s >= approx) return s;
    }
    return candidates.last;
  }

  // Y축 라벨 포맷: 10만 / 100만 / 1000만 / 1억 / 10억 …
  String _formatKoreanShort(int v) {
    if (v >= 1000000000) {
      // 10억 이상
      final n = (v / 100000000).toStringAsFixed(0); // 억 단위
      return '${n}억';
    } else if (v >= 100000000) {
      // 1억 이상
      final n = (v / 100000000).toStringAsFixed(0);
      return '${n}억';
    } else if (v >= 10000000) {
      // 1000만 이상
      final n = (v / 10000).toStringAsFixed(0); // 만원 단위로 표현하면 숫자 큼
      // 1000만은 그냥 '1000만' 식으로 보여주기
      return '${(v / 10000).toStringAsFixed(0)}만';
    } else if (v >= 1000000) {
      // 100만 이상
      return '${(v / 10000).toStringAsFixed(0)}만';
    } else if (v >= 100000) {
      // 10만 이상
      return '${(v / 10000).toStringAsFixed(0)}만';
    }
    // 그 외는 그냥 천 단위 콤마
    return money.format(v);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paddingLeft = 56.0; // Y축 라벨 영역
    const paddingRight = 12.0;
    const paddingTop = 12.0;
    const paddingBottom = 28.0; // X축 라벨 영역
    final chartW = size.width - paddingLeft - paddingRight;
    final chartH = size.height - paddingTop - paddingBottom;

    if (chartW <= 0 || chartH <= 0 || values.isEmpty) return;

    // 축/가이드 스타일
    final axis = Paint()
      ..color = const Color(0xFFCBD3DF)
      ..strokeWidth = 1.2;
    final guide = Paint()
      ..color = const Color(0xFFE9ECF1)
      ..strokeWidth = 1;

    // 값 범위
    int maxValI = values.reduce(math.max);
    int minValI = values.reduce(math.min);
    if (maxValI == minValI) {
      maxValI += 1;
      minValI = (minValI - 1).clamp(0, 1 << 31);
    }

    final step = _pickNiceStep(minValI, maxValI);
    // 아래/위로 step의 배수까지 확장(그래프 여백 상향)
    final yMin = (minValI / step).floor() * step;
    final yMax = (maxValI / step).ceil() * step;

    final span = (yMax - yMin).toDouble();
    final ticks = <int>[];
    for (int v = yMin; v <= yMax; v += step) {
      ticks.add(v);
    }

    double yForVal(num v) => paddingTop + chartH - ((v - yMin) / span) * chartH;
    double xForIndex(int i) {
      final n = values.length;
      final denom = (n - 1) == 0 ? 1 : (n - 1);
      return paddingLeft + chartW * (i / denom);
    }

    // 가이드 + Y축 라벨
    final txtStyle = const TextStyle(fontSize: 10, color: Colors.black54);
    for (final t in ticks) {
      final y = yForVal(t);
      canvas.drawLine(
          Offset(paddingLeft, y), Offset(paddingLeft + chartW, y), guide);
      final label = _formatKoreanShort(t);
      final tp = TextPainter(
        text: TextSpan(text: label, style: txtStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: paddingLeft - 8);
      tp.paint(canvas, Offset(paddingLeft - 8 - tp.width, y - tp.height / 2));
    }

    // 축선 (X, Y)
    canvas.drawLine(Offset(paddingLeft, paddingTop),
        Offset(paddingLeft, paddingTop + chartH), axis);
    canvas.drawLine(Offset(paddingLeft, paddingTop + chartH),
        Offset(paddingLeft + chartW, paddingTop + chartH), axis);

    // 선 경로
    final pt = (int i) => Offset(xForIndex(i), yForVal(values[i]));
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, line);

    // 포인트 + 금액 라벨
    final dot = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final valStyle = const TextStyle(
        fontSize: 9, color: Colors.black87, fontWeight: FontWeight.w600);
    for (int i = 0; i < values.length; i++) {
      final p = pt(i);
      canvas.drawCircle(p, 3.5, dot);

      final lbl = money.format(values[i]);
      final tp = TextPainter(
        text: TextSpan(text: lbl, style: valStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height - 6));
    }

    // X축 라벨
    final xStyle = const TextStyle(fontSize: 10, color: Colors.black54);
    for (int i = 0; i < labels.length; i++) {
      final x = xForIndex(i);
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: xStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, paddingTop + chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartAdvancedPainter old) =>
      old.labels != labels ||
      old.values != values ||
      old.lineColor != lineColor;
}

// ========================= 모델/유틸 =========================

class _MonthlyPoint {
  final String month; // '03' '04' ...
  final int total; // 월별 총자산
  const _MonthlyPoint({required this.month, required this.total});
}

int _calcAge(DateTime birth) {
  final now = DateTime.now();
  int age = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) age--;
  return math.max(age, 0);
}

// ========================= 서버 연동 가정 함수들 =========================

Future<List<_MonthlyPoint>> fetchAssetTrend() async {
  throw UnimplementedError('asset trend endpoint not connected yet');
}

Future<UserProfile> fetchUserProfile() async {
  throw UnimplementedError('profile endpoint not connected yet');
}

class UserProfile {
  final String name;
  final DateTime birth;
  UserProfile({required this.name, required this.birth});
}
