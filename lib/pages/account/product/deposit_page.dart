import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:reframe/service/account_service.dart';
import '../../../constants/text_animation.dart';
import '../../../model/product_account_detail.dart';

/// ===== 팔레트: 리뷰 헤더 느낌과 동일 톤 =====
const _brand = Color(0xFF304FFE); // 포인트
const _brand2 = Color(0xFF3B82F6); // 그라데이션 앞쪽 블루
const _ink = Color(0xFF0B0D12); // 본문 진한 텍스트
const _inkWeak = Color(0xFF6B7280); // 보조 텍스트
const _cardLine = Color(0xFFE6EAF0); // 옅은 보더
const _chipBg = Color(0xFFF1F4FF); // Pill 배경(라이트)
const _chipFg = _brand; // Pill 텍스트/아이콘
const _headerGradA = Color(0xFFF7F9FF); // 라이트 그라데이션(미사용, 참고)
const _headerGradB = Color(0xFFFFFFFF);

/// ===== 포맷터 (₩, 날짜) =====
final _won =
    NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);
final _won2 =
    NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 2);
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

  Future<void> _reload() async {
    setState(() {
      _future = fetchAccountDetail(widget.accountId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _reload,
        color: Theme.of(context).colorScheme.primary,
        child: FutureBuilder<ProductAccountDetail>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('상세 데이터를 불러오지 못했습니다.')),
                ],
              );
            }

            final detail = snap.data!;
            final acc = detail.account;
            final app = detail.application;

            if (acc == null) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('계좌 정보가 없습니다.')),
                ],
              );
            }

            // ===== 계산/가공 =====
            final principal = (acc.balance ?? 0);
            final start = app.startAt;
            final close = app.closeAt;
            final rateBase = app.baseRateAtEnroll ?? 0;
            final rateEffective = app.effectiveRateAnnual ?? rateBase;

            // D-day 계산(만기 없는 경우 null)
            int? dday;
            if (close != null) {
              final today = DateTime.now();
              final end = DateTime(close.year, close.month, close.day);
              final day0 = DateTime(today.year, today.month, today.day);
              dday = end.difference(day0).inDays;
            }
            final ddayText =
                close == null ? '만기 없음' : (dday! >= 0 ? 'D-$dday' : '만기 지남');

            final projectedInterestNow = detail.projectedInterestNow ?? 0;
            final maturityAmountProjected =
                detail.maturityAmountProjected; // null이면 만기 없음

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                /// ===== 파란 그라데이션 헤더 (리뷰 헤더 스타일 적용) =====
                _BlueHeaderCard(
                  title: acc.accountName ?? app.product.name,
                  accountMasked: acc.accountNumber ?? '',
                  principal: principal,
                  ddayText: ddayText,
                  start: start,
                  close: close,
                ),
                const SizedBox(height: 16),

                /// ===== 이자/만기 예상 =====
                _SectionGroup(children: [
                  _RowKV.withWidget(
                    '현재까지 이자(세전)',
                    LiveInterestTicker(
                      principal: principal,
                      annualRatePercent: rateEffective, // 연이율(%)
                      start: start,
                      end: close,
                      formatter: _won2, // 소수점 2자리(원하면 _won으로 교체)
                    ),
                  ),
                  if (maturityAmountProjected != null)
                    _RowKV(
                        '만기 예상 수령액(세전)', _won.format(maturityAmountProjected)),
                ]),
                const SizedBox(height: 16),

                /// ===== 약정/금리 정보 =====
                _SectionGroup(children: [
                  _RowKV(
                    '약정 기간',
                    (app.termMonthsAtEnroll == null)
                        ? '-'
                        : '${app.termMonthsAtEnroll}개월',
                  ),
                  _RowKV('가입일', start == null ? '-' : _date.format(start)),
                  _RowKV('만기일', close == null ? '-' : _date.format(close)),
                  _RowKV(
                    '현재 적용 금리',
                    '${rateEffective.toStringAsFixed(2)}%',
                  ),
                ]),
                const SizedBox(height: 8),

                /// (옵션) 참고 정보
                if (projectedInterestNow > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '※ 세후 금액은 상품/세율에 따라 달라질 수 있어요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// 리뷰 페이지의 파란 배너 무드를 적용한 헤더 카드
/// - 그라데이션 배경 + 화이트 계열 칩 + 소프트 섀도
/// - 큰 금액 카운트업 + 진행바
/// ─────────────────────────────────────────────────────────
class _BlueHeaderCard extends StatelessWidget {
  final String title;
  final String accountMasked;
  final num principal;
  final String ddayText;
  final DateTime? start;
  final DateTime? close;

  const _BlueHeaderCard({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : const LinearGradient(
                colors: [_brand2, _brand],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isDark ? const Color(0xFF16181A) : null,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 타이틀 + D-day 칩
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                ),
              ),
              _HeaderChip.light(
                icon: Icons.event_available_rounded,
                text: ddayText,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 계좌번호(흰색 약간 투명)
          Text(
            accountMasked,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(.9),
                  letterSpacing: 0.2,
                ),
          ),
          const SizedBox(height: 12),

          // 금액 라벨
          Text(
            '현재 잔액(원금)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(.85),
                ),
          ),
          const SizedBox(height: 6),

          // 큰 금액(애니메이션 카운트업)
          DiffHighlight(
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
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),

          // 진행바
          if (start != null && close != null) ...[
            const SizedBox(height: 12),
            _BrandCountdownBar(start: start, close: close),
          ],
        ],
      ),
    );
  }
}

/// 리뷰 헤더 느낌의 칩 (화이트/반투명)
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool inverted;
  const _HeaderChip({
    super.key,
    required this.icon,
    required this.text,
    this.inverted = false,
  });

  factory _HeaderChip.light({required IconData icon, required String text}) {
    return _HeaderChip(icon: icon, text: text, inverted: false);
  }

  @override
  Widget build(BuildContext context) {
    final bg = inverted ? Colors.white : Colors.white24;
    final fg = inverted ? _brand : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ]),
    );
  }
}

/// 진행바(연회색 트랙 + 브랜드 채움)
class _BrandCountdownBar extends StatelessWidget {
  final DateTime? start;
  final DateTime? close;
  const _BrandCountdownBar({super.key, this.start, this.close});

  @override
  Widget build(BuildContext context) {
    if (start == null || close == null) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1), // 내부 위젯 애니메이션만 사용
      builder: (_, __, ___) {
        return _CountdownBarStyled(start: start!, close: close!);
      },
    );
  }
}

/// 기존 로직을 유지하고 색상만 통일
class _CountdownBarStyled extends StatefulWidget {
  final DateTime start;
  final DateTime close;
  const _CountdownBarStyled(
      {super.key, required this.start, required this.close});

  @override
  State<_CountdownBarStyled> createState() => _CountdownBarStyledState();
}

class _CountdownBarStyledState extends State<_CountdownBarStyled> {
  double _prev = 0.0;

  static double _calcProgress(DateTime start, DateTime close) {
    final today = DateTime.now();
    final total =
        close.difference(DateTime(start.year, start.month, start.day)).inDays;
    if (total <= 0) return 1.0;
    final left =
        close.difference(DateTime(today.year, today.month, today.day)).inDays;
    final done = (total - left).clamp(0, total);
    return done / total;
  }

  @override
  void initState() {
    super.initState();
    _prev = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final total = widget.close
        .difference(
            DateTime(widget.start.year, widget.start.month, widget.start.day))
        .inDays;
    final left = widget.close
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final done = (total - left).clamp(0, total);
    final target = total <= 0 ? 1.0 : (done / total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: _prev, end: target),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            onEnd: () => _prev = target,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: const Color(0xFFEDEFF5), // 연회색 트랙
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFC107)), // 노란색 채움
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: _prev, end: target),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            final currDone =
                (value * (total <= 0 ? 0 : total)).round().clamp(0, total);
            return Text(
              '진행 ${currDone}일 / 총 ${total}일',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(.9),
                  ),
            );
          },
        ),
      ],
    );
  }
}

/// 섹션 카드(흰 배경 + 얇은 선 + 라운드)
class _SectionGroup extends StatelessWidget {
  final List<Widget> children;
  const _SectionGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : _cardLine;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111315) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i != 0)
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? borderColor.withOpacity(0.85) : borderColor,
              ),
            children[i],
          ]
        ],
      ),
    );
  }
}

/// Key-Value 한 줄
class _RowKV extends StatelessWidget {
  final String k;
  final String? v;
  final Widget? vWidget;

  const _RowKV(this.k, this.v, {super.key}) : vWidget = null;
  const _RowKV.withWidget(this.k, this.vWidget, {super.key}) : v = null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.white70 : _inkWeak,
        );
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: isDark ? Colors.white : _ink,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(k, style: label)),
          const SizedBox(width: 12),
          Flexible(
            child: vWidget ??
                Text(
                  v ?? '-',
                  textAlign: TextAlign.right,
                  style: valueStyle,
                ),
          ),
        ],
      ),
    );
  }
}

/// ===== 숫자 롤링/실시간 이자 틱업: 기존 로직 유지 =====

/// 자리별 롤링 텍스트(탭룰라 숫자)
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
  late String _display;
  late String _target;

  @override
  void initState() {
    super.initState();
    final from =
        widget.animateOnFirstBuild ? (widget.initialFrom ?? 0) : widget.value;
    _display = widget.formatter.format(from);
    _target = widget.formatter.format(widget.value);

    if (widget.animateOnFirstBuild && _display != _target) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _display = _target);
      });
    } else {
      _display = _target;
    }
  }

  @override
  void didUpdateWidget(RollingNumberText old) {
    super.didUpdateWidget(old);
    final newTarget = widget.formatter.format(widget.value);
    if (newTarget != _target) {
      _target = newTarget;
      setState(() => _display = _target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final maxLen =
        _display.length > _target.length ? _display.length : _target.length;
    final padDisp = _display.padLeft(maxLen);
    final padTgt = _target.padLeft(maxLen);

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
            final offset =
                Tween<Offset>(begin: const Offset(0, 0.45), end: Offset.zero)
                    .chain(CurveTween(curve: widget.curve))
                    .animate(anim);
            return SlideTransition(
              position: offset,
              child: FadeTransition(opacity: anim, child: child),
            );
          },
          child: Text(
            ch,
            key: ValueKey('$i-$ch'),
            style: style,
          ),
        );
      }),
    );
  }
}

/// 실시간 이자(세전) 틱업
/// - ACT/365 단리 가정
/// - 만기 도달 시 자동 정지
class LiveInterestTicker extends StatefulWidget {
  final num principal;
  final double annualRatePercent;
  final DateTime? start;
  final DateTime? end;
  final NumberFormat formatter;
  final Duration tick;
  final bool animateOnFirstBuild;

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

  static const _secondsPerYear = 365 * 24 * 60 * 60;

  num _interestAt(DateTime now) {
    if (widget.start == null) return 0;
    final effectiveEnd =
        (widget.end != null && now.isAfter(widget.end!)) ? widget.end! : now;
    if (effectiveEnd.isBefore(widget.start!)) return 0;

    final elapsedSec = effectiveEnd.difference(widget.start!).inSeconds;
    final rate = widget.annualRatePercent / 100.0;
    final raw =
        widget.principal.toDouble() * rate * (elapsedSec / _secondsPerYear);

    // 표시 자리수 반올림
    final decimals = widget.formatter.decimalDigits ?? 0;
    final factor = MathPow.pow(10, decimals).toDouble();
    return (raw * factor).round() / factor;
  }

  void _tick() {
    final now = DateTime.now();
    final newVal = _interestAt(now);
    if (!mounted) return;
    setState(() => _value = newVal);

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

/// 간단 pow (정수 거듭제곱)
class MathPow {
  static num pow(num base, int exponent) {
    num result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
