import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reframe/constants/color.dart';

import 'package:reframe/model/product_application.dart';
import 'package:reframe/pages/account/account_detail_page.dart';
import 'package:reframe/service/my_service.dart';

/// ====== 스타일 토큰
const _bg       = Colors.white;
const _card     = Colors.white;
const _line     = Color(0xFFE5E7EB);
const _tStrong  = Color(0xFF0B0D12);
const _tWeak    = Color(0xFF6B7280);
const _brand    = Color(0xFF3182F6);
const _success  = Color(0xFF16A34A);
const _warn     = Color(0xFFF59E0B);
const _muted    = Color(0xFF9CA3AF);

final _dateFmt  = DateFormat('yyyy.MM.dd');

class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage> {
  late Future<List<ProductApplication>> _future;

  // ---------- 필터/정렬 상태 ----------
  String _cat = '전체';   // 전체 / 예금 / 적금 / 입출금자유
  String _stat = '전체';  // 전체 / 진행중 / 만기 / 해지

  @override
  void initState() {
    super.initState();
    _future = getMyApplications();
  }

  Future<void> _refresh() async {
    setState(() => _future = getMyApplications());
    await _future;
  }

  void _onTap(int accountId) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AccountDetailPage(accountId: accountId)));
  }

  // ---------- 필터/정렬 로직 ----------
  List<ProductApplication> _filtered(List<ProductApplication> src) {
    Iterable<ProductApplication> it = src;

    if (_cat != '전체') {
      it = it.where((a) => (a.product.category ?? '').trim() == _cat);
    }

    if (_stat != '전체') {
      it = it.where((a) {
        final s = a.status?.name.toUpperCase();
        return (_stat == '진행중' && s == 'STARTED') ||
            (_stat == '만기'   && s == 'CLOSED')  ||
            (_stat == '해지'   && s == 'CANCELED');
      });
    }

    final list = it.toList();

    int ddayOf(ProductApplication a) {
      final c = a.closeAt;
      if (c == null) return 1 << 20; // D-day 없는 항목은 뒤로
      final today = DateTime.now();
      final t0 = DateTime(today.year, today.month, today.day);
      final c0 = DateTime(c.year, c.month, c.day);
      return c0.difference(t0).inDays;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('내가 가입한 상품'),
        centerTitle: true,
        backgroundColor: _bg,
        foregroundColor: _tStrong,
        elevation: 0.5,
        surfaceTintColor: _bg,
      ),
      body: FutureBuilder<List<ProductApplication>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _SkeletonList();
          }
          if (snap.hasError) {
            return _ErrorView(
              message: '목록을 불러오지 못했어요.\n다시 시도해 주세요.',
              onRetry: _refresh,
            );
          }

          final all = snap.data ?? const [];
          final items = _filtered(all);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _FilterBar(
                    cat: _cat,
                    stat: _stat,
                    onChangeCat: (v) => setState(() => _cat = v),
                    onChangeStat: (v) => setState(() => _stat = v),
                  ),
                ),
                if (all.isEmpty)
                  SliverToBoxAdapter(child: _EmptyView(onRefresh: _refresh))
                else if (items.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
                      child: Column(
                        children: const [
                          Icon(Icons.filter_list_off_rounded, size: 48, color: _muted),
                          SizedBox(height: 12),
                          Text('선택한 조건에 맞는 상품이 없어요.', style: TextStyle(color: _tStrong, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('필터를 변경해 보세요.', style: TextStyle(color: _tWeak)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ApplicationCard(
                        app: items[i],
                        onTap: () => _onTap(items[i].productAccount.id),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ====== 필터 바
class _FilterBar extends StatelessWidget {
  final String cat;
  final String stat;
  final ValueChanged<String> onChangeCat;
  final ValueChanged<String> onChangeStat;

  const _FilterBar({
    required this.cat,
    required this.stat,
    required this.onChangeCat,
    required this.onChangeStat,
  });

  @override
  Widget build(BuildContext context) {
    final cats  = ['전체', '예금', '적금', '입출금자유'];
    final stats = ['전체', '진행중', '만기', '해지'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ChipRow(
            labels: cats,
            selected: cat,
            onSelected: onChangeCat,
          ),
          Spacer(),
          _LabeledDropdown(
            value: stat,
            items: stats,
            onChanged: onChangeStat,
          )
        ],
      ),
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _LabeledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              items: items
                  .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(fontSize: 12)),
              ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              icon: const Icon(Icons.expand_more_rounded, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}


class _ChipRow extends StatelessWidget {
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ChipRow({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final l in labels)
          ChoiceChip(
            label: Text(l),
            selected: selected == l,
            onSelected: (_) => onSelected(l),
            labelStyle: TextStyle(
              color: selected == l ? Colors.white : _tStrong,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            selectedColor: _brand,
            backgroundColor: Colors.white,
            side: const BorderSide(color: _line),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

/// ====== 카드 (핵심만 슬림하게)
class _ApplicationCard extends StatelessWidget {
  final ProductApplication app;
  final VoidCallback? onTap;

  const _ApplicationCard({required this.app, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dday   = _calcDDay(app.closeAt);
    final status = app.status?.name.toUpperCase() ?? '-';
    final iconPack = _iconByCategory(app.product.category);

    String? ddayText;
    if (dday != null) {
      if (dday < 0) ddayText = '만기 지남';
      else if (dday == 0) ddayText = 'D-DAY';
      else ddayText = 'D-$dday';
    }

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              _CategoryIcon(icon: iconPack.icon, bg: iconPack.bg, fg: iconPack.fg),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        app.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _tStrong,
                        ),
                      ),
                    ),
                    if (ddayText != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        ddayText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: dday != null && dday <= 7 && dday >= 0 ? _warn : _tWeak,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: status),
            ],
          ),
        ),
      ),
    );
  }

  static int? _calcDDay(DateTime? close) {
    if (close == null) return null;
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final c0 = DateTime(close.year, close.month, close.day);
    return c0.difference(t0).inDays;
  }
}

/// ====== 카테고리별 아이콘/색상
class _CatIconPack {
  final IconData icon;
  final Color bg;
  final Color fg;
  const _CatIconPack(this.icon, this.bg, this.fg);
}

_CatIconPack _iconByCategory(String? category) {
  final c = (category ?? '').trim();
  if (c == '예금') {
    return _CatIconPack(Icons.savings_rounded, const Color(0xFFE6F0FF), const Color(0xFF1E66F5));
  } else if (c == '적금') {
    return _CatIconPack(Icons.calendar_month_rounded, const Color(0xFFEFFAF0), const Color(0xFF16A34A));
  } else if (c == '입출금자유') {
    return _CatIconPack(Icons.account_balance_wallet_rounded, const Color(0xFFFFF3E6), const Color(0xFFEA580C));
  }
  return _CatIconPack(Icons.account_balance_rounded, const Color(0xFFF1F5F9), const Color(0xFF64748B));
}

class _CategoryIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  const _CategoryIcon({required this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Icon(icon, size: 22, color: fg),
    );
  }
}

/// ====== 상태 뱃지
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      'STARTED'  => _success,
      'CLOSED'   => _muted,
      'CANCELED' => _warn,
      _          => _muted
    };
    final label = switch (status) {
      'STARTED'  => '진행중',
      'CLOSED'   => '만기',
      'CANCELED' => '해지',
      _          => status
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: tone, fontWeight: FontWeight.w600)),
    );
  }
}

/// ====== 상태 뷰들 (공통)
class _EmptyView extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(Icons.inbox_rounded, size: 48, color: _muted),
        const SizedBox(height: 12),
        const Center(
          child: Text('가입한 상품이 없어요', style: TextStyle(fontSize: 16, color: _tStrong, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        const Center(child: Text('상품을 가입하면 이곳에서 확인할 수 있어요.', style: TextStyle(color: _tWeak))),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('새로고침'),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(Icons.error_outline_rounded, size: 48, color: _warn),
        const SizedBox(height: 12),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: _tStrong, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 시도'),
          ),
        ),
      ],
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(12))),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 16, color: _line)),
          const SizedBox(width: 8),
          Container(width: 56, height: 24, decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(999))),
        ]),
      ),
    );
  }
}
