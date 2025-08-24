import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:reframe/service/account_service.dart';
import '../../../constants/text_animation.dart';
import '../../../model/product_account_detail.dart';

final _won = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);
final _date = DateFormat('yyyy.MM.dd');

class DepositPage extends StatefulWidget {
  final int accountId;
  const DepositPage({super.key, required this.accountId});

  @override
  State<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  late Future<ProductAccountDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchAccountDetail(widget.accountId);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => setState(() {
          _future = fetchAccountDetail(widget.accountId);
        }),
        child: FutureBuilder<ProductAccountDetail>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return ListView(children: const [
                SizedBox(height: 100),
                Center(child: Text('상세 데이터를 불러오지 못했습니다.')),
              ]);
            }

            final detail = snap.data!;
            final acc = detail.account;
            final app = detail.application;

            final principal = (acc?.balance ?? 0);
            final start = app.startAt;
            final close = app.closeAt;
            final rateBase = app.baseRateAtEnroll ?? 0;
            final rateEffective = app.effectiveRateAnnual ?? rateBase;

            final now = DateTime.now();
            int? dday;
            if (close != null) {
              final today = DateTime(now.year, now.month, now.day);
              final end = DateTime(close.year, close.month, close.day);
              dday = end.difference(today).inDays;
            }

            final projectedInterestNow = detail.projectedInterestNow ?? 0;
            final maturityAmountProjected = detail.maturityAmountProjected; // null이면 만기 없음
            // final projectedNetInterest = (projectedInterestNow * 0.846).floor(); // 세후(15.4%)

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // === 헤더 요약 (토스/카카오 느낌) ===
                _HeaderSummary(
                    title: acc?.accountName ?? '상품계좌',
                    accountMasked: acc!.accountNumber,
                    principal: principal,
                    ddayText: close == null
                        ? '만기 없음'
                        : (dday! >= 0 ? 'D-$dday' : '만기 지남'),
                    start: start,
                    close: close
                ),
                const SizedBox(height: 16),

                _SectionGroup(children: [
                  _RowKV.withWidget(
                    '현재까지 이자(세전)',
                    LiveInterestTicker(
                      principal: principal,
                      annualRatePercent: rateEffective, // 적용 금리(연)
                      start: start,                     // 가입일
                      end: close,                       // 만기(없으면 null)
                      // 원 단위 표시(기본):
                      // formatter: NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0),

                      // 소수점 둘째자리까지 보고 싶다면 아래처럼 사용
                      formatter: NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 2),
                    ),
                  ),

                  if (maturityAmountProjected != null)
                    _RowKV('만기 예상 수령액(세전)', _won.format(maturityAmountProjected)),
                ]),
                const SizedBox(height: 20),
                _SectionGroup(children: [
                  _RowKV('만기일', close == null ? '만기 없음' : _date.format(close)),
                  _RowKV('약정 개월수',
                      app.termMonthsAtEnroll == null ? '-' : '${app.termMonthsAtEnroll}개월'),
                  _RowKV('현재 적용금리', '${rateEffective.toStringAsFixed(2)}%'),
                ]),
                const SizedBox(height: 12),
                _SectionGroup(children: [
                  _RowKV('가입일', start == null ? '-' : _date.format(start)),
                  _RowKV('만기일', close == null ? '-' : _date.format(close)),
                ]),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------- 보조 위젯/함수 ----------
class _HeaderSummary extends StatelessWidget {
  final String title;
  final String accountMasked;
  final num principal;
  final String ddayText;
  DateTime? start;
  DateTime? close;

  _HeaderSummary({
    super.key,
    required this.title,
    required this.accountMasked,
    required this.principal,
    required this.ddayText,
    this.start,
    this.close,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181A) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 상단: 계좌명 / D-day 배지
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _Pill(ddayText),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          accountMasked,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '현재 잔액(원금)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        // 큼직한 금액
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
        const SizedBox(height: 4),
        (start != null && close != null ? CountdownBar(start: start, close: close) : SizedBox())
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionGroup extends StatelessWidget {
  final List<Widget> children;
  const _SectionGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final border = Divider.createBorderSide(context, width: 0.4, color: Colors.grey.withOpacity(0.25));
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111315)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i != 0) Divider(height: 1, thickness: 0.4, color: border.color),
            children[i],
          ]
        ],
      ),
    );
  }
}

class _RowKV extends StatelessWidget {
  final String k;
  final String? v;
  final Widget? vWidget;

  const _RowKV(this.k, this.v, {super.key}) : vWidget = null;
  const _RowKV.withWidget(this.k, this.vWidget, {super.key}) : v = null;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.grey[600],
    );
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(k, style: label)),
          const SizedBox(width: 12),
          Flexible(
            child: vWidget ??
                Text(v ?? '-', textAlign: TextAlign.right, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

/// 남은 일수 진행바 (첫 진입 애니메이션)
class CountdownBar extends StatefulWidget {
  final DateTime? start;
  final DateTime? close;

  /// 첫 진입 시 0→progress 애니메이션할지 여부
  final bool animateOnFirstBuild;

  /// 애니메이션 세팅
  final Duration duration;
  final Curve curve;

  const CountdownBar({
    super.key,
    this.start,
    this.close,
    this.animateOnFirstBuild = true,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<CountdownBar> {
  double _prev = 0.0;

  static double _calcProgress(DateTime? start, DateTime? close) {
    if (start == null || close == null) return 0.0;
    final today = DateTime.now();
    final total = close.difference(DateTime(start.year, start.month, start.day)).inDays;
    if (total <= 0) return 1.0;
    final left = close.difference(DateTime(today.year, today.month, today.day)).inDays;
    final done = (total - left).clamp(0, total);
    return done / total;
  }

  @override
  void initState() {
    super.initState();
    final p = _calcProgress(widget.start, widget.close);
    _prev = widget.animateOnFirstBuild ? 0.0 : p;
  }

  @override
  void didUpdateWidget(covariant CountdownBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 진행률이 변한 경우(날짜/데이터 갱신) 이전 진행률에서 새 진행률로 애니메이션
    final oldP = _calcProgress(oldWidget.start, oldWidget.close);
    _prev = oldP;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.start == null || widget.close == null) return const SizedBox.shrink();

    final today = DateTime.now();
    final total = widget.close!
        .difference(DateTime(widget.start!.year, widget.start!.month, widget.start!.day))
        .inDays;
    final left = widget.close!
        .difference(DateTime(today.year, today.month, today.day))
        .inDays
        .clamp(-1 << 31, 1 << 31); // 안전 클램프
    final done = (total - left).clamp(0, total);
    final target = total <= 0 ? 1.0 : (done / total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: _prev, end: target),
            duration: widget.duration,
            curve: widget.curve,
            onEnd: () => _prev = target, // 다음 빌드에서 재시작 방지
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.grey.withOpacity(0.15),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // 라벨 숫자도 같이 자연스럽게 증가
        TweenAnimationBuilder<double>(
          tween: Tween(begin: _prev, end: target),
          duration: widget.duration,
          curve: widget.curve,
          builder: (context, value, _) {
            final currDone = (value * (total <= 0 ? 0 : total)).round().clamp(0, total);
            return Text(
              '진행 ${currDone}일 / 총 ${total}일',
              style: Theme.of(context).textTheme.bodySmall,
            );
          },
        ),
      ],
    );
  }
}

// 2) 자리별 롤링(오도미터)
class RollingNumberText extends StatefulWidget {
  final num value;
  final NumberFormat formatter;
  final Duration duration;
  final Curve curve;
  final TextStyle? style;

  final bool animateOnFirstBuild;
  final num? initialFrom;

  const RollingNumberText({
    super.key,
    required this.value,
    required this.formatter,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOut,
    this.style,
    this.animateOnFirstBuild = false,
    this.initialFrom,
  });

  @override
  State<RollingNumberText> createState() => _RollingNumberTextState();
}

class _RollingNumberTextState extends State<RollingNumberText> {
  late String _display; // 화면에 그릴 "현재 문자열" (처음엔 from, 다음 프레임에 target으로 교체)
  late String _target;  // 최종 문자열

  @override
  void initState() {
    super.initState();
    final from = widget.animateOnFirstBuild ? (widget.initialFrom ?? 0) : widget.value;
    _display = widget.formatter.format(from);
    _target  = widget.formatter.format(widget.value);

    // 첫 진입 롤링: 다음 프레임에 target으로 교체해 AnimatedSwitcher가 작동하도록
    if (widget.animateOnFirstBuild && _display != _target) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _display = _target);
      });
    } else {
      _display = _target; // 애니메이션 필요 없음
    }
  }

  @override
  void didUpdateWidget(RollingNumberText old) {
    super.didUpdateWidget(old);
    final newTarget = widget.formatter.format(widget.value);
    if (newTarget != _target) {
      _target = newTarget;
      setState(() => _display = _target); // 값 변경 시 자리별 롤링
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final maxLen = _display.length > _target.length ? _display.length : _target.length;
    final padDisp = _display.padLeft(maxLen);
    final padTgt  = _target.padLeft(maxLen);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: List.generate(maxLen, (i) {
        final ch = padDisp[i];
        final isDigit = ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;
        if (!isDigit) return Text(ch, style: style);

        return AnimatedSwitcher(
          duration: widget.duration,
          transitionBuilder: (child, anim) {
            final offset = Tween<Offset>(begin: const Offset(0, 0.45), end: Offset.zero)
                .chain(CurveTween(curve: widget.curve))
                .animate(anim);
            return SlideTransition(position: offset, child: FadeTransition(opacity: anim, child: child));
          },
          child: Text(
            ch,
            key: ValueKey('$i-$ch'), // 같은 자릿수의 글자 바뀔 때만 애니메이션
            style: style,
          ),
        );
      }),
    );
  }
}

/// 실시간 이자(세전) 틱업 위젯
/// - ACT/365 단순이자 가정
/// - 만기(end) 도달 시 자동 정지
class LiveInterestTicker extends StatefulWidget {
  final num principal;                 // 납입(원금)
  final double annualRatePercent;      // 연이율(%)
  final DateTime? start;               // 이자 발생 시작 시점
  final DateTime? end;                 // 만기(없으면 null)
  final NumberFormat formatter;        // 표시 포맷 (소수점 2자리 원하면 decimalDigits: 2)
  final Duration tick;                 // 갱신 주기
  final bool animateOnFirstBuild;      // 첫 진입 롤링 여부

  const LiveInterestTicker({
    super.key,
    required this.principal,
    required this.annualRatePercent,
    required this.formatter,
    this.start,
    this.end,
    this.tick = const Duration(milliseconds: 250),
    this.animateOnFirstBuild = true,
  });

  @override
  State<LiveInterestTicker> createState() => _LiveInterestTickerState();
}

class _LiveInterestTickerState extends State<LiveInterestTicker> {
  Timer? _timer;
  num _value = 0;

  static const _secondsPerYear = 365 * 24 * 60 * 60; // ACT/365

  num _interestAt(DateTime now) {
    if (widget.start == null) return 0;
    final end = (widget.end != null && now.isAfter(widget.end!)) ? widget.end! : now;
    if (end.isBefore(widget.start!)) return 0;

    final elapsedSec = end.difference(widget.start!).inSeconds;
    final rate = widget.annualRatePercent / 100.0;

    final raw = widget.principal.toDouble() * rate * (elapsedSec / _secondsPerYear);
    // 표시 자리수에 맞춰 반올림 (원 단위면 정수, 2자리면 소수)
    final decimals = widget.formatter.decimalDigits ?? 0;
    final factor = MathPow.pow(10, decimals).toDouble();
    return (raw * factor).round() / factor;
  }

  void _tick() {
    final now = DateTime.now();
    final newVal = _interestAt(now);
    if (!mounted) return;
    setState(() => _value = newVal);

    // 만기 도달 시 타이머 종료
    if (widget.end != null && now.isAfter(widget.end!)) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _value = _interestAt(DateTime.now());
    _timer = Timer.periodic(widget.tick, (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant LiveInterestTicker old) {
    super.didUpdateWidget(old);
    // 입력 값이 바뀌면 즉시 재계산
    _value = _interestAt(DateTime.now());
    _timer?.cancel();
    _timer = Timer.periodic(widget.tick, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 자리별 롤링 이미 있으니 그대로 활용
    return RollingNumberText(
      value: _value,
      formatter: widget.formatter,
      animateOnFirstBuild: widget.animateOnFirstBuild,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// 간단 pow (dart:math 없이 정수 거듭제곱용)
class MathPow {
  static num pow(num base, int exponent) {
    num result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
