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

// ===== 앱 톤앤매너 =====
const _bgCanvas = Colors.white;
const _textStrong = Color(0xFF0B0D12);
const _textWeak = Color(0xFF6B7280);
const _line = Color(0xFFE5E7EB);
const _blue = Color(0xFF0064FF);

// 헤더 그라데이션
const _brand = Color(0xFF306BFF);
const _brand2 = Color(0xFF3B82F6);

const _warn = Color(0xFF8A4B00);
const _cardShadow = Color(0x14000000);

final _won =
    NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);

// ===== intl 없이 쓰는 날짜 포맷 =====
String _pad2(int n) => n.toString().padLeft(2, '0');
String fmtYmd(DateTime d) => '${d.year}.${_pad2(d.month)}.${_pad2(d.day)}';
String fmtYmdE(DateTime d) {
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  final w = days[(d.weekday - 1) % 7];
  return '${fmtYmd(d)} ($w)';
}

class _StepProgress {
  final int total;
  final int target;
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
  ProductAccountDetail? _detailCache;

  bool _paying = false;
  bool _syncing = false;
  bool _hideBalance = false;
  int _stepsToday = 0;

  final Health _health = Health();
  String _healthStatus = '걸음 연동 준비됨';

  int? _stepsMonthOverride;
  int? _thresholdOverride;
  double? _effRateOverride;

  @override
  void initState() {
    super.initState();
    _future = fetchAccountDetail(widget.accountId);
    _future.then((detail) async {
      if (!mounted) return;
      _detailCache ??= detail;
      _loadSummaryOnce(detail.application.id);
    });
  }

  Future<void> _loadSummaryOnce(int appId) async {
    try {
      final r = await fetchWalkSummary(appId);
      if (!mounted) return;
      setState(() {
        _stepsMonthOverride = r.stepsThisMonth;
        _thresholdOverride = r.threshold;
        _effRateOverride = r.effectiveRate;
        _stepsToday = r.todaySteps;
        _healthStatus = r.lastSyncDate != null
            ? '최근 동기화: ${r.lastSyncDate!.year}.${_pad2(r.lastSyncDate!.month)}.${_pad2(r.lastSyncDate!.day)} '
                '${_pad2(r.lastSyncDate!.hour)}:${_pad2(r.lastSyncDate!.minute)}'
            : '걸음 연동 준비됨';
      });
    } catch (_) {}
  }

  // --- 권한/걸음 ---
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
    final types = [HealthDataType.STEPS];
    final access = [HealthDataAccess.READ];

    final has =
        await _health.hasPermissions(types, permissions: access) ?? false;
    if (!has) {
      final ok = await _health.requestAuthorization(types, permissions: access);
      if (!ok) {
        setState(
            () => _healthStatus = '❌ Health 권한 없음(Health Connect/HealthKit)');
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

  // --- 상세 리프레시 ---
  Future<void> _softRefresh() async {
    try {
      final d = await fetchAccountDetail(widget.accountId);
      if (!mounted) return;
      setState(() => _detailCache = d);
    } catch (_) {}
  }

  // --- 납입 처리 ---
  Future<void> _onPressPay(ProductAccountDetail detail) async {
    final nxt = _findNextUnpaid(detail);
    if (nxt == null) return;

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
        const SnackBar(
            content: Text('다음 회차 납입이 완료되었습니다.'),
            duration: Duration(milliseconds: 1500)),
      );
      await _softRefresh();
    } catch (e) {
      if (!mounted) return;
      final msg = _errorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('실패: $msg'),
            duration: const Duration(milliseconds: 1800)),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  // ===== 도메인 헬퍼 =====
  DepositPaymentLog? _findNextUnpaid(ProductAccountDetail d) {
    for (final log in d.depositPaymentLogList) {
      if ((log.status ?? PaymentStatus.unpaid) == PaymentStatus.unpaid)
        return log;
    }
    return null;
  }

  DateTime _computeDueDate(DateTime startAt, int round) {
    final m0 = DateTime(startAt.year, startAt.month, 1);
    final m = DateTime(m0.year, m0.month + (round - 1), 1);
    final targetDom = startAt.day;
    final last = DateTime(m.year, m.month + 1, 0).day;
    final dom = targetDom > last ? last : targetDom;
    return DateTime(m.year, m.month, dom);
  }

  int _currentMonthlyRound(DateTime startAt, DateTime now) {
    int lo = 1, hi = 600;
    while (lo < hi) {
      final next = _computeDueDate(startAt, ((lo + hi) >> 1) + 1);
      if (now.isBefore(next)) {
        hi = (lo + hi) >> 1;
      } else {
        lo = ((lo + hi) >> 1) + 1;
      }
    }
    return lo;
  }

  Period _monthCycleBounds(DateTime startAt, int round) {
    final s = _computeDueDate(startAt, round);
    final e = _computeDueDate(startAt, round + 1)
        .subtract(const Duration(seconds: 1));
    return Period(s, e);
  }

  _StepProgress _calcMonthlyProgress(ProductAccountDetail detail) {
    final app = detail.application;
    final target = app.walkThresholdSteps ?? 100000;
    if (app.startAt == null) return _StepProgress(0, target);

    final now = DateTime.now();
    final roundNow = _currentMonthlyRound(app.startAt!, now);

    DepositPaymentLog? curLog;
    for (final e in detail.depositPaymentLogList) {
      if (e.round == roundNow) {
        curLog = e;
        break;
      }
    }
    final total = curLog?.walkStepsTotal ?? 0;
    return _StepProgress(total, target);
  }

  String _errorMessage(Object e) {
    if (e is DioException) {
      final r = e.response;
      final msg = (r?.data is Map && r!.data['message'] is String)
          ? r.data['message'] as String
          : null;
      return msg ?? 'HTTP ${r?.statusCode ?? ''} 오류';
    }
    return '알 수 없는 오류';
  }

  Future<void> _openAppSettings() async {
    final opened = await openAppSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('설정을 열 수 없었습니다.'),
            duration: Duration(milliseconds: 1500)),
      );
    }
  }

  Future<void> _syncStepsAuto(ProductAccountDetail detail) async {
    setState(() {
      _healthStatus = '권한 확인 중...';
      _syncing = true;
    });
    final ok = await _ensureHealthPermissions();
    if (!ok) {
      setState(() => _syncing = false);
      return;
    }

    setState(() => _healthStatus = '오늘 걸음 집계 중...');
    final steps = await _fetchTodaySteps();

    if (!mounted) return;
    setState(() {
      _stepsToday = steps;
      _healthStatus = '오늘 걸음: $steps 보';
    });

    try {
      final appId = detail.application.id;
      final r = await fetchWalkSync(appId, steps);
      if (!mounted) return;
      setState(() {
        _stepsMonthOverride = r.stepsThisMonth;
        _thresholdOverride = r.threshold;
        _effRateOverride = r.effectiveRate;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('걸음 동기화 완료'), duration: Duration(milliseconds: 1500)),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = _errorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('동기화 실패: $msg'),
            duration: const Duration(milliseconds: 1800)),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<bool> _confirmPayDialog(int round, int amount) async {
    final formatted = NumberFormat('#,###').format(amount);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _TossSheet(
        title: '$round 회차 납입',
        primary: _TossPrimaryButton(
          label: '납입',
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(ctx, true);
          },
        ),
        secondary: _TossOutlineButton(
            label: '취소', onPressed: () => Navigator.pop(ctx, false)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: Text(
                '금액을 확인해 주세요',
                style: TextStyle(fontSize: 14, color: _textWeak),
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
          onRefresh: _softRefresh,
          child: FutureBuilder<ProductAccountDetail>(
            future: _future,
            initialData: _detailCache,
            builder: (context, snap) {
              final detail = _detailCache ?? snap.data;

              if (detail == null &&
                  snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError || detail == null) {
                return ListView(children: const [
                  SizedBox(height: 140),
                  Center(
                      child: Text('상세 데이터를 불러오지 못했습니다.',
                          style: TextStyle(color: _textWeak))),
                ]);
              }

              final acc = detail.account;
              final app = detail.application;
              final principal = (acc?.balance ?? 0);

              final now = DateTime.now();
              final roundNow = (app.startAt == null)
                  ? 1
                  : _currentMonthlyRound(app.startAt!, now);
              final Period bounds = (app.startAt == null)
                  ? Period(
                      DateTime(now.year, now.month, 1),
                      DateTime(now.year, now.month + 1, 1)
                          .subtract(const Duration(seconds: 1)))
                  : _monthCycleBounds(app.startAt!, roundNow);

              final step = _calcMonthlyProgress(detail);

              final totalForUI = _stepsMonthOverride ?? step.total;
              final targetForUI = _thresholdOverride ?? step.target;
              final effRateForUI = _effRateOverride ??
                  (app.effectiveRateAnnual ?? app.baseRateAtEnroll);

              final nextUnpaid = _findNextUnpaid(detail);
              final startAt = app.startAt ?? DateTime.now();
              final nextDue = (nextUnpaid == null)
                  ? null
                  : _computeDueDate(startAt, nextUnpaid.round);
              final today = DateTime.now();

              DateTime _onlyDate(DateTime d) =>
                  DateTime(d.year, d.month, d.day);
              final DateTime todayOnly = _onlyDate(DateTime.now());

              final canPayToday =
                  nextDue != null && fmtYmd(nextDue) == fmtYmd(today);
              final bool canPayNow = nextUnpaid != null &&
                  nextDue != null &&
                  !todayOnly.isBefore(_onlyDate(nextDue));

              final dueText = nextDue == null
                  ? null
                  : (_onlyDate(today).isBefore(_onlyDate(nextDue))
                      ? '예정일 ${fmtYmd(nextDue)}'
                      : '연체: ${fmtYmd(nextDue)}부터');

              final baseRate = app.baseRateAtEnroll ?? 0.0;
              final effRate = effRateForUI ?? baseRate;

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // ===== 파란 그라데이션 헤더 (요청 레이아웃) =====
                  _BlueHeaderCard(
                    productName: app.product.name,
                    accountName: acc?.accountName,
                    accountNumber: acc?.accountNumber ?? '-',
                    principal: principal,
                    hideBalance: _hideBalance,
                    onToggleHide: () =>
                        setState(() => _hideBalance = !_hideBalance),
                    baseRate: baseRate,
                    effectiveRate: effRate,
                    dueText: dueText,
                  ),

                  // ===== 걸음 카드 =====
                  _Section(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('오늘 걸음 수',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _textStrong)),
                              const SizedBox(height: 10),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text('$_stepsToday 걸음',
                                    key: ValueKey(_stepsToday),
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: _textStrong)),
                              ),
                              const SizedBox(height: 6),
                              Text(_healthStatus,
                                  style: const TextStyle(
                                      fontSize: 12, color: _textWeak)),
                              if (_healthStatus.startsWith('❌')) ...[
                                const SizedBox(height: 6),
                                _TossTextButton(
                                    label: '권한 설정 열기',
                                    onPressed: _openAppSettings),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 52,
                          child: _syncing
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: CupertinoActivityIndicator(),
                                )
                              : _TossOutlineButton(
                                  label: '걸음 동기화',
                                  onPressed: () => _syncStepsAuto(detail)),
                        ),
                      ],
                    ),
                  ),

                  // ===== 이번 회차 진행 =====
                  _Section(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('이번 회차 (가입일 기준 월)'),
                        const SizedBox(height: 8),
                        Text(
                          '${NumberFormat('#,###').format(totalForUI)} / ${NumberFormat('#,###').format(targetForUI)} 보',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _textStrong),
                        ),
                        const SizedBox(height: 6),
                        Text(
                            '기간: ${fmtYmd(bounds.start)} ~ ${fmtYmd(bounds.end)}',
                            style: const TextStyle(color: _textWeak)),
                        const SizedBox(height: 12),
                        AnimatedStepBar(total: totalForUI, target: targetForUI),
                      ],
                    ),
                  ),

                  // ===== 다음 납입 + CTA =====
                  _Section(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('다음 납입'),
                        const SizedBox(height: 10),
                        _KvRow('회차',
                            nextUnpaid == null ? '-' : '${nextUnpaid.round}회차'),
                        _KvRow(
                            '예정일', nextDue == null ? '-' : fmtYmdE(nextDue!)),
                        _KvRow(
                            '회차 금액',
                            nextUnpaid == null
                                ? '-'
                                : _won.format(nextUnpaid.amount)),
                        const SizedBox(height: 14),
                        _TossPrimaryButton(
                          label: canPayToday ? '이번 회차 납입' : '오늘은 납입일이 아니에요',
                          onPressed:
                              (nextUnpaid == null || !canPayToday || _paying)
                                  ? null
                                  : () async => _onPressPay(detail),
                          busy: _paying,
                        ),
                      ],
                    ),
                  ),

                  // ===== 요약 =====
                  _Section(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('요약'),
                        const SizedBox(height: 10),
                        _KvRow(
                            '약정 개월수',
                            app.termMonthsAtEnroll == null
                                ? '-'
                                : '${app.termMonthsAtEnroll}개월'),
                        _KvRow('가입일',
                            app.startAt == null ? '-' : fmtYmdE(app.startAt!)),
                        _KvRow('만기일',
                            app.closeAt == null ? '-' : fmtYmdE(app.closeAt!)),
                      ],
                    ),
                  ),

                  // ===== 납입 현황 =====
                  _Section(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('납입 현황'),
                        const SizedBox(height: 6),
                        if (detail.depositPaymentLogList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('표시할 납입 내역이 없습니다.',
                                style: TextStyle(color: _textWeak)),
                          )
                        else
                          ...detail.depositPaymentLogList.map((e) {
                            final isPaid = (e.status ?? PaymentStatus.unpaid) ==
                                PaymentStatus.paid;
                            final due = _computeDueDate(startAt, e.round);
                            final subtitle = isPaid
                                ? '납입일 ${fmtYmd(e.paidAt ?? due)}'
                                : '예정일 ${fmtYmd(due)}';
                            return Column(
                              children: [
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  visualDensity:
                                      const VisualDensity(vertical: -2),
                                  title: Text(
                                      '${e.round}회차  ${_won.format(e.amount)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _textStrong)),
                                  subtitle: Text(subtitle,
                                      style: const TextStyle(color: _textWeak)),
                                  trailing: _StatusPill(
                                    text: isPaid ? '납입완료' : '미납입',
                                    tone: isPaid
                                        ? _ChipTone.success
                                        : _ChipTone.warning,
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

// ====================== 파란 그라데이션 헤더 ======================
// 제목(상품명·계좌번호) ↓ 현재 잔액 ↓ 기본/적용금리 (한 줄 정렬)
// 우상단: 자산 숨기기 버튼 / 오른쪽 끝: 연체 칩(있을 때만, 회색)
class _BlueHeaderCard extends StatelessWidget {
  final String productName;
  final String? accountName;
  final String accountNumber;
  final int principal;
  final bool hideBalance;
  final VoidCallback onToggleHide;
  final double baseRate;
  final double effectiveRate;
  final String? dueText;

  const _BlueHeaderCard({
    super.key,
    required this.productName,
    required this.accountName,
    required this.accountNumber,
    required this.principal,
    required this.hideBalance,
    required this.onToggleHide,
    required this.baseRate,
    required this.effectiveRate,
    this.dueText,
  });

  @override
  Widget build(BuildContext context) {
    final title = accountName?.trim().isNotEmpty == true
        ? accountName!.trim()
        : productName;
    final isOverdue = (dueText ?? '').startsWith('연체');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brand2, _brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === 상단: 타이틀 + 계좌번호 + 숨기기 ===
            Row(
              children: [
                const Icon(CupertinoIcons.creditcard_fill,
                    size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const TextSpan(text: '  ·  '),
                        TextSpan(
                          text: accountNumber,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(.92),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  visualDensity:
                      const VisualDensity(horizontal: -2, vertical: -2),
                  onPressed: onToggleHide,
                  icon: Icon(
                    hideBalance ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                    size: 20,
                    color: Colors.white.withOpacity(.95),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // === 현재 잔액 ===
            Text('현재 잔액',
                style: TextStyle(color: Colors.white.withOpacity(.85))),
            const SizedBox(height: 6),
            hideBalance
                ? Container(
                    height: 30,
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )
                : DiffHighlight(
                    marker: principal,
                    highlightOnFirstBuild: true,
                    child: MoneyCountUp(
                      value: principal,
                      formatter: _won,
                      animateOnFirstBuild: true,
                      duration: const Duration(milliseconds: 650),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
            const SizedBox(height: 14),

            // === 하단: 기본/적용/연체 (한 줄 정렬) ===
            Row(
              children: [
                // 기본금리
                const _BaseRateTextChip(),
                const SizedBox(width: 4),
                Text(
                  '${baseRate.toStringAsFixed(2)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),

                // 적용금리(노란색 + ↑ 펄스)
                const _EffRateTextChip(),
                const SizedBox(width: 4),
                _EffRateNumber(from: baseRate, to: effectiveRate),

                // 오른쪽 끝: 연체 칩(연한 회색)
                const Spacer(),
                if (isOverdue) _OverdueBadge(text: dueText!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// === 텍스트 라벨: "기본"
class _BaseRateTextChip extends StatelessWidget {
  const _BaseRateTextChip({super.key});
  @override
  Widget build(BuildContext context) {
    return const Text(
      '기본',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 0.2,
      ),
    );
  }
}

// === 텍스트 라벨: "적용"
class _EffRateTextChip extends StatelessWidget {
  const _EffRateTextChip({super.key});
  @override
  Widget build(BuildContext context) {
    return const Text(
      '적용',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 0.2,
      ),
    );
  }
}

// === 적용 금리 숫자 (노란색 + 크게 + 카운트업 + ↑ 펄스)
class _EffRateNumber extends StatefulWidget {
  final double from;
  final double to;
  const _EffRateNumber({super.key, required this.from, required this.to});
  @override
  State<_EffRateNumber> createState() => _EffRateNumberState();
}

class _EffRateNumberState extends State<_EffRateNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.to > widget.from) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final up = widget.to > widget.from;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: widget.from, end: widget.to),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${value.toStringAsFixed(2)}%',
              style: TextStyle(
                color: Colors.amber.shade300,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                shadows: const [
                  Shadow(
                    blurRadius: 6,
                    color: Color(0x55000000),
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
            if (up) ...[
              const SizedBox(width: 4),
              FadeTransition(
                opacity: _pulse.drive(Tween(begin: .45, end: 1.0)),
                child: const Icon(
                  CupertinoIcons.arrow_up_right_circle_fill,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// === 연체 칩 (연한 회색)
class _OverdueBadge extends StatelessWidget {
  final String text;
  const _OverdueBadge({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6), // 연한 회색 배경
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF374151), // 진회색 텍스트
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ====================== 공용 섹션/버튼/칩 ======================
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
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(color: _cardShadow, blurRadius: 10, offset: Offset(0, 2))
          ],
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
    return Text(text,
        style:
            const TextStyle(fontWeight: FontWeight.w800, color: _textStrong));
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
          Text(v,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: _textStrong)),
        ],
      ),
    );
  }
}

enum _ChipTone { neutral, success, warning }

class _StatusPill extends StatelessWidget {
  final String text;
  final _ChipTone tone;
  const _StatusPill({required this.text, this.tone = _ChipTone.neutral});
  @override
  Widget build(BuildContext context) {
    Color fg;
    Color bg;
    switch (tone) {
      case _ChipTone.success:
        fg = const Color(0xFF0A7A33);
        bg = const Color(0xFFE8F5ED);
        break;
      case _ChipTone.warning:
        fg = _warn;
        bg = const Color(0xFFFFF3E0);
        break;
      default:
        fg = const Color(0xFF1F2937);
        bg = const Color(0xFFF3F4F6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child:
          Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _TossPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const _TossPrimaryButton(
      {required this.label, required this.onPressed, this.busy = false});
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
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
          side: const BorderSide(color: _line, width: 1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

// 바텀시트 느낌의 토스풍 다이얼로그
class _TossSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget primary;
  final Widget? secondary;
  const _TossSheet(
      {required this.title,
      required this.child,
      required this.primary,
      this.secondary});

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
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textStrong)),
            const SizedBox(height: 10),
            child,
            if (secondary != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: secondary!),
                const SizedBox(width: 8),
                Expanded(child: primary)
              ]),
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

// ===== 걸음 진행바 =====
class AnimatedStepBar extends StatefulWidget {
  final int total;
  final int target;
  final Duration duration;
  final Curve curve;

  const AnimatedStepBar({
    super.key,
    required this.total,
    required this.target,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedStepBar> createState() => _AnimatedStepBarState();
}

class _AnimatedStepBarState extends State<AnimatedStepBar> {
  double _prevRatio = 0.0;

  @override
  void didUpdateWidget(covariant AnimatedStepBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.total != widget.total || oldWidget.target != widget.target) {
      _prevRatio =
          (oldWidget.total / (oldWidget.target == 0 ? 1 : oldWidget.target))
              .clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetRatio =
        (widget.total / (widget.target == 0 ? 1 : widget.target))
            .clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: _prevRatio, end: targetRatio),
            duration: widget.duration,
            curve: widget.curve,
            onEnd: () => _prevRatio = targetRatio,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: Colors.grey.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(_blue),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: _prevRatio, end: targetRatio),
            duration: widget.duration,
            curve: widget.curve,
            builder: (context, value, _) {
              final curr = (value * widget.target).round();
              return Text('$curr / ${widget.target} 보',
                  style: Theme.of(context).textTheme.bodySmall);
            },
          ),
        ),
      ],
    );
  }
}
