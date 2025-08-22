// lib/pages/my_service_test_page.dart
//
// 프론트 전용 목 데이터로 모든 섹션/차트를 한 화면에 구성.
// + 적금 목표(게이지/프로그레스바)
// + 입출금 합계 막대그래프
// + 잔액 추이 선그래프
//
// 외부 의존성 없음.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class MyServiceTestPage extends StatefulWidget {
  const MyServiceTestPage({super.key});
  @override
  State<MyServiceTestPage> createState() => _MyServiceTestPageState();
}

class _MyServiceTestPageState extends State<MyServiceTestPage> {
  // ===== 목 데이터 =====
  final _userName = '홍길동';
  final _birth = DateTime(1998, 9, 1);

  // 계좌(입출금/예적금)
  final _accounts = <_Account>[
    _Account(
      name: '부산은행 급여통장',
      number: '110-1234-567890',
      type: _AccountType.demand,
      bank: 'BNK부산은행',
      balance: 1800000,
      isDefault: true,
    ),
    _Account(
      name: '저탄소 실천 적금',
      number: '208-9876-543210',
      type: _AccountType.deposit,
      bank: 'BNK부산은행',
      balance: 3000000,
    ),
  ];

  // 진행/만기
  final _applications = <_AppItem>[
    _AppItem(
      title: 'BNK 내맘대로예금',
      status: '진행중',
      startAt: DateTime(2024, 9, 10),
      closeAt: DateTime(2025, 9, 10),
    ),
    _AppItem(
      title: '애큐온 ○○적금',
      status: '신청완료',
      startAt: DateTime(2025, 8, 1),
      closeAt: null,
    ),
  ];

  // 추천
  final _recommends = <_RecommendItem>[
    _RecommendItem(
        title: '저탄소 실천 적금',
        tag: '평점 4.5 ★  |  최고 연 6.0%',
        rateText: '최고 연 6.0%',
        periodText: '12~24개월'),
    _RecommendItem(
        title: '메리트정기예금',
        tag: '연 5.8% | 12개월',
        rateText: '연 5.8%',
        periodText: '12개월'),
    _RecommendItem(
        title: 'BNK내맘대로예금',
        tag: '연 5.6% | 6~24개월',
        rateText: '연 5.6%',
        periodText: '6~24개월'),
  ];

  // 벤치마크(세그먼트 전환)
  final _benchmarks = <String, _Benchmark>{
    '20대 남성': const _Benchmark(cash: 0.36, deposit: 0.64),
    '20대 여성': const _Benchmark(cash: 0.42, deposit: 0.58),
  };
  String _selectedBM = '20대 남성';

  // ===== [추가] 차트용 하드코딩 데이터 =====
  // 1) 적금 목표
  final int _savingGoal = 10000000; // 목표 1,000만원
  final int _savingNow = 3200000; // 현재 320만원 → 32%

  // 2) 입출금 합계 (최근 6개월)
  final List<String> _months = const ['03', '04', '05', '06', '07', '08'];
  final List<int> _sumIn = const [
    1200000,
    800000,
    1500000,
    900000,
    1100000,
    1300000
  ];
  final List<int> _sumOut = const [
    900000,
    700000,
    800000,
    950000,
    1000000,
    980000
  ];

  // 3) 잔액 추이 (최근 6개월 총자산 스냅샷)
  final List<int> _balanceSeries = const [
    3800000,
    4000000,
    4200000,
    4100000,
    4600000,
    4800000
  ];

  @override
  Widget build(BuildContext context) {
    // 합계/비중/대표계좌 계산
    final cashSum = _accounts
        .where((a) => a.type == _AccountType.demand)
        .fold<int>(0, (p, a) => p + a.balance);
    final depositSum = _accounts
        .where((a) => a.type == _AccountType.deposit)
        .fold<int>(0, (p, a) => p + a.balance);
    final total = cashSum + depositSum;
    final safeTotal = total == 0 ? 1 : total;
    final cashRatio = (cashSum / safeTotal).clamp(0.0, 1.0);
    final depositRatio = (depositSum / safeTotal).clamp(0.0, 1.0);
    final age = _calcAge(_birth);
    final defaultAcc =
        _accounts.firstWhere((a) => a.isDefault, orElse: () => _accounts.first);
    final defaultMask = _maskLast4(defaultAcc.number);

    final bm = _benchmarks[_selectedBM]!;

    return Scaffold(
      appBar: AppBar(title: const Text('내 자산 요약'), centerTitle: true),
      body: SafeArea(
        bottom: true,
        child: Builder(builder: (context) {
          final bottomPadding = MediaQuery.of(context).padding.bottom +
              kBottomNavigationBarHeight +
              16;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
            children: [
              // ===== 상단 카드 =====
              _TopSummaryCard(
                title: '$_userName님(만 $age세)',
                total: total,
                defaultText: '대표계좌($defaultMask)',
                cashRatio: cashRatio,
                depositRatio: depositRatio,
                cashSum: cashSum,
                depositSum: depositSum,
              ),
              const SizedBox(height: 16),

              // ===== [추가] 적금 목표 (게이지 + 프로그레스) =====
              Card(
                elevation: 0.4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(
                    children: [
                      // 게이지
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: _GaugeProgress(
                          ratio: (_savingNow / _savingGoal).clamp(0.0, 1.0),
                          color: const Color(0xFF7C88FF),
                          label: '적금 목표',
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 텍스트 + Linear Progress
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('적금 목표 달성률',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('${_won(_savingNow)} / ${_won(_savingGoal)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 10),
                            _LinearProgress(
                              ratio: (_savingNow / _savingGoal).clamp(0.0, 1.0),
                              color: const Color(0xFF7C88FF),
                              height: 14,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== 자산 분포 (도넛 차트) =====
              Card(
                elevation: 0.4,
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
                              child: _DonutChart(
                                slices: [
                                  _Slice(
                                      ratio: cashRatio,
                                      color: const Color(0xFF40C4FF)),
                                  _Slice(
                                      ratio: depositRatio,
                                      color: const Color(0xFF7C88FF)),
                                ],
                              ),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== 내 비중 vs 벤치마크 =====
              Card(
                elevation: 0.4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('내 비중 vs 벤치마크',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          PopupMenuButton<String>(
                            initialValue: _selectedBM,
                            onSelected: (v) => setState(() => _selectedBM = v),
                            itemBuilder: (c) => _benchmarks.keys
                                .map((k) =>
                                    PopupMenuItem(value: k, child: Text(k)))
                                .toList(),
                            child: Row(
                              children: [
                                Text(_selectedBM,
                                    style: const TextStyle(fontSize: 12)),
                                const Icon(Icons.keyboard_arrow_down, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _CompareRow(
                        label: '현금성',
                        mine: cashRatio,
                        bm: bm.cash,
                        color: const Color(0xFF40C4FF),
                      ),
                      const SizedBox(height: 10),
                      _CompareRow(
                        label: '예·적금',
                        mine: depositRatio,
                        bm: bm.deposit,
                        color: const Color(0xFF7C88FF),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== [추가] 입출금 합계 막대그래프 =====
              Card(
                elevation: 0.4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('입출금 합계 (최근 6개월)',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: _GroupedBarChart(
                          labels: _months,
                          seriesA: _sumIn,
                          seriesB: _sumOut,
                          colorA: const Color(0xFF40C4FF), // 입금
                          colorB: const Color(0xFF7C88FF), // 출금
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        children: const [
                          _LegendSmall(color: Color(0xFF40C4FF), label: '입금'),
                          _LegendSmall(color: Color(0xFF7C88FF), label: '출금'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== [추가] 잔액 추이 선그래프 =====
              Card(
                elevation: 0.4,
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
                        height: 220,
                        child: _LineChart(
                            labels: _months,
                            values: _balanceSeries,
                            lineColor: const Color(0xFF7C88FF)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== 진행 중/만기 임박 =====
              const _SectionHeader('진행 중/만기 임박'),
              const SizedBox(height: 8),
              ..._applications.map((e) => _ApplicationTile(item: e)),
              const SizedBox(height: 16),

              // ===== 추천 예·적금 =====
              const _SectionHeader('추천 예·적금'),
              const SizedBox(height: 8),
              ..._recommends.map((e) => _RecommendTile(item: e)),
              const SizedBox(height: 16),

              // ===== 내 계좌 =====
              const _SectionHeader('내 계좌'),
              const SizedBox(height: 8),
              ..._accounts.map((a) => _AccountTile(a)),
            ],
          );
        }),
      ),
    );
  }
}

// =====================================================
// 위젯들
// =====================================================

class _TopSummaryCard extends StatelessWidget {
  final String title;
  final int total;
  final String defaultText;
  final double cashRatio;
  final double depositRatio;
  final int cashSum;
  final int depositSum;

  const _TopSummaryCard({
    required this.title,
    required this.total,
    required this.defaultText,
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
            // 프로필
            Row(
              children: [
                const CircleAvatar(radius: 16, child: Icon(Icons.person)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),

            // 총자산 + 대표계좌
            Text(_won(total),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(defaultText,
                style: TextStyle(color: Colors.black.withOpacity(.55))),

            const SizedBox(height: 12),

            // 비중 바
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 18,
                child: Stack(
                  children: [
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 비중 텍스트
            Row(
              children: [
                Text('현금성 ${pct(cashRatio)}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                const Text('·', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text('예·적금 ${pct(depositRatio)}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),

            const SizedBox(height: 8),

            // 범례
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _LegendDot(color: cashColor, label: '현금성', amount: cashSum),
                _LegendDot(
                    color: depositColor, label: '예·적금', amount: depositSum),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- 적금 목표: 게이지 ---
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${(ratio * 100).toStringAsFixed(0)}%',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
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
    final center = size.center(Offset.zero);
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

    // 반원 게이지(180도)
    final start = math.pi; // 왼쪽
    final sweepAll = math.pi;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: r), start, sweepAll, false, bg);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), start,
        sweepAll * ratio.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.ratio != ratio || old.color != color;
}

// --- 적금 목표: Linear Progress ---
class _LinearProgress extends StatelessWidget {
  final double ratio;
  final Color color;
  final double height;
  const _LinearProgress(
      {required this.ratio, required this.color, this.height = 10});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: const Color(0xFFE9ECF1)),
            FractionallySizedBox(
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 도넛 차트 ---
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

    // 배경 원
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

// --- 비교 바 ---
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
    return Row(
      children: [
        SizedBox(
            width: 64,
            child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CompareBar(mine: mine, benchmark: bm, color: color),
              const SizedBox(height: 4),
              Text('내 비중 ${pct(mine)} / 벤치마크 ${pct(bm)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
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
      child: Stack(
        children: [
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
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
}

class _ApplicationTile extends StatelessWidget {
  final _AppItem item;
  const _ApplicationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final dday = item.closeAt == null ? null : _dDay(item.closeAt!);
    final badgeText = dday != null ? 'D-$dday' : (item.status);
    final sub = item.closeAt != null
        ? '만기 ${_fmtDate(item.closeAt!)}'
        : '신청일 ${_fmtDate(item.startAt)}';

    return Card(
      elevation: 0.4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.schedule)),
        title: Row(
          children: [
            Expanded(
                child: Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            _Tag(text: badgeText),
          ],
        ),
        subtitle: Text(sub),
        onTap: () {},
      ),
    );
  }
}

class _RecommendTile extends StatelessWidget {
  final _RecommendItem item;
  const _RecommendTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.savings)),
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(item.tag),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(item.rateText,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(item.periodText,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final _Account account;
  const _AccountTile(this.account);

  @override
  Widget build(BuildContext context) {
    final badge = account.isDefault ? const _Tag(text: '기본계좌') : null;

    return Card(
      elevation: 0.4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(account.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (badge != null) badge,
          ],
        ),
        subtitle: Text('${account.type.label} · ${account.number}'),
        trailing: Text(_won(account.balance),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        onTap: () {},
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final int amount;
  const _LegendDot(
      {required this.color, required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label  ${_won(amount)}',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LegendSmall extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendSmall({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// --- 막대그래프(입금/출금) ---
class _GroupedBarChart extends StatelessWidget {
  final List<String> labels; // x축 라벨 (예: '03','04'..)
  final List<int> seriesA; // 입금
  final List<int> seriesB; // 출금
  final Color colorA;
  final Color colorB;

  const _GroupedBarChart({
    required this.labels,
    required this.seriesA,
    required this.seriesB,
    required this.colorA,
    required this.colorB,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GroupedBarPainter(
        labels: labels,
        a: seriesA,
        b: seriesB,
        colorA: colorA,
        colorB: colorB,
      ),
      child: Container(),
    );
  }
}

class _GroupedBarPainter extends CustomPainter {
  final List<String> labels;
  final List<int> a, b;
  final Color colorA, colorB;
  _GroupedBarPainter(
      {required this.labels,
      required this.a,
      required this.b,
      required this.colorA,
      required this.colorB});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 28.0; // 좌우
    final top = 8.0, bottom = 28.0; // 상단/라벨 영역
    final chartW = size.width - padding * 2;
    final chartH = size.height - top - bottom;

    // 배경 가이드라인 3개
    final guide = Paint()
      ..color = const Color(0xFFE9ECF1)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = top + chartH * (i / 3);
      canvas.drawLine(Offset(padding, y), Offset(padding + chartW, y), guide);
    }

    final n = labels.length;
    final maxVal = [0, ...a, ...b].reduce(math.max).toDouble();
    final groupW = chartW / n;
    final barW = groupW * 0.32;

    final paintA = Paint()
      ..color = colorA
      ..style = PaintingStyle.fill;
    final paintB = Paint()
      ..color = colorB
      ..style = PaintingStyle.fill;

    final textPainter = (String s, {double size = 10}) {
      final tp = TextPainter(
        text: TextSpan(
            text: s, style: TextStyle(fontSize: size, color: Colors.black54)),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    };

    for (int i = 0; i < n; i++) {
      final x0 = padding + i * groupW + groupW * 0.5;

      // A bar
      final double hA = maxVal == 0 ? 0.0 : (a[i].toDouble() / maxVal) * chartH;
      final Rect rectA = Rect.fromLTWH(
        x0 - barW - 4,
        top + chartH - hA,
        barW,
        hA,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rectA, const Radius.circular(6)),
        paintA,
      );

      // B bar
      final double hB = maxVal == 0 ? 0.0 : (b[i].toDouble() / maxVal) * chartH;
      final Rect rectB = Rect.fromLTWH(
        x0 + 4,
        top + chartH - hB,
        barW,
        hB,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rectB, const Radius.circular(6)),
        paintB,
      );

      // x 라벨
      final tp = textPainter(labels[i]);
      tp.paint(canvas, Offset(x0 - tp.width / 2, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _GroupedBarPainter old) =>
      old.labels != labels ||
      old.a != a ||
      old.b != b ||
      old.colorA != colorA ||
      old.colorB != colorB;
}

// --- 라인 차트(잔액 추이) ---
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
    final top = 8.0, bottom = 28.0;
    final chartW = size.width - padding * 2;
    final chartH = size.height - top - bottom;

    // 가이드라인
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

    // 선
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < n; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, linePaint);

    // 포인트
    final dot = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      canvas.drawCircle(pt(i), 3.5, dot);
    }

    // x 라벨
    final textPainter = (String s) {
      final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: const TextStyle(fontSize: 10, color: Colors.black54)),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    };
    for (int i = 0; i < labels.length; i++) {
      final p = pt(i);
      final tp = textPainter(labels[i]);
      tp.paint(canvas, Offset(p.dx - tp.width / 2, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.labels != labels ||
      old.values != values ||
      old.lineColor != lineColor;
}

// =====================================================
// 모델/유틸/색/포맷
// =====================================================

enum _AccountType { demand, deposit }

extension on _AccountType {
  String get label => this == _AccountType.demand ? '입출금' : '상품계좌';
}

class _Account {
  final String name;
  final String number;
  final _AccountType type;
  final String bank;
  final int balance;
  final bool isDefault;
  _Account({
    required this.name,
    required this.number,
    required this.type,
    required this.bank,
    required this.balance,
    this.isDefault = false,
  });
}

class _AppItem {
  final String title;
  final String status; // '진행중', '신청완료' 등
  final DateTime startAt;
  final DateTime? closeAt; // 만기일(없으면 null)
  _AppItem(
      {required this.title,
      required this.status,
      required this.startAt,
      this.closeAt});
}

class _RecommendItem {
  final String title;
  final String tag;
  final String rateText;
  final String periodText;
  _RecommendItem(
      {required this.title,
      required this.tag,
      required this.rateText,
      required this.periodText});
}

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

int _calcAge(DateTime birth) {
  final now = DateTime.now();
  int age = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) age--;
  return math.max(age, 0);
}

String _maskLast4(String no) {
  final digits = no.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length <= 4) return '…$digits';
  return '…${digits.substring(digits.length - 4)}';
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _dDay(DateTime target) {
  final today = DateTime.now();
  final t = DateTime(target.year, target.month, target.day);
  final n = DateTime(today.year, today.month, today.day);
  return t.difference(n).inDays;
}

String _won(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - 1 - i;
    buf.write(s[idx]);
    if ((i + 1) % 3 == 0 && idx != 0) buf.write(',');
  }
  final str = buf.toString().split('').reversed.join();
  return (v < 0 ? '- ' : '') + str + ' 원';
}
