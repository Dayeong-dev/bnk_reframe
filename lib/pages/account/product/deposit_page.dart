import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:reframe/service/account_service.dart';
import '../../../core/interceptors/http.dart';
import '../../../model/product_account_detail.dart';

final _won =
    NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);
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
    _future = fetchAccountDetailModel(widget.accountId);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => setState(() {
          _future = fetchAccountDetailModel(widget.accountId);
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
            final maturityAmountProjected =
                detail.maturityAmountProjected; // null이면 만기 없음
            // final projectedNetInterest = (projectedInterestNow * 0.846).floor(); // 세후(15.4%)

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // === 헤더 요약 (토스/카카오 느낌) ===
                _HeaderSummary(
                    title: acc?.accountName ?? '상품계좌',
                    accountMasked: acc!.accountNumber,
                    principalText: _won.format(principal),
                    ddayText: close == null
                        ? '만기 없음'
                        : (dday! >= 0 ? 'D-$dday' : '만기 지남'),
                    start: start,
                    close: close),
                const SizedBox(height: 16),

                _SectionGroup(children: [
                  _RowKV('만기일', close == null ? '만기 없음' : _date.format(close)),
                  _RowKV(
                      '약정 개월수',
                      app.termMonthsAtEnroll == null
                          ? '-'
                          : '${app.termMonthsAtEnroll}개월'),
                  _RowKV('현재 적용금리', '${rateEffective.toStringAsFixed(2)}%'),
                ]),

                const SizedBox(height: 12),

                _SectionGroup(children: [
                  _RowKV('가입일', start == null ? '-' : _date.format(start)),
                  _RowKV('만기일', close == null ? '-' : _date.format(close)),
                ]),

                const SizedBox(height: 12),

                _SectionGroup(children: [
                  _RowKV('현재까지 이자(세전)', _won.format(projectedInterestNow)),
                  if (maturityAmountProjected != null)
                    _RowKV(
                        '만기 예상 수령액(세전)', _won.format(maturityAmountProjected)),
                ]),

                const SizedBox(height: 20)
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
  final String principalText;
  final String ddayText;
  DateTime? start;
  DateTime? close;

  _HeaderSummary(
      {super.key,
      required this.title,
      required this.accountMasked,
      required this.principalText,
      required this.ddayText,
      this.start,
      this.close});

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
        Text(
          principalText,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            // 고정폭 느낌 (가독성)
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        (start != null && close != null
            ? CountdownBar(start: start, close: close)
            : SizedBox())
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
    final border = Divider.createBorderSide(context,
        width: 0.4, color: Colors.grey.withOpacity(0.25));
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
  final String v;
  const _RowKV(this.k, this.v, {super.key});

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.grey[600],
        );
    final value = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(k, style: label)),
          const SizedBox(width: 12),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: value)),
        ],
      ),
    );
  }
}

/// 남은 일수 진행바
class CountdownBar extends StatelessWidget {
  final DateTime? start;
  final DateTime? close;
  const CountdownBar({super.key, this.start, this.close});

  @override
  Widget build(BuildContext context) {
    if (start == null || close == null) return const SizedBox.shrink();
    final today = DateTime.now();
    final total = close!
        .difference(DateTime(start!.year, start!.month, start!.day))
        .inDays;
    final left =
        close!.difference(DateTime(today.year, today.month, today.day)).inDays;
    final done = (total - left).clamp(0, total);
    final progress = total <= 0 ? 1.0 : done / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.withOpacity(0.15),
          ),
        ),
        const SizedBox(height: 6),
        Text('진행 ${done}일 / 총 ${total}일',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
