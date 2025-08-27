import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reframe/constants/color.dart';

import 'package:reframe/model/product_application.dart';
import 'package:reframe/pages/account/account_detail_page.dart';
import 'package:reframe/service/my_service.dart';

/// ====== 스타일 토큰
const _bg = Colors.white;
const _card = Colors.white;
const _tStrong = Color(0xFF0B0D12);
const _tWeak = Color(0xFF6B7280);
const _brand = Color(0xFF3182F6);
const _success = Color(0xFF16A34A);
const _warn = Color(0xFFF59E0B);
const _muted = Color(0xFF9CA3AF);

final _dateFmt = DateFormat('yyyy.MM.dd');

class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage> {
  late Future<List<ProductApplication>> _future;

  // ---------- 필터/정렬 상태 ----------
  String _cat = '전체'; // 전체 / 예금 / 적금 / 입출금자유
  String _stat = '전체'; // 전체 / 진행중 / 만기 / 해지

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
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AccountDetailPage(accountId: accountId)));
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
            (_stat == '만기' && s == 'CLOSED') ||
            (_stat == '해지' && s == 'CANCELED');
      });
    }
    return it.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('내가 가입한 상품'),
        centerTitle: true,
        backgroundColor: _bg,
        foregroundColor: _tStrong,
        elevation: 0.3,
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
            color: _brand,
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
                  const SliverToBoxAdapter(child: _EmptyView())
                else if (items.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 36, 16, 8),
                      child: Column(
                        children: const [
                          Icon(Icons.filter_list_off_rounded,
                              size: 44, color: _muted),
                          SizedBox(height: 10),
                          Text('선택한 조건에 맞는 상품이 없어요.',
                              style: TextStyle(
                                  color: _tStrong,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('필터를 변경해 보세요.', style: TextStyle(color: _tWeak)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _ApplicationCard(
                        app: items[i],
                        onTap: () => _onTap(items[i].productAccount.id),
                      ),
                    ),
                  ),
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
    final cats = ['전체', '예금', '적금', '입출금자유'];
    final stats = ['전체', '진행중', '만기', '해지'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _ChipRow(
              labels: cats,
              selected: cat,
              onSelected: onChangeCat,
            ),
          ),
          const SizedBox(width: 8),
          _PillDropdown(
            value: stat,
            items: stats,
            onChanged: onChangeStat,
          ),
        ],
      ),
    );
  }
}

/// ====== 드롭다운(자연스러운 pill 스타일 + 그림자, 언더라인/테두리 없음)
class _PillDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _PillDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 메뉴 텍스트 스타일 통일
    final textStyle = const TextStyle(
        fontSize: 12, color: _tStrong, fontWeight: FontWeight.w600);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(999), // ✅ 각진 사각형 제거 → pill
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000), // 8% 블러
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: Theme(
          // 드롭다운 메뉴의 배경/텍스트 톤 살짝 개선
          data: Theme.of(context).copyWith(
            // M2 기준 DropdownButton은 메뉴 모양 커스터마이즈가 제한됨.
            // 가능한 범위 내에서 색/텍스트만 맞춰줌.
            canvasColor: Colors.white,
          ),
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            items: items
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: textStyle),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            icon: const Icon(Icons.expand_more_rounded,
                size: 18, color: _tStrong),
            style: textStyle, // 트리거 텍스트 스타일
          ),
        ),
      ),
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
            backgroundColor: _card,
            side: BorderSide.none, // 칩도 더 부드럽게
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

/// ====== 카드 (테두리 없이 그림자만으로 구분)
class _ApplicationCard extends StatelessWidget {
  final ProductApplication app;
  final VoidCallback? onTap;

  const _ApplicationCard({required this.app, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dday = _calcDDay(app.closeAt);
    final status = app.status?.name.toUpperCase() ?? '-';
    final iconPack = _iconByCategory(app.product.category);

    String? ddayText;
    if (dday != null) {
      if (dday < 0)
        ddayText = '만기 지남';
      else if (dday == 0)
        ddayText = 'D-DAY';
      else
        ddayText = 'D-$dday';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            // ✅ 테두리 제거, 그림자만
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              _CategoryIcon(
                  icon: iconPack.icon, bg: iconPack.bg, fg: iconPack.fg),
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
                          fontWeight: FontWeight.w700,
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
                          fontWeight: FontWeight.w600,
                          color: dday != null && dday <= 7 && dday >= 0
                              ? _warn
                              : _tWeak,
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
    return _CatIconPack(Icons.savings_rounded, const Color(0xFFE6F0FF),
        const Color(0xFF1E66F5));
  } else if (c == '적금') {
    return _CatIconPack(Icons.calendar_month_rounded, const Color(0xFFEFFAF0),
        const Color(0xFF16A34A));
  } else if (c == '입출금자유') {
    return _CatIconPack(Icons.account_balance_wallet_rounded,
        const Color(0xFFFFF3E6), const Color(0xFFEA580C));
  }
  return _CatIconPack(Icons.account_balance_rounded, const Color(0xFFF1F5F9),
      const Color(0xFF64748B));
}

class _CategoryIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  const _CategoryIcon({required this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
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
      'STARTED' => _success,
      'CLOSED' => _muted,
      'CANCELED' => _warn,
      _ => _muted
    };
    final label = switch (status) {
      'STARTED' => '진행중',
      'CLOSED' => '만기',
      'CANCELED' => '해지',
      _ => status
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        // ✅ 테두리 없이 그림자만으로 띄움
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, color: tone, fontWeight: FontWeight.w700)),
    );
  }
}

/// ====== 상태 뷰들 (간단 유지)
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Icon(Icons.inbox_rounded, size: 48, color: _muted),
        SizedBox(height: 12),
        Center(
          child: Text('가입한 상품이 없어요',
              style: TextStyle(
                  fontSize: 16, color: _tStrong, fontWeight: FontWeight.w600)),
        ),
        SizedBox(height: 6),
        Center(
            child: Text('상품을 가입하면 이곳에서 확인할 수 있어요.',
                style: TextStyle(color: _tWeak))),
        SizedBox(height: 20),
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
        const SizedBox(height: 120),
        const Icon(Icons.error_outline_rounded, size: 48, color: _warn),
        const SizedBox(height: 12),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, color: _tStrong, fontWeight: FontWeight.w600),
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          // ✅ 테두리 없음 + 그림자만
          boxShadow: const [
            BoxShadow(
              color: Color(0x13000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 56,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ]),
      ),
    );
  }
}
