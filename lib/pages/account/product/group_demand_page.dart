import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:reframe/model/account_transaction.dart';
import '../../../model/product_account_detail.dart';
import '../../../service/account_service.dart';

// 금액 포맷
final _won = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);

// ===== Toss tone colors & text =====
const _tStrong = Color(0xFF0B0D12);
const _tWeak   = Color(0xFF6B7280);
const _line    = Color(0xFFE5E7EB);
const _blue    = Color(0xFF0064FF);
const _bg      = Color(0xFFF7F8FA);

TextStyle get _h1 => const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _tStrong);
TextStyle get _h2 => const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _tStrong);
TextStyle get _b1 => const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _tStrong);
TextStyle get _c1 => const TextStyle(fontSize: 13, color: _tWeak, height: 1.3);

// 둥근 화이트 카드
class _TossCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _TossCard({required this.child, this.padding = const EdgeInsets.all(16), super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
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
  const _TossPrimaryBtn({required this.label, required this.onTap, this.busy = false, super.key});
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
        child: busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
  const _TossActionButton({required this.icon, required this.label, this.onTap, super.key});
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: _tStrong)),
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
  const _TossTxTile({required this.tx, required this.won, super.key});

  @override
  Widget build(BuildContext context) {
    final isCredit = (tx.direction ?? '').toUpperCase() == 'CREDIT';
    final sign = isCredit ? '+' : '-';
    final color = isCredit ? const Color(0xFF155EEF) : const Color(0xFFB42318);

    // 보기 좋은 날짜 포맷 (intl init 없이)
    final dt = tx.transactionAt?.toLocal();
    String when = '';
    if (dt != null) {
      String pad2(int n) => n.toString().padLeft(2, '0');
      const days = ['월','화','수','목','금','토','일'];
      final w = days[(dt.weekday - 1) % 7];
      when = '${dt.year}.${pad2(dt.month)}.${pad2(dt.day)} ($w) ${pad2(dt.hour)}:${pad2(dt.minute)}';
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
          // 우: 금액/잔액
          // Column(
          //   crossAxisAlignment: CrossAxisAlignment.end,
          //   children: [
          //     Text('$sign${won.format(tx.amount)}', style: _b1.copyWith(color: color)),
          //     if (tx.balanceAfter != null)
          //       Padding(
          //         padding: const EdgeInsets.only(top: 2),
          //         child: Text('잔액 ${won.format(tx.balanceAfter)}', style: _c1),
          //       ),
          //   ],
          // ),
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

  // (미사용 변수였던 듯 하여 정리)
  // bool _loading = false;

  final _fromCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _detailFuture = fetchAccountDetailModel(widget.accountId);
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

  void _onScroll() {
    if (!_scroll.hasClients || _loadingTx || !_txHasMore) return;
    const threshold = 300.0;
    if (_scroll.position.maxScrollExtent - _scroll.position.pixels < threshold) {
      _loadMoreTx();
    }
  }

  Future<void> _loadMoreTx() async {
    if (_loadingTx || !_txHasMore) return;
    setState(() => _loadingTx = true);
    try {
      final page = await fetchAccountTransactions(widget.accountId, page: _nextPage, size: 30);
      setState(() {
        _tx.addAll(page.items);
        _txHasMore = page.hasMore;
        _nextPage = page.nextPage;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('거래내역 실패: $e')));
    } finally {
      if (mounted) setState(() => _loadingTx = false);
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      _detailFuture = fetchAccountDetailModel(widget.accountId); // 통일
      _tx.clear();
      _txHasMore = true;
      _nextPage = 0;
    });
    await _loadMoreTx();
  }

  void _copyAccountNumber(String n) async {
    await Clipboard.setData(ClipboardData(text: n));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('계좌번호가 복사되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                              onPressed: () => _copyAccountNumber(acc!.accountNumber),
                              style: TextButton.styleFrom(
                                foregroundColor: _tWeak,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('복사'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${acc?.bankName ?? ''}  ${_mask(acc?.accountNumber)}', style: _c1),
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

                // 빠른 액션
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TossActionButton(
                        icon: Icons.move_down_rounded,
                        label: '입금하기',
                        onTap: () {
                          // TODO: 입금 플로우 연결
                        },
                      ),
                    ),
                    // const SizedBox(width: 8),
                    // Expanded(child: _TossActionButton(icon: Icons.group_add_rounded, label: '멤버 초대', onTap: () {})),
                  ],
                ),

                // (선택) 금리 카드
                if ((app.baseRateAtEnroll ?? 0) > 0 || (app.effectiveRateAnnual ?? 0) > 0) ...[
                  const SizedBox(height: 12),
                  _TossCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('금리', style: _h2),
                        const SizedBox(height: 8),
                        _kvRow('기본금리', '${(app.baseRateAtEnroll ?? 0).toStringAsFixed(2)}%'),
                        const SizedBox(height: 8),
                        _kvRow('현재 적용금리', '${(app.effectiveRateAnnual ?? app.baseRateAtEnroll ?? 0).toStringAsFixed(2)}%'),
                      ],
                    ),
                  ),
                ],

                // 거래내역
                const SizedBox(height: 16),
                Text('거래내역', style: _h2),
                const SizedBox(height: 8),

                if (_tx.isEmpty && !_loadingTx)
                  const _EmptyTransactions()
                else
                  _TossCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      children: [
                        ..._tx.map((t) => Column(
                          children: [
                            _TossTxTile(tx: t, won: _won),
                            const Divider(height: 1, color: _line),
                          ],
                        )),
                      ],
                    ),
                  ),

                if (_loadingTx)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!_txHasMore && _tx.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text('끝까지 보셨습니다.', style: TextStyle(color: _tWeak))),
                  ),
              ],
            );
          },
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

// 공통 유틸
String _mask(String? n) {
  if (n == null || n.length < 6) return n ?? '-';
  return '${n.substring(0,3)}****${n.substring(n.length-2)}';
}
