import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:reframe/model/account_transaction.dart';
import '../../../model/product_account_detail.dart';
import '../../../service/account_service.dart';

// 금액 포맷
final _won =
    NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);

// ===== Toss tone colors & text =====
const _tStrong = Color(0xFF0B0D12);
const _tWeak = Color(0xFF6B7280);
const _line = Color(0xFFE5E7EB);
const _blue = Color(0xFF0064FF);
const _bg = Color(0xFFF7F8FA);

TextStyle get _h1 =>
    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _tStrong);
TextStyle get _h2 =>
    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _tStrong);
TextStyle get _b1 =>
    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _tStrong);
TextStyle get _c1 => const TextStyle(fontSize: 13, color: _tWeak, height: 1.3);

// 둥근 화이트 카드
class _TossCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _TossCard(
      {required this.child,
      this.padding = const EdgeInsets.all(16),
      super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18)),
      padding: padding,
      child: child,
    );
  }
}

// 프라이머리 라운드 버튼
class _TossPrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const _TossPrimaryBtn(
      {required this.label, required this.onTap, this.busy = false, super.key});
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: enabled ? _blue : _line,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );
  }
}

// 라운드 아웃라인 버튼 (빠른 액션)
class _TossActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _TossActionButton(
      {required this.icon, required this.label, this.onTap, super.key});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE6FF)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _blue),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: _tStrong)),
          ],
        ),
      ),
    );
  }
}

// 거래 타일(토스풍)
class _TossTxTile extends StatelessWidget {
  final AccountTransaction tx;
  final NumberFormat won;
  final int? balanceAfter;

  const _TossTxTile(
      {required this.tx, required this.won, this.balanceAfter, super.key});

  @override
  Widget build(BuildContext context) {
    final isCredit = (tx.direction ?? '').toUpperCase() == 'CREDIT';
    final sign = isCredit ? '+' : '-';
    final color = isCredit ? const Color(0xFF155EEF) : const Color(0xFFB42318);

    final dt = tx.transactionAt?.toLocal();
    String when = '';
    if (dt != null) {
      String pad2(int n) => n.toString().padLeft(2, '0');
      const days = ['월', '화', '수', '목', '금', '토', '일'];
      final w = days[(dt.weekday - 1) % 7];
      when =
          '${dt.year}.${pad2(dt.month)}.${pad2(dt.day)} ($w) ${pad2(dt.hour)}:${pad2(dt.minute)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          // 좌: 제목/서브
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.transactionType ?? '거래', style: _b1),
                const SizedBox(height: 4),
                Text(
                  (tx.counterpartyAccount ?? '').isNotEmpty
                      ? '$when · ${tx.counterpartyAccount}'
                      : when,
                  style: _c1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 우: 금액 + (있으면) 잔액
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sign${won.format(tx.amount ?? 0)}',
                  style: _b1.copyWith(color: color)),
              if (balanceAfter != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('잔액 ${won.format(balanceAfter)}', style: _c1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class GroupDemandPage extends StatefulWidget {
  final int accountId;
  const GroupDemandPage({super.key, required this.accountId});

  @override
  State<GroupDemandPage> createState() => _GroupDemandPageState();
}

class _GroupDemandPageState extends State<GroupDemandPage> {
  late Future<ProductAccountDetail> _detailFuture;

  final _tx = <AccountTransaction>[];
  bool _loadingTx = false;
  bool _txHasMore = true;
  int _nextPage = 0;

  final _scroll = ScrollController();

  final _fromCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  // ====== 필터 상태 ======
  String _filterDirection = 'ALL'; // ALL | CREDIT | DEBIT
  int _filterDays = 0; // 0(전체) | 7 | 30 | -1(이번 달)
  bool _sortDesc = true; // 최신순(true) / 과거순(false)

  @override
  void initState() {
    super.initState();
    _detailFuture = fetchAccountDetail(widget.accountId);
    _loadMoreTx(); // 첫 페이지
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _fromCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _openDirectionSheet() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DirectionSheet(selected: _filterDirection),
    );
    if (v != null && mounted) {
      setState(() => _filterDirection = v);
    }
  }

  // 런닝 잔액 계산 (목록: 최신→과거 기준)
  List<int> _computeBalanceAfterList(
      List<AccountTransaction> list, int startingBalance) {
    var bal = startingBalance; // 최신 거래의 거래후잔액 = 현재 잔액
    final afters = <int>[];
    for (final t in list) {
      afters.add(bal); // 이 거래의 "거래 후 잔액"
      final amt = t.amount ?? 0;
      final isCredit = (t.direction ?? '').toUpperCase() == 'CREDIT';
      bal = bal - (isCredit ? amt : -amt); // 과거로 이동(효과 되돌리기)
    }
    return afters;
  }

  // 페이징
  void _onScroll() {
    if (!_scroll.hasClients || _loadingTx || !_txHasMore) return;
    const threshold = 300.0;
    if (_scroll.position.maxScrollExtent - _scroll.position.pixels <
        threshold) {
      _loadMoreTx();
    }
  }

  Future<void> _loadMoreTx() async {
    if (_loadingTx || !_txHasMore) return;
    setState(() => _loadingTx = true);
    try {
      final page = await fetchAccountTransactions(widget.accountId,
          page: _nextPage, size: 30);
      setState(() {
        _tx.addAll(page.items);
        _txHasMore = page.hasMore;
        _nextPage = page.nextPage;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('거래내역 실패: $e')));
    } finally {
      if (mounted) setState(() => _loadingTx = false);
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      _detailFuture = fetchAccountDetail(widget.accountId);
      _tx.clear();
      _txHasMore = true;
      _nextPage = 0;
    });
    await _loadMoreTx();
  }

  // 공용 헬퍼
  void _copyAccountNumber(String n) async {
    await Clipboard.setData(ClipboardData(text: n));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('계좌번호가 복사되었습니다.')));
  }

  // 필터 & 정렬
  List<AccountTransaction> get _filteredTx {
    final now = DateTime.now();
    DateTime? cutoff;
    bool onlyThisMonth = false;

    // _filterDays: 0=전체, 양수=며칠, -1=이번 달
    if (_filterDays > 0) {
      cutoff = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: _filterDays));
    } else if (_filterDays == -1) {
      onlyThisMonth = true;
    }

    final list = _tx.where((t) {
      // 방향
      if (_filterDirection != 'ALL') {
        final dir = (t.direction ?? '').toUpperCase();
        if (dir != _filterDirection) return false;
      }
      // 기간
      final dt = t.transactionAt;
      if (dt == null) return true;
      if (cutoff != null && dt.isBefore(cutoff)) return false;
      if (onlyThisMonth) {
        if (!(dt.year == now.year && dt.month == now.month)) return false;
      }
      return true;
    }).toList();

    // 정렬
    list.sort((a, b) {
      final da = a.transactionAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.transactionAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return _sortDesc ? db.compareTo(da) : da.compareTo(db);
    });

    return list;
  }

  ({int inSum, int outSum, int net}) _calcMonthSnapshot() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    int inSum = 0, outSum = 0;

    for (final t in _tx) {
      final dt = t.transactionAt;
      if (dt == null) continue;
      if (dt.isBefore(start) || !dt.isBefore(end)) continue;
      final amt = t.amount ?? 0;
      final isCredit = (t.direction ?? '').toUpperCase() == 'CREDIT';
      if (isCredit)
        inSum += amt;
      else
        outSum += amt;
    }
    return (inSum: inSum, outSum: outSum, net: inSum - outSum);
  }

  String _ym(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}';

  // 월별 헤더 + 거래 리스트 (정렬 상태에 맞게, but 런닝잔액은 최신→과거 기준으로 산출 후 매핑)
  List<Widget> _buildTxList(int startingBalance) {
    final list = _filteredTx;

    // 항상 "최신→과거" 리스트를 만들어 런닝잔액 계산
    final listDesc = List<AccountTransaction>.from(list)
      ..sort((a, b) {
        final da = a.transactionAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.transactionAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    final aftersDesc = _computeBalanceAfterList(listDesc, startingBalance);

    String prevYm = '';
    final children = <Widget>[];
    for (final t in list) {
      final dt = t.transactionAt?.toLocal();
      final ym = dt != null ? _ym(dt) : '';
      if (ym.isNotEmpty && ym != prevYm) {
        prevYm = ym;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(ym, style: _b1.copyWith(color: _tWeak)),
        ));
      }
      final idxInDesc = listDesc.indexOf(t);
      final afterVal = (idxInDesc >= 0) ? aftersDesc[idxInDesc] : null;

      children.addAll([
        _TossTxTile(tx: t, won: _won, balanceAfter: afterVal),
        const Divider(height: 1, color: _line),
      ]);
    }

    if (children.isEmpty) return [const _EmptyTransactions()];
    return [
      _TossCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(children: children),
      ),
    ];
  }

  // --- 미니 보기 바 (토스뱅크 톤, 아주 얇게) ---
  Widget _buildMiniViewBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _DirectionSelect(
          label: _dirLabel(_filterDirection),
          onTap: _openDirectionSheet,
        ),
      ),
    );
  }

  // Top 상대계좌 (필터 결과 기준)
  List<MapEntry<String, int>> _topCounterparties() {
    final map = <String, int>{};
    for (final t in _filteredTx) {
      final cp = (t.counterpartyAccount ?? '').trim();
      if (cp.isEmpty) continue;
      map.update(cp, (v) => v + (t.amount ?? 0),
          ifAbsent: () => (t.amount ?? 0));
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).toList();
  }

  // CSV 내보내기 (필터/정렬 결과 기준, running balance 제외)
  Future<void> _exportCsv() async {
    try {
      final rows = <List<String>>[
        ['datetime', 'direction', 'type', 'amount', 'counterparty']
      ];
      for (final t in _filteredTx) {
        rows.add([
          t.transactionAt?.toLocal().toIso8601String() ?? '',
          (t.direction ?? '').toUpperCase(),
          t.transactionType ?? '',
          (t.amount ?? 0).toString(),
          t.counterpartyAccount ?? '',
        ]);
      }
      final csv = rows
          .map((r) => r.map((c) {
                final needsQuote =
                    c.contains(',') || c.contains('"') || c.contains('\n');
                final escaped = c.replaceAll('"', '""');
                return needsQuote ? '"$escaped"' : escaped;
              }).join(','))
          .join('\n');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/group_account_tx.csv');
      await file.writeAsString(csv, encoding: utf8);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV로 내보냈습니다: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
    }
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: _bg,
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: FutureBuilder<ProductAccountDetail>(
            future: _detailFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError || !snap.hasData) {
                return ListView(children: const [
                  SizedBox(height: 120),
                  Center(child: Text('상세 데이터를 불러오지 못했습니다.')),
                ]);
              }

              final d = snap.data!;
              final acc = d.account;
              final app = d.application;
              final balance = (acc?.balance ?? 0);

              return ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  // 상단 요약 (헤더)
                  _TossCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                acc?.accountName ?? '모임통장',
                                style: _h2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if ((acc?.accountNumber ?? '').isNotEmpty)
                              TextButton.icon(
                                onPressed: () =>
                                    _copyAccountNumber(acc!.accountNumber),
                                style: TextButton.styleFrom(
                                  foregroundColor: _tWeak,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('복사'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${acc?.bankName ?? ''}  ${acc?.accountNumber}',
                            style: _c1),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('잔액', style: TextStyle(color: _tWeak)),
                            Text(_won.format(balance), style: _h1),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 이번 달 스냅샷
                  const SizedBox(height: 12),
                  _TossCard(
                    child: Builder(builder: (context) {
                      final s = _calcMonthSnapshot();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('이번 달 스냅샷', style: _h2),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                  child: _MiniStat(
                                      label: '입금',
                                      value: _won.format(s.inSum),
                                      color: const Color(0xFF155EEF))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _MiniStat(
                                      label: '출금',
                                      value: _won.format(s.outSum),
                                      color: const Color(0xFFB42318))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _MiniStat(
                                      label: '순증감',
                                      value: _won.format(s.net),
                                      color: _tStrong)),
                            ],
                          ),
                        ],
                      );
                    }),
                  ),

                  // 빠른 액션
                  // const SizedBox(height: 12),
                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: _TossActionButton(
                  //         icon: Icons.move_down_rounded,
                  //         label: '입금하기',
                  //         onTap: () {
                  //           // TODO: 입금 플로우 연결
                  //         },
                  //       ),
                  //     ),
                  //   ],
                  // ),

                  // (선택) 금리 카드
                  if ((app.baseRateAtEnroll ?? 0) > 0 ||
                      (app.effectiveRateAnnual ?? 0) > 0) ...[
                    const SizedBox(height: 12),
                    _TossCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('금리', style: _h2),
                          const SizedBox(height: 8),
                          _kvRow('기본금리',
                              '${(app.baseRateAtEnroll ?? 0).toStringAsFixed(2)}%'),
                          const SizedBox(height: 8),
                          _kvRow('현재 적용금리',
                              '${(app.effectiveRateAnnual ?? app.baseRateAtEnroll ?? 0).toStringAsFixed(2)}%'),
                        ],
                      ),
                    ),
                  ],
                  // Top 상대계좌
                  Builder(builder: (context) {
                    final top = _topCounterparties();
                    if (top.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        _TossCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Top 상대계좌', style: _h2),
                              const SizedBox(height: 8),
                              ...top.map((e) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                            child: Text(e.key, style: _b1)),
                                        Text(_won.format(e.value),
                                            style:
                                                _b1.copyWith(color: _tStrong)),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),

                  // 거래내역 헤더 + CSV 내보내기
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Text('거래내역', style: _h2)),
                      // ▶▶ 미니 보기 바 (아주 얇은 UI)
                      _buildMiniViewBar(),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 거래 리스트 (월별 구분 + 런닝잔액)
                  ..._buildTxList(balance),

                  if (_loadingTx)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (!_txHasMore && _tx.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: Text('끝까지 보셨습니다.',
                              style: TextStyle(color: _tWeak))),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // 금리 섹션용 key-value 라인
  Widget _kvRow(String k, String v) {
    return Row(
      children: [
        Expanded(child: Text(k, style: _c1)),
        const SizedBox(width: 8),
        Text(v, style: _b1, textAlign: TextAlign.right),
      ],
    );
  }
}

// ===== 보조 위젯 =====

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: _c1),
        const SizedBox(height: 6),
        Text(value, style: _b1.copyWith(color: color)),
      ]),
    );
  }
}

// 아주 작은 필터 칩(토스뱅크 얇은 톤)
class _MiniPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MiniPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFEFF4FF) : const Color(0xFFF3F4F6);
    final border = selected ? const Color(0xFFDCE6FF) : _line;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(label,
            style: _b1.copyWith(fontWeight: FontWeight.w600, color: _tStrong)),
      ),
    );
  }
}

// 빈 거래내역
class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({super.key});
  @override
  Widget build(BuildContext context) => _TossCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: const [
            Icon(Icons.receipt_long_outlined, size: 36, color: _tWeak),
            SizedBox(height: 8),
            Text('거래내역이 없습니다.', style: TextStyle(color: _tWeak)),
          ]),
        ),
      );
}

String _dirLabel(String v) {
  switch (v) {
    case 'CREDIT':
      return '입금';
    case 'DEBIT':
      return '출금';
    default:
      return '전체';
  }
}

// 상단 얇은 셀렉터 (텍스트 + V 아이콘)
class _DirectionSelect extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DirectionSelect({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          // ← const 빼기
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: _b1.copyWith(color: _tWeak)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 18, color: _tWeak),
          ],
        ),
      ),
    );
  }
}

// 토스풍 바텀시트: 내역 선택
class _DirectionSheet extends StatelessWidget {
  final String selected; // 'ALL' | 'CREDIT' | 'DEBIT'
  const _DirectionSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    Widget item(String value, String label) {
      final sel = value == selected;
      return ListTile(
        dense: true,
        title: Text(label, style: _b1.copyWith(color: _tStrong)),
        trailing: Icon(Icons.check, color: sel ? _blue : _line),
        onTap: () => Navigator.pop(context, value),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 핸들
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('내역 선택', style: _h2),
            const SizedBox(height: 8),

            item('ALL', '전체'),
            item('CREDIT', '입금'),
            item('DEBIT', '출금'),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
