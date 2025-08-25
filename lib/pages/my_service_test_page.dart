import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reframe/constants/number_format.dart'; // money.format
import 'package:reframe/model/account.dart';
import 'package:reframe/service/account_service.dart';

/// 대시보드 중심 페이지:
/// - 이름/생년: DB(API)에서 fetchUserProfile() → 실패 시 로컬 fallback
/// - "내 계좌" 섹션 제거
/// - 자산추이(최근 6개월) → 목표달성률 → 자산 분포 → 내 비중 vs 벤치마크(맨 아래)

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

  // ===== 목표금액 (SharedPreferences 저장) =====
  static const _kGoalKey = 'saving_goal_amount';
  int _savingGoal = 10000000; // 초깃값
  int _savingNow = 0; // 예·적금(상품) 잔액 합계

  // ===== 벤치마크 (세그먼트 전환) =====
  String _selectedSegment = '20대 남성';
  _Benchmark? _bm; // 서버 연결 성공 시 사용, 실패 시 로컬 상수 fallback

  @override
  void initState() {
    super.initState();

    _futureAccounts = fetchAccounts(null);
    _futureProfile = _fetchProfileOrFallback();
    _loadGoal();

    // 예적금 합계 계산 → 상태 반영
    _futureAccounts.then((accounts) {
      _savingNow = _sumSavings(accounts);
      if (mounted) setState(() {});
    });

    // 총자산 추이
    _futureTrend = _fetchAssetTrendOrFallback();

    // 벤치마크
    _fetchBenchmarkOrFallback(_selectedSegment);
  }

  // ===== 프로필(DB에서 이름/생년 가져오기) =====
  Future<UserProfile> _fetchProfileOrFallback() async {
    try {
      final p = await fetchUserProfile(); // ← 실제 API로 연결 (아래에 TODO)
      _profile = p;
      return p;
    } catch (_) {
      // 안전한 기본값
      final p = UserProfile(name: '홍길동', birth: DateTime(1998, 9, 1));
      _profile = p;
      return p;
    } finally {
      if (mounted) setState(() {});
    }
  }

  // ===== 벤치마크 =====
  Future<void> _fetchBenchmarkOrFallback(String segment) async {
    try {
      final bm = await fetchBenchmark(segment); // ← DB/엔드포인트 연결 가정
      if (mounted) setState(() => _bm = bm);
    } catch (_) {
      if (mounted) setState(() => _bm = _benchmarksLocal[segment]);
    }
  }

  // ===== Goal 저장/로드 =====
  Future<void> _loadGoal() async {
    final sp = await SharedPreferences.getInstance();
    setState(() => _savingGoal = sp.getInt(_kGoalKey) ?? _savingGoal);
  }

  Future<void> _saveGoal(int v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kGoalKey, v);
    setState(() => _savingGoal = v);
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Account>>(
      future: _futureAccounts,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body:
                  SafeArea(child: Center(child: CircularProgressIndicator())));
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('내 자산 요약'), centerTitle: true),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    const Text('계좌 정보를 불러오지 못했습니다.'),
                    const SizedBox(height: 10),
                    Text('${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _futureAccounts = fetchAccounts(null)),
                      child: const Text('다시 시도'),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }

        final accounts = snap.data ?? [];
        final cashSum = _sumCash(accounts);
        final depositSum = _sumSavings(accounts);
        final total = cashSum + depositSum;

        final safeTotal = total == 0 ? 1 : total;
        final cashRatio = (cashSum / safeTotal).clamp(0.0, 1.0);
        final depositRatio = (depositSum / safeTotal).clamp(0.0, 1.0);

        final name = _profile?.name ?? '홍길동';
        final birth = _profile?.birth ?? DateTime(1998, 9, 1);
        final age = _calcAge(birth);
        final goalRatio =
            (_savingNow / (_savingGoal == 0 ? 1 : _savingGoal)).clamp(0.0, 1.0);

        final bottomPadding = MediaQuery.of(context).padding.bottom +
            kBottomNavigationBarHeight +
            16;

        return Scaffold(
          appBar: AppBar(title: const Text('내 자산 요약'), centerTitle: true),
          body: SafeArea(
            bottom: true,
            child: ListView(
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

                // ===== 1) 총자산 추이 (맨 위로 올림) =====
                FutureBuilder<List<_MonthlyPoint>>(
                  future: _futureTrend,
                  builder: (context, tsnap) {
                    final months = _recent6MonthsLabels();
                    final series = tsnap.data ?? const <_MonthlyPoint>[];
                    final values = series.isEmpty
                        ? List.filled(6, total)
                        : series.map((e) => e.total).toList();

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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 220,
                                child: _LineChart(
                                    labels: months,
                                    values: values,
                                    lineColor: const Color(0xFF7C88FF)),
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
                            ]),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // ===== 2) 목표달성률 =====
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: _GaugeProgress(
                            ratio: goalRatio,
                            color: const Color(0xFF7C88FF),
                            label: '적금 목표',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('적금 목표 달성률',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                  '${money.format(_savingNow)} 원 / ${money.format(_savingGoal)} 원',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                                const SizedBox(height: 10),
                                _LinearProgress(
                                    ratio: goalRatio,
                                    color: const Color(0xFF7C88FF),
                                    height: 14),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: _openGoalSheet,
                                    icon: const Icon(Icons.flag),
                                    label: const Text('목표 설정'),
                                  ),
                                ),
                              ]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ===== 3) 자산 분포 (도넛) =====
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('자산 분포',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 160,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _DonutChart(slices: [
                                    _Slice(
                                        ratio: cashRatio,
                                        color: const Color(0xFF40C4FF)),
                                    _Slice(
                                        ratio: depositRatio,
                                        color: const Color(0xFF7C88FF)),
                                  ]),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _LegendDot(
                                        color: const Color(0xFF40C4FF),
                                        label: '현금성',
                                        amount: cashSum),
                                    const SizedBox(height: 8),
                                    _LegendDot(
                                        color: const Color(0xFF7C88FF),
                                        label: '예·적금',
                                        amount: depositSum),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ]),
                  ),
                ),
                const SizedBox(height: 16),

                // ===== 4) 내 비중 vs 벤치마크 (맨 아래) =====
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Expanded(
                              child: Text('내 비중 vs 벤치마크',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                            ),
                            PopupMenuButton<String>(
                              initialValue: _selectedSegment,
                              onSelected: (v) {
                                setState(() => _selectedSegment = v);
                                _fetchBenchmarkOrFallback(v);
                              },
                              itemBuilder: (c) => _benchmarksLocal.keys
                                  .map((k) =>
                                      PopupMenuItem(value: k, child: Text(k)))
                                  .toList(),
                              child: Row(children: [
                                Text(_selectedSegment,
                                    style: const TextStyle(fontSize: 12)),
                                const Icon(Icons.keyboard_arrow_down, size: 18),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          _CompareRow(
                            label: '현금성',
                            mine: cashRatio,
                            bm: (_bm ?? _benchmarksLocal[_selectedSegment]!)
                                .cash,
                            color: const Color(0xFF40C4FF),
                          ),
                          const SizedBox(height: 10),
                          _CompareRow(
                            label: '예·적금',
                            mine: depositRatio,
                            bm: (_bm ?? _benchmarksLocal[_selectedSegment]!)
                                .deposit,
                            color: const Color(0xFF7C88FF),
                          ),
                        ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== 목표 설정 바텀시트 =====
  void _openGoalSheet() {
    final ctrl = TextEditingController(text: _savingGoal.toString());
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 16 + MediaQuery.of(c).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('목표 금액 설정',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '예: 10000000',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final raw = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                      final v = int.tryParse(raw) ?? _savingGoal;
                      _saveGoal(v);
                      Navigator.pop(c);
                    },
                    child: const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========================= 위젯/그리기 =========================

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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(radius: 16, child: Icon(Icons.person)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            Text('${money.format(total)} 원',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 18,
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
            const SizedBox(height: 8),
            Row(children: [
              Text('현금성 ${pct(cashRatio)}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              const Text('·', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text('예·적금 ${pct(depositRatio)}',
                  style: const TextStyle(fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 6, children: [
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

// 게이지(반원)
class _GaugeProgress extends StatelessWidget {
  final double ratio;
  final Color color;
  final String label;
  const _GaugeProgress(
      {required this.ratio, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GaugePainter(ratio: ratio, color: color),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${(ratio * 100).toStringAsFixed(0)}%',
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      ),
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
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
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

// 도넛
class _DonutChart extends StatelessWidget {
  final List<_Slice> slices;
  const _DonutChart({required this.slices});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutPainter(slices),
      child: Center(
        child: Text('분포',
            style: TextStyle(
                color: Colors.black.withOpacity(.55),
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  _DonutPainter(this.slices);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final bg = Paint()
      ..color = const Color(0xFFEFF1F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawCircle(center, radius, bg);
    double start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.ratio.clamp(0.0, 1.0) * 2 * math.pi;
      final p = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 18;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
          sweep, false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices;
}

// 비교 바
class _CompareRow extends StatelessWidget {
  final String label;
  final double mine;
  final double bm;
  final Color color;
  const _CompareRow(
      {required this.label,
      required this.mine,
      required this.bm,
      required this.color});
  @override
  Widget build(BuildContext context) {
    String pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
    return Row(children: [
      SizedBox(
          width: 64, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CompareBar(mine: mine, benchmark: bm, color: color),
          const SizedBox(height: 4),
          Text('내 비중 ${pct(mine)} / 벤치마크 ${pct(bm)}',
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ]),
      ),
    ]);
  }
}

class _CompareBar extends StatelessWidget {
  final double mine;
  final double benchmark;
  final Color color;
  const _CompareBar(
      {required this.mine, required this.benchmark, required this.color});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Stack(children: [
        Container(
            decoration: BoxDecoration(
                color: const Color(0xFFE9ECF1),
                borderRadius: BorderRadius.circular(999))),
        FractionallySizedBox(
          widthFactor: benchmark.clamp(0, 1),
          child: Container(
              decoration: BoxDecoration(
                  color: color.withOpacity(.35),
                  borderRadius: BorderRadius.circular(999))),
        ),
        FractionallySizedBox(
          widthFactor: mine.clamp(0, 1),
          child: Container(
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(999))),
        ),
      ]),
    );
  }
}

// 라인차트(총자산)
class _LineChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final Color lineColor;
  const _LineChart(
      {required this.labels, required this.values, required this.lineColor});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(
          labels: labels, values: values, lineColor: lineColor),
      child: Container(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<String> labels;
  final List<int> values;
  final Color lineColor;
  _LineChartPainter(
      {required this.labels, required this.values, required this.lineColor});
  @override
  void paint(Canvas canvas, Size size) {
    final padding = 32.0;
    const top = 8.0, bottom = 28.0;
    final chartW = size.width - padding * 2;
    final chartH = size.height - top - bottom;

    final guide = Paint()
      ..color = const Color(0xFFE9ECF1)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = top + chartH * (i / 3);
      canvas.drawLine(Offset(padding, y), Offset(padding + chartW, y), guide);
    }

    final n = values.length;
    final maxVal = values.reduce(math.max).toDouble();
    final minVal = values.reduce(math.min).toDouble();
    final span = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    Offset pt(int i) {
      final x = padding + chartW * (i / (n - 1));
      final y = top + chartH - ((values[i] - minVal) / span) * chartH;
      return Offset(x, y);
    }

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < n; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, line);

    final dot = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      canvas.drawCircle(pt(i), 3.5, dot);
    }

    // x 라벨
    final textStyle = const TextStyle(fontSize: 10, color: Colors.black54);
    for (int i = 0; i < labels.length; i++) {
      final p = pt(i);
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.labels != labels ||
      old.values != values ||
      old.lineColor != lineColor;
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

// --- 적금 목표: Linear Progress ---
class _LinearProgress extends StatelessWidget {
  final double ratio; // 0.0 ~ 1.0
  final Color color;
  final double height;

  const _LinearProgress({
    required this.ratio,
    required this.color,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: const Color(0xFFE9ECF1)), // 배경 트랙
            FractionallySizedBox(
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(color: color), // 진행 구간
            ),
          ],
        ),
      ),
    );
  }
}

// ========================= 모델/유틸 =========================

class _Slice {
  final double ratio;
  final Color color;
  const _Slice({required this.ratio, required this.color});
}

class _Benchmark {
  final double cash;
  final double deposit;
  const _Benchmark({required this.cash, required this.deposit});
}

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

// ===== 로컬 벤치마크 상수 (DB 미연결 시) =====
final Map<String, _Benchmark> _benchmarksLocal = <String, _Benchmark>{
  '20대 남성': const _Benchmark(cash: 0.36, deposit: 0.64),
  '20대 여성': const _Benchmark(cash: 0.42, deposit: 0.58),
};

// ========================= 서버 연동 가정 함수들 =========================
// 실제 프로젝트에 맞게 구현/대체하세요. (지금은 UnimplementedError로 표시)

/// 총자산 추이(최근 6개월)
Future<List<_MonthlyPoint>> fetchAssetTrend() async {
  // TODO: 실제 구현 (예: GET /api/asset/trend?months=6)
  throw UnimplementedError('asset trend endpoint not connected yet');
}

/// 벤치마크(세그먼트별 비중)
Future<_Benchmark> fetchBenchmark(String segment) async {
  // TODO: 실제 구현 (예: GET /asset/benchmark?segment=20대%20남성)
  throw UnimplementedError('benchmark endpoint not connected yet');
}

/// 사용자 프로필(이름/생년)
Future<UserProfile> fetchUserProfile() async {
  // TODO: 실제 구현 (예: GET /user/profile -> {name:'홍길동', birth:'1998-09-01'})
  // DateTime 파싱 유의 (UTC/로컬)
  throw UnimplementedError('profile endpoint not connected yet');
}

// ========================= 프로필 모델 =========================
class UserProfile {
  final String name;
  final DateTime birth;
  UserProfile({required this.name, required this.birth});
}
