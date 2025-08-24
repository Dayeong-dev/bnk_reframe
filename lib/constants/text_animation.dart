// 값 변경 하이라이트
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DiffHighlight extends StatefulWidget {
  final Object marker;
  final Widget child;
  final Duration duration;
  final bool highlightOnFirstBuild;

  const DiffHighlight({
    super.key,
    required this.marker,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.highlightOnFirstBuild = false,
  });

  @override
  State<DiffHighlight> createState() => _DiffHighlightState();
}

class _DiffHighlightState extends State<DiffHighlight> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);

    if (widget.highlightOnFirstBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ac..value = 1..reverse();
      });
    }
  }

  @override
  void didUpdateWidget(covariant DiffHighlight old) {
    super.didUpdateWidget(old);
    if (old.marker != widget.marker) {
      _ac..stop()..value = 1..reverse();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _fade,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


// 카운트업(₩ 촤라락)
class MoneyCountUp extends StatefulWidget {
  final num value;
  final NumberFormat formatter;
  final Duration duration;
  final Curve curve;
  final TextStyle? style;

  final bool animateOnFirstBuild; // 첫 진입 때도 0→value
  final num? initialFrom;

  const MoneyCountUp({
    super.key,
    required this.value,
    required this.formatter,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
    this.style,
    this.animateOnFirstBuild = false,
    this.initialFrom,
  });

  @override
  State<MoneyCountUp> createState() => _MoneyCountUpState();
}

class _MoneyCountUpState extends State<MoneyCountUp> {
  late double _from;

  @override
  void initState() {
    super.initState();
    _from = (widget.animateOnFirstBuild ? (widget.initialFrom ?? 0) : widget.value).toDouble();
  }

  @override
  void didUpdateWidget(MoneyCountUp old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _from = old.value.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.value),
      tween: Tween(begin: _from, end: widget.value.toDouble()),
      duration: widget.duration,
      curve: widget.curve,
      builder: (_, v, __) => Text(widget.formatter.format(v), style: style, textAlign: TextAlign.right),
    );
  }
}