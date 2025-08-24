import 'dart:io';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../../constants/text_animation.dart';
import '../../../model/deposit_payment_log.dart';
import '../../../model/common.dart';
import '../../../model/product_account_detail.dart';
import 'package:reframe/service/account_service.dart';

import '../../../service/walk_service.dart'; // dio, commonUrl

// ===== 토스 스타일 색/타이포 =====
const _bgCanvas = Color(0xFFF7F8FA);          // 화면 배경
const _textStrong = Color(0xFF0B0D12);        // 강한 본문
const _textWeak = Color(0xFF6B7280);          // 연한 본문
const _line = Color(0xFFE5E7EB);              // 아주 옅은 구분선
const _blue = Color(0xFF0064FF);              // Toss Blue

final _won = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);

// ===== intl 초기화 없이 쓰는 날짜 포맷 =====
String _pad2(int n) => n.toString().padLeft(2, '0');
String fmtYmd(DateTime d) => '${d.year}.${_pad2(d.month)}.${_pad2(d.day)}';
String fmtYmdE(DateTime d) {
  // 월=1..일=7 → 일월화수목금토
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  final w = days[(d.weekday - 1) % 7];
  return '${fmtYmd(d)} ($w)';
}

class _StepProgress {
  final int total;   // 이번 회차 총 걸음
  final int target;  // 목표 (예: 100000)
  double get ratio => (total / target).clamp(0.0, 1.0);
  const _StepProgress(this.total, this.target);
}

class Period {
  final DateTime start;
  final DateTime end;
  const Period(this.start, this.end);
}

class WalkSavingPage extends StatefulWidget {
  final int accountId;
  const WalkSavingPage({super.key, required this.accountId});

  @override
  State<WalkSavingPage> createState() => _WalkSavingPageState();
}

class _WalkSavingPageState extends State<WalkSavingPage> {
  late Future<ProductAccountDetail> _future;
  bool _paying = false;
  int _stepsToday = 0;

  final Health _health = Health();
  String _healthStatus = '걸음 연동 준비됨';

  @override
  void initState() {
    super.initState();
    _future = fetchAccountDetail(widget.accountId);
  }

  // --- 걸음수 측정 메서드 ---
  Future<bool> _ensureHealthPermissions() async {
    if (Platform.isAndroid) {
      final ar = await Permission.activityRecognition.status;
      if (ar.isDenied || ar.isRestricted) {
        final r = await Permission.activityRecognition.request();
        if (!r.isGranted) {
          setState(() => _healthStatus = '❌ 활동 인식 권한 거부됨');
          return false;
        }
      }
    }
    // 읽기 권한
    final types = [HealthDataType.STEPS];
    final access = [HealthDataAccess.READ];

    final has = await _health.hasPermissions(types, permissions: access) ?? false;
    if (!has) {
      final ok = await _health.requestAuthorization(types, permissions: access);
      if (!ok) {
        setState(() => _healthStatus = '❌ Health 권한 없음(Health Connect/HealthKit)');
        return false;
      }
    }
    return true;
  }

  Future<int> _fetchTodaySteps() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(midnight, now);
    return steps ?? 0;
  }

  // --- 가입 상품 정보 데이터 메서드 ---
  Future<void> _refresh() async {
    final f = fetchAccountDetail(widget.accountId);
    setState(() => _future = f);
    await f;
  }

  Future<void> _onPressPay(ProductAccountDetail detail) async {
    final nxt = _findNextUnpaid(detail);
    if (nxt == null) return;

    // 가벼운 햅틱
    HapticFeedback.lightImpact();

    final ok = await _confirmPayDialog(nxt.round, nxt.amount);
    if (!mounted || !ok) return;

    if (_paying) return;
    setState(() => _paying = true);
    try {
      final appId = detail.application.id;
      await payMonthlySaving(appId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다음 회차 납입이 완료되었습니다.')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      final msg = _errorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실패: $msg')),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  // ===== 도메인 헬퍼 =====
  DepositPaymentLog? _findNextUnpaid(ProductAccountDetail d) {
    for (final log in d.depositPaymentLogList) {
      if ((log.status ?? PaymentStatus.unpaid) == PaymentStatus.unpaid) return log;
    }
    return null;
  }

  DateTime _computeDueDate(DateTime startAt, int round) {
    // 가입일의 '일자' 기준으로 회차별 예정일 계산 (말일 보정)
    final m0 = DateTime(startAt.year, startAt.month, 1);
    final m = DateTime(m0.year, m0.month + (round - 1), 1);
    final targetDom = startAt.day;
    final last = DateTime(m.year, m.month + 1, 0).day;
    final dom = targetDom > last ? last : targetDom;
    return DateTime(m.year, m.month, dom);
  }

  // now가 어느 회차(가입일 기준 '월' 구간)에 속하는지 찾기
  int _currentMonthlyRound(DateTime startAt, DateTime now) {
    int lo = 1, hi = 600; // 넉넉한 상한
    while (lo < hi) {
      final next = _computeDueDate(startAt, ((lo + hi) >> 1) + 1);
      if (now.isBefore(next)) {
        hi = (lo + hi) >> 1;
      } else {
        lo = ((lo + hi) >> 1) + 1;
      }
    }
    return lo; // now ∈ [due(lo), due(lo+1))
  }

  // r회차의 집계 기간 [start, end] (end는 inclusive로 1초 뺌)
  Period _monthCycleBounds(DateTime startAt, int round) {
    final s = _computeDueDate(startAt, round);
    final e = _computeDueDate(startAt, round + 1).subtract(const Duration(seconds: 1));
    return Period(s, e);
  }

  _StepProgress _calcMonthlyProgress(ProductAccountDetail detail) {
    const target = 100000; // 월 목표 걸음
    final app = detail.application;
    if (app.startAt == null) return const _StepProgress(0, target);

    final now = DateTime.now();
    final roundNow = _currentMonthlyRound(app.startAt!, now);

    // 현재 회차 로그 찾기
    DepositPaymentLog? curLog;
    for (final e in detail.depositPaymentLogList) {
      if (e.round == roundNow) { curLog = e; break; }
    }

    final total = curLog?.walkStepsTotal ?? 0;
    return _StepProgress(total, target);
  }

  String _errorMessage(Object e) {
    if (e is DioException) {
      final r = e.response;
      final msg = (r?.data is Map && r!.data['message'] is String) ? r.data['message'] as String : null;
      return msg ?? 'HTTP ${r?.statusCode ?? ''} 오류';
    }
    return '알 수 없는 오류';
  }

  Future<void> _syncStepsAuto(ProductAccountDetail detail) async {
    setState(() => _healthStatus = '권한 확인 중...');
    final ok = await _ensureHealthPermissions();
    if (!ok) return;

    setState(() => _healthStatus = '오늘 걸음 집계 중...');
    final steps = await _fetchTodaySteps();

    if (!mounted) return;
    setState(() {
      _stepsToday = steps;
      _healthStatus = '오늘 걸음: $steps 보';
    });

    // (선택) 서버에 오늘 "누적 걸음수" 전달하여 회차 누적/보너스 확정/금리 업데이트
    // WalkSyncService.sync(appId, stepsTodayTotal) 에 맞춘 엔드포인트가 있다면 아래처럼 호출
    try {
      final appId = detail.application.id;
      await fetchWalkSync(appId, steps);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('걸음 동기화 완료')),
      );
      // 금리/진행도 갱신 위해 새로고침
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      final msg = _errorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('동기화 실패: $msg')),
      );
    }
  }


  Future<bool> _confirmPayDialog(int round, int amount) async {
    final formatted = NumberFormat('#,###').format(amount);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _TossSheet(
        title: '$round 회차 납입',

        // 버튼들 — 네가 이미 정의해둔 컴포넌트 그대로 사용
        primary: _TossPrimaryButton(
          label: '납입',
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(ctx, true);
          },
        ),
        secondary: _TossOutlineButton(
          label: '취소',
          onPressed: () => Navigator.pop(ctx, false),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // 금액 강조 + 문장
            Align(
              alignment: Alignment.center,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$formatted원',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _textStrong,
                        height: 1.3,
                      ),
                    ),
                    const TextSpan(
                      text: ' 을(를) 납입할까요?',
                      style: TextStyle(
                        fontSize: 16,
                        color: _textWeak,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 안내 박스
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 18, color: _textWeak),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '확인 시 납입이 진행됩니다. \n납입 취소는 거래내역에서 가능합니다.',
                      style: TextStyle(fontSize: 13, color: _textWeak, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }


  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgCanvas,
      child: SafeArea(
        top: false,
        bottom: true,
        child: RefreshIndicator(
          color: _blue,
          onRefresh: _refresh,
          child: FutureBuilder<ProductAccountDetail>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError || !snap.hasData) {
                return ListView(children: const [
                  SizedBox(height: 140),
                  Center(child: Text('상세 데이터를 불러오지 못했습니다.')),
                ]);
              }

              final detail = snap.data!;
              final acc = detail.account;
              final app = detail.application;
              final principal = (acc?.balance ?? 0);

              final now = DateTime.now();
              final roundNow = (app.startAt == null) ? 1 : _currentMonthlyRound(app.startAt!, now);
              final Period bounds = (app.startAt == null)
                  ? Period(
                DateTime(now.year, now.month, 1),
                DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1)),
              )
                  : _monthCycleBounds(app.startAt!, roundNow);

              final step = _calcMonthlyProgress(detail);

              final nextUnpaid = _findNextUnpaid(detail);
              final startAt = app.startAt ?? DateTime.now();
              final nextDue = (nextUnpaid == null) ? null : _computeDueDate(startAt, nextUnpaid.round);
              final today = DateTime.now();
              final canPayToday = nextDue != null && fmtYmd(nextDue) == fmtYmd(today);

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // 헤더(화이트) — 잔액 강조
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 상단 타이틀 라인
                        Row(
                          children: [
                            const Icon(CupertinoIcons.creditcard, size: 18, color: _textWeak),
                            const SizedBox(width: 6),
                            Text(
                              acc?.accountName ?? app.product.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textStrong),
                            ),
                            const Spacer(),
                            Text(acc?.accountNumber ?? '-', style: const TextStyle(color: _textWeak)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text('현재 잔액', style: TextStyle(fontSize: 13, color: _textWeak)),
                        const SizedBox(height: 6),
                        DiffHighlight(
                          marker: principal,
                          highlightOnFirstBuild: true,
                          child: MoneyCountUp(
                            value: principal,
                            formatter: _won,
                            animateOnFirstBuild: true,                 // 첫 진입에도 촤라락
                            duration: const Duration(milliseconds: 650),
                            style: Theme.of(context).textTheme.headlineSmall, // (원하면 더 크게)
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _TossChip(text: '기본 ${_pct(app.baseRateAtEnroll)}', icon: CupertinoIcons.percent),
                            _TossChip(text: '적용 ${_pct(app.effectiveRateAnnual ?? app.baseRateAtEnroll)}', icon: Icons.trending_up),
                            if (nextDue != null)
                              _TossChip(
                                text: canPayToday ? '오늘 납입 가능' : '예정일 ${fmtYmd(nextDue)}',
                                icon: canPayToday ? CupertinoIcons.calendar : CupertinoIcons.calendar,
                                tone: canPayToday ? _ChipTone.success : _ChipTone.neutral,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 걸음 카드
                  _Section(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('오늘 걸음 수', style: TextStyle(fontWeight: FontWeight.w700, color: _textStrong)),
                              const SizedBox(height: 10),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  '$_stepsToday 걸음',
                                  key: ValueKey(_stepsToday),
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textStrong),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _healthStatus,
                                style: const TextStyle(fontSize: 12, color: _textWeak),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _TossOutlineButton(
                          label: '걸음 동기화',
                          onPressed: () => _syncStepsAuto(detail),
                        ),
                      ],
                    ),
                  ),
                  _Section(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('이번 회차 (가입일 기준 월)'),
                        const SizedBox(height: 8),
                        Text(
                          '${NumberFormat('#,###').format(step.total)} / ${NumberFormat('#,###').format(step.target)} 보',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textStrong),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '기간: ${fmtYmd(bounds.start)} ~ ${fmtYmd(bounds.end)}',
                          style: const TextStyle(color: _textWeak),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: step.ratio, minHeight: 10, backgroundColor: _line),
                      ],
                    ),
                  ),
                  // 다음 납입 + CTA
                  _Section(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('다음 납입'),
                        const SizedBox(height: 10),
                        _KvRow('회차', nextUnpaid == null ? '-' : '${nextUnpaid.round}회차'),
                        _KvRow('예정일', nextDue == null ? '-' : fmtYmdE(nextDue)),
                        _KvRow('회차 금액', nextUnpaid == null ? '-' : _won.format(nextUnpaid.amount)),
                        const SizedBox(height: 14),
                        _TossPrimaryButton(
                          label: canPayToday ? '이번 회차 납입' : '오늘은 납입일이 아니에요',
                          onPressed: (nextUnpaid == null || !canPayToday || _paying)
                              ? null
                              : () async => _onPressPay(detail),
                          busy: _paying,
                        ),
                      ],
                    ),
                  ),

                  // 요약
                  _Section(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('요약'),
                        const SizedBox(height: 10),
                        _KvRow('약정 개월수', app.termMonthsAtEnroll == null ? '-' : '${app.termMonthsAtEnroll}개월'),
                        _KvRow('가입일', app.startAt == null ? '-' : fmtYmdE(app.startAt!)),
                        _KvRow('만기일', app.closeAt == null ? '-' : fmtYmdE(app.closeAt!)),
                      ],
                    ),
                  ),

                  // 납입 현황
                  _Section(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('납입 현황'),
                        const SizedBox(height: 6),
                        if (detail.depositPaymentLogList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('표시할 납입 내역이 없습니다.', style: TextStyle(color: _textWeak)),
                          )
                        else
                          ...detail.depositPaymentLogList.map((e) {
                            final isPaid = (e.status ?? PaymentStatus.unpaid) == PaymentStatus.paid;
                            final due = _computeDueDate(startAt, e.round);
                            final subtitle = isPaid ? '납입일 ${fmtYmd(e.paidAt ?? due)}' : '예정일 ${fmtYmd(due)}';
                            return Column(
                              children: [
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${e.round}회차  ${_won.format(e.amount)}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: _textStrong)),
                                  subtitle: Text(subtitle, style: const TextStyle(color: _textWeak)),
                                  trailing: _StatusPill(
                                    text: isPaid ? '납입완료' : '미납입',
                                    tone: isPaid ? _ChipTone.success : _ChipTone.warning,
                                  ),
                                ),
                                const Divider(height: 16, color: _line),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ====== 재사용 UI (토스풍) ======
class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: _textStrong));
  }
}

class _KvRow extends StatelessWidget {
  final String k;
  final String v;
  const _KvRow(this.k, this.v);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: _textWeak))),
          const SizedBox(width: 8),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700, color: _textStrong)),
        ],
      ),
    );
  }
}

enum _ChipTone { neutral, success, warning }

class _TossChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final _ChipTone tone;
  const _TossChip({required this.text, required this.icon, this.tone = _ChipTone.neutral});

  @override
  Widget build(BuildContext context) {
    Color fg; Color bg;
    switch (tone) {
      case _ChipTone.success:
        fg = const Color(0xFF0A7A33);
        bg = const Color(0xFFE8F5ED);
        break;
      case _ChipTone.warning:
        fg = const Color(0xFF8A4B00);
        bg = const Color(0xFFFFF3E0);
        break;
      default:
        fg = const Color(0xFF1F2937);
        bg = const Color(0xFFF3F4F6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final _ChipTone tone;
  const _StatusPill({required this.text, this.tone = _ChipTone.neutral});
  @override
  Widget build(BuildContext context) {
    Color fg; Color bg;
    switch (tone) {
      case _ChipTone.success:
        fg = const Color(0xFF0A7A33);
        bg = const Color(0xFFE8F5ED);
        break;
      case _ChipTone.warning:
        fg = const Color(0xFF8A4B00);
        bg = const Color(0xFFFFF3E0);
        break;
      default:
        fg = const Color(0xFF1F2937);
        bg = const Color(0xFFF3F4F6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _TossPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const _TossPrimaryButton({required this.label, required this.onPressed, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? _blue : const Color(0xFFE5E7EB),
          foregroundColor: enabled ? Colors.white : const Color(0xFF9CA3AF),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: busy
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _TossOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _TossOutlineButton({required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _textStrong,
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _TossTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _TossTextButton({required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: _textWeak),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

// 바텀시트 느낌의 토스풍 다이얼로그(얕은 여백, 둥근 모서리)
class _TossSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget primary;
  final Widget? secondary;
  const _TossSheet({required this.title, required this.child, required this.primary, this.secondary});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textStrong)),
            const SizedBox(height: 10),
            child,
            if (secondary != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: secondary!),   // 취소 버튼
                  const SizedBox(width: 8),      // 버튼 간격
                  Expanded(child: primary),      // 납입 버튼
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              primary,
            ],
          ],
        ),
      ),
    );
  }
}

String _pct(num? v) => '${(v ?? 0).toStringAsFixed(2)}%';
