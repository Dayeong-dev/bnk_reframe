// lib/pages/home_page.dart
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'package:reframe/constants/number_format.dart';
import 'package:reframe/model/account.dart';
import 'package:reframe/pages/account/account_detail_page.dart';
import 'package:reframe/pages/auth/login_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/service/account_service.dart';

import '../constants/text_animation.dart';

/// ===================================================================
///  홈 페이지
///  - 상단: 총자산
///  - 코호트 비교(현금성/예적금 비중) : BenchmarkDashboard 사용
///  - 추천 서비스 Top5 슬라이드(파스텔 카드, 히트테스트 오류 방지)
///  - 내 계좌(잔액 내림차순 3개 → 더보기/간략히 보기)
///  - 마이메뉴(최대 3개, 편집 모달은 루트 네비게이터로 띄움)
/// ===================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _secureStorage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  // 데이터
  late final Future<List<Account>> _accountsFuture = fetchAccounts(null);

  // 내 계좌: 더보기 토글
  int _visibleCount = 3;

  // 추천 슬라이드
  final PageController _recController =
      PageController(viewportFraction: 0.86, keepPage: true);
  int _recPage = 0;

  // 마이메뉴
  static const _kMenuStorageKey = 'home_my_menu';
  final List<_MyMenuItem> _pool = const [
    _MyMenuItem(key: 'ai', title: 'AI 챗봇', icon: Icons.smart_toy_rounded),
    _MyMenuItem(key: 'trend', title: '자산추이', icon: Icons.show_chart_rounded),
    _MyMenuItem(key: 'event', title: '이벤트', icon: Icons.card_giftcard_rounded),
    _MyMenuItem(
        key: 'test', title: '저축성향테스트', icon: Icons.psychology_alt_rounded),
    _MyMenuItem(
        key: 'coupon', title: '쿠폰함', icon: Icons.local_activity_rounded),
  ];
  List<String> _myMenu = ['ai', 'trend', 'event'];

  // 코호트 선택(팝업에서 조합 문자열 사용: "20대 남성" 등)
  final List<String> _cohorts = const [
    '20대 남성',
    '20대 여성',
    '30대 남성',
    '30대 여성',
    '40대 남성',
    '40대 여성',
  ];
  String _selectedCohort = '20대 여성';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkBiometricSupport();
      await _loadMyMenu();
    });
  }

  @override
  void dispose() {
    _recController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricSupport() async {
    final canCheck = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    final available = await _auth.getAvailableBiometrics();
    final enabled = await _secureStorage.read(key: 'biometricEnabled');
    if (canCheck && supported && available.isNotEmpty && enabled == null) {
      // 필요 시 생체등록 안내 가능
    }
  }

  Future<void> _loadMyMenu() async {
    final saved = await _secureStorage.read(key: _kMenuStorageKey);
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _myMenu = saved.split(',').where((e) => e.isNotEmpty).take(3).toList();
      });
    }
  }

  Future<void> _saveMyMenu() async {
    await _secureStorage.write(key: _kMenuStorageKey, value: _myMenu.join(','));
  }

  Future<T?> _push<T>(Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠어요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('아니요')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('네')),
        ],
      ),
    );
    if (ok != true) return;
    await _secureStorage.deleteAll();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BNK Reframe",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
              tooltip: '로그아웃',
              icon: const Icon(Icons.logout, size: 20),
              onPressed: _logout),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Account>>(
          future: _accountsFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorView(
                  error: '${snap.error}', onRetry: () => setState(() {}));
            }

            final accounts = snap.data ?? [];
            final demand = accounts
                .where((a) => a.accountType == AccountType.demand)
                .toList();
            final product = accounts
                .where((a) => a.accountType == AccountType.product)
                .toList();

            // 총자산
            final cashTotal =
                demand.fold<int>(0, (s, a) => s + (a.balance ?? 0));
            final savingTotal =
                product.fold<int>(0, (s, a) => s + (a.balance ?? 0));
            final total = cashTotal + savingTotal;

            // "내 계좌"는 모든 계좌(입출금+상품) 통합으로 정렬
            final allAccounts = [...demand, ...product]
              ..sort((a, b) => (b.balance ?? 0).compareTo(a.balance ?? 0));

            // 더보기 보정
            if (_visibleCount > allAccounts.length) {
              _visibleCount = math.min(3, allAccounts.length);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                // 1) 상단 총자산
                _TotalHeaderCard(
                  total: total,
                  cash: cashTotal,
                  saving: savingTotal,
                  onDeposit: () => _push(DepositMainPage()),
                ),

                const SizedBox(height: 12),

                // 2) 코호트 비교 (현금성/예적금 비중)
                BenchmarkDashboard(
                  title: '내 비중 vs 벤치마크',
                  mineCashRatio: total == 0 ? 0 : cashTotal / total,
                  mineDepositRatio: total == 0 ? 0 : savingTotal / total,
                  initialSegment: _selectedCohort,
                  localBenchmarks: const {
                    '20대 남성': BenchmarkRatio(cash: 0.40, deposit: 0.60),
                    '20대 여성': BenchmarkRatio(cash: 0.42, deposit: 0.58),
                    '30대 남성': BenchmarkRatio(cash: 0.38, deposit: 0.62),
                    '30대 여성': BenchmarkRatio(cash: 0.41, deposit: 0.59),
                    '40대 남성': BenchmarkRatio(cash: 0.36, deposit: 0.64),
                    '40대 여성': BenchmarkRatio(cash: 0.39, deposit: 0.61),
                  },
                  onFetchBenchmark: (segment) async {
                    // 서버 연동시 이 부분만 교체하세요.
                    await Future.delayed(const Duration(milliseconds: 180));
                    // 간단 목업(세그먼트별 미세조정)
                    final base = {
                      '20대 남성': const BenchmarkRatio(cash: 0.40, deposit: 0.60),
                      '20대 여성': const BenchmarkRatio(cash: 0.42, deposit: 0.58),
                      '30대 남성': const BenchmarkRatio(cash: 0.38, deposit: 0.62),
                      '30대 여성': const BenchmarkRatio(cash: 0.41, deposit: 0.59),
                      '40대 남성': const BenchmarkRatio(cash: 0.36, deposit: 0.64),
                      '40대 여성': const BenchmarkRatio(cash: 0.39, deposit: 0.61),
                    }[segment]!;
                    return base;
                  },
                ),

                const SizedBox(height: 16),

                // 3) 추천 서비스(Top5 슬라이드)
                _RecommendCarousel(
                  controller: _recController,
                  page: _recPage,
                  onPageChanged: (i) => setState(() => _recPage = i),
                ),

                const SizedBox(height: 16),

                // 4) 내 계좌 (잔액 상위 3개 → 더보기/간략히 보기)
                Row(
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text('내 계좌',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (allAccounts.isEmpty)
                  _EmptyAccounts(onExplore: () => _push(DepositMainPage()))
                else ...[
                  ...allAccounts.take(_visibleCount).map((a) => _AccountCard(
                        title: a.accountName ?? 'BNK 부산은행 계좌',
                        subtitle: a.accountNumber ?? '-',
                        balanceText: '${money.format(a.balance ?? 0)} 원',
                        leading: _productBadgeIcon(a),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AccountDetailPage(accountId: a.id),
                              ));
                        },
                      )),
                  if (allAccounts.length > 3)
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _visibleCount = (_visibleCount < allAccounts.length)
                                ? allAccounts.length
                                : math.min(3, allAccounts.length);
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                        ),
                        icon: Icon(
                          (_visibleCount < allAccounts.length)
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 22,
                        ),
                        label: Text(
                          (_visibleCount < allAccounts.length)
                              ? '더보기'
                              : '간략히 보기',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],

                const SizedBox(height: 16),

                // 5) 마이메뉴 (편집 가능)
                _MyMenuSection(
                  pool: _pool,
                  selectedKeys: _myMenu,
                  onTapItem: _openMenu,
                  onTapEdit: _openMenuEditor,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 메뉴 라우팅 (데모 페이지)
  void _openMenu(String key) {
    Widget page = _DemoPage(title: key);
    switch (key) {
      case 'ai':
        page = const _DemoPage(title: 'AI 챗봇');
        break;
      case 'trend':
        page = const _DemoPage(title: '자산추이');
        break;
      case 'event':
        page = const _DemoPage(title: '이벤트');
        break;
      case 'test':
        page = const _DemoPage(title: '저축성향테스트');
        break;
      case 'coupon':
        page = const _DemoPage(title: '쿠폰함');
        break;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // 편집 모달: 루트 네비게이터 + 스크림(배경 어둡게)
  Future<void> _openMenuEditor() async {
    final current = [..._myMenu];
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      barrierColor: Colors.black.withOpacity(0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          bool selected(String k) => current.contains(k);
          void toggle(String k) {
            setSheet(() {
              if (current.contains(k)) {
                current.remove(k);
              } else {
                if (current.length >= 3) return;
                current.add(k);
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16 + MediaQuery.of(ctx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('마이메뉴 편집 (최대 3개)',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _pool.map((m) {
                    final isSel = selected(m.key);
                    return ChoiceChip(
                      label: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(m.icon, size: 16),
                        const SizedBox(width: 6),
                        Text(m.title),
                      ]),
                      selected: isSel,
                      onSelected: (_) => toggle(m.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('${current.length}/3 선택됨',
                        style: const TextStyle(color: Colors.black54)),
                    const Spacer(),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('취소')),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: () {
                        setState(() => _myMenu = current.take(3).toList());
                        _saveMyMenu();
                        Navigator.pop(ctx);
                      },
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

/* ─────────────────────────────────────────────────────────
 * 상단 총자산 카드 (카운트업 + 자산구성 바)
 * ───────────────────────────────────────────────────────── */
class _TotalHeaderCard extends StatelessWidget {
  final int total;
  final int cash;
  final int saving;
  final VoidCallback onDeposit;

  const _TotalHeaderCard({
    required this.total,
    required this.cash,
    required this.saving,
    required this.onDeposit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('총 자산',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              MoneyCountUp(
                value: total,
                formatter: money,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                animateOnFirstBuild: true,
                initialFrom: 0,
              ),
              const SizedBox(width: 6),
              Text('원',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 140,
            height: 42,
            child: OutlinedButton(
              onPressed: onDeposit,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: Colors.grey.shade400),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 20),
                  SizedBox(width: 4),
                  Text('예적금 만들기',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.monetization_on_rounded,
                  size: 16, color: Colors.black38),
              const SizedBox(width: 4),
              Text('자산 구성',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      )),
              const Spacer(),
              Text('총 ${money.format(total)} 원',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                      )),
            ],
          ),
          const SizedBox(height: 8),
          _AssetBreakdownBar(cash: cash, saving: saving),
          const SizedBox(height: 8),
          _AssetLegend(cash: cash, saving: saving),
        ],
      ),
    );
  }
}

/* ─────────────────────────────────────────────────────────
 * 추천 슬라이드 (히트테스트 오류 방지: 크기 명시)
 * ───────────────────────────────────────────────────────── */
class _RecommendItem {
  final String title;
  final String caption;
  final int subscribers;
  final String emoji;
  final List<Color> gradient;
  const _RecommendItem({
    required this.title,
    required this.caption,
    required this.subscribers,
    required this.emoji,
    required this.gradient,
  });
}

final _kPastelCards = <_RecommendItem>[
  _RecommendItem(
    title: '정기예금 플러스',
    caption: '높은 금리로 안정적으로',
    subscribers: 92000,
    emoji: '💎',
    gradient: [const Color(0xFFBFD7FF), const Color(0xFF7FA8FF)],
  ),
  _RecommendItem(
    title: '자유적금 챌린지',
    caption: '자유롭게, 꾸준하게',
    subscribers: 81000,
    emoji: '🌱',
    gradient: [const Color(0xFFC9F2FF), const Color(0xFF8DD9FF)],
  ),
  _RecommendItem(
    title: 'AI 목표저축',
    caption: '목표 기반 자동이체',
    subscribers: 73000,
    emoji: '🤖',
    gradient: [const Color(0xFFD9CCFF), const Color(0xFFA48CFF)],
  ),
  _RecommendItem(
    title: '월급통장 리워드',
    caption: '월급 실적 캐시백',
    subscribers: 69000,
    emoji: '💼',
    gradient: [const Color(0xFFFFE1C9), const Color(0xFFFFB08A)],
  ),
  _RecommendItem(
    title: '학생왕 적금',
    caption: '청년 전용 우대',
    subscribers: 64000,
    emoji: '🎓',
    gradient: [const Color(0xFFFFD6E8), const Color(0xFFFFA4CA)],
  ),
];

class _RecommendCarousel extends StatelessWidget {
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final int page;
  const _RecommendCarousel({
    super.key,
    required this.controller,
    required this.onPageChanged,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: const [
          Padding(
            padding: EdgeInsets.only(left: 6),
            child: Text('실시간 추천 서비스',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 180, // 카드 높이 보장
          child: PageView.builder(
            controller: controller,
            itemCount: _kPastelCards.length,
            onPageChanged: onPageChanged,
            physics: const PageScrollPhysics(),
            itemBuilder: (ctx, i) {
              final it = _kPastelCards[i];
              final double cardWidth = MediaQuery.of(ctx).size.width * 0.86;
              return Center(
                child: SizedBox(
                  width: cardWidth,
                  height: 156,
                  child: _RecommendCard(index: i, item: it),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_kPastelCards.length, (i) {
            final active = i == page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? const Color(0xFF2962FF) : Colors.black26,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _RecommendCard extends StatelessWidget {
  final int index;
  final _RecommendItem item;
  const _RecommendCard({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    final rank = index + 1;
    return SizedBox.expand(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: item.gradient),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 12,
                  offset: Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.3),
                    shape: BoxShape.circle),
                child: Center(
                    child:
                        Text(item.emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.6),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text('$rank위',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.caption,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('가입자수 ${_fmtSubs(item.subscribers)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${item.title} 상세로 이동 (데모)')),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(.75),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('신청하기',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtSubs(int n) {
    if (n >= 10000) {
      final v = (n / 10000).toStringAsFixed(1);
      return '${v}만명';
    }
    return '$n명';
  }
}

/* ─────────────────────────────────────────────────────────
 * 마이메뉴
 * ───────────────────────────────────────────────────────── */
class _MyMenuItem {
  final String key;
  final String title;
  final IconData icon;
  const _MyMenuItem(
      {required this.key, required this.title, required this.icon});
}

class _MyMenuSection extends StatelessWidget {
  final List<_MyMenuItem> pool;
  final List<String> selectedKeys;
  final ValueChanged<String> onTapItem;
  final VoidCallback onTapEdit;

  const _MyMenuSection({
    super.key,
    required this.pool,
    required this.selectedKeys,
    required this.onTapItem,
    required this.onTapEdit,
  });

  @override
  Widget build(BuildContext context) {
    final items =
        pool.where((m) => selectedKeys.contains(m.key)).take(3).toList();
    return Card(
      elevation: 0.4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                const Text('마이메뉴',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton.icon(
                    onPressed: onTapEdit,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('편집')),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 78,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (ctx, i) {
                final m = items[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onTapItem(m.key),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE6EAF0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(m.icon, size: 26, color: const Color(0xFF2962FF)),
                        const SizedBox(height: 6),
                        Text(m.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────────────────────────────────────────
 * 공통 카드/계좌/요약
 * ───────────────────────────────────────────────────────── */
class _AccountCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String balanceText;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading;

  const _AccountCard({
    required this.title,
    required this.subtitle,
    required this.balanceText,
    this.onTap,
    this.trailing,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(.7),
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(balanceText,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w700,
                    )),
                if (trailing != null) ...[const SizedBox(height: 4), trailing!],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  final VoidCallback onExplore;
  const _EmptyAccounts({required this.onExplore});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFF1F5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 40, color: Color(0xFF8B95A1)),
          const SizedBox(height: 10),
          const Text('계좌가 없습니다.'),
          const SizedBox(height: 4),
          Text('지금 통장을 만들어 시작해 보세요.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFF6B7280))),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onExplore, child: const Text('통장 만들기')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text('계좌 정보를 불러오지 못했습니다.'),
            const SizedBox(height: 8),
            Text(error,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────────────────────────────────────────
 * 아이콘/컬러 + 자산 구성 바/범례
 * ───────────────────────────────────────────────────────── */
class _IconMeta {
  final IconData icon;
  final Color color;
  const _IconMeta(this.icon, this.color);
}

const _kPrimary = Color(0xFF2962FF);
const _kCashSolid = _kPrimary; // 현금성
const _kSavingSolid = Color(0xFF80A4FF); // 예·적금
const _kTrack = Color(0xFFE9EEF6);

const _kGreen = Color(0xFF10B981);
const _kGray = Color(0xFF6B7280);

_IconMeta _iconMetaForProduct(Account a) {
  String pt = '';
  try {
    pt = (a.productType ?? '').toString();
  } catch (_) {}
  final hint = '${pt} ${a.accountName ?? ''}'.toLowerCase();
  if (hint.contains('walk') ||
      hint.contains('step') ||
      hint.contains('health') ||
      hint.contains('걷') ||
      hint.contains('헬스')) {
    return _IconMeta(Icons.directions_walk_rounded, _kGreen);
  }
  if (hint.contains('savings') ||
      hint.contains('installment') ||
      hint.contains('적금')) {
    return _IconMeta(Icons.savings_outlined, _kSavingSolid);
  }
  if (hint.contains('deposit') || hint.contains('예금') || hint.contains('정기')) {
    return _IconMeta(Icons.account_balance_rounded, _kCashSolid);
  }
  if (a.accountType == AccountType.demand ||
      hint.contains('입출금') ||
      hint.contains('checking')) {
    return _IconMeta(Icons.account_balance_wallet_outlined, _kCashSolid);
  }
  return _IconMeta(Icons.account_balance_outlined, _kGray);
}

Widget _productBadgeIcon(Account a) {
  final m = _iconMetaForProduct(a);
  return Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
        color: m.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12)),
    alignment: Alignment.center,
    child: Icon(m.icon, color: m.color, size: 22),
  );
}

class _AssetBreakdownBar extends StatelessWidget {
  final int cash;
  final int saving;
  final double height;
  final Duration duration;
  final Curve curve;
  final double split;

  const _AssetBreakdownBar({
    super.key,
    required this.cash,
    required this.saving,
    this.height = 8,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    this.split = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    final total = (cash + saving).toDouble();
    final cashRatio = total == 0 ? 0.0 : cash / total;
    final savingRatio = total == 0 ? 0.0 : saving / total;
    final safeSplit = split.clamp(0.1, 0.9);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        return TweenAnimationBuilder<double>(
          key: ValueKey('$cash-$saving'),
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          curve: curve,
          builder: (context, t, _) {
            if (total == 0) return Container(height: height, color: _kTrack);

            final cashPhaseEnd = safeSplit;
            final cashProgress = (t <= cashPhaseEnd) ? (t / cashPhaseEnd) : 1.0;
            final savingPhaseStart = safeSplit;
            final savingProgress = (t <= savingPhaseStart)
                ? 0.0
                : ((t - savingPhaseStart) / (1 - savingPhaseStart));

            final wCash = w * cashRatio * cashProgress;
            final wSaving = w * savingRatio * savingProgress;

            return Stack(children: [
              Container(height: height, color: _kTrack),
              Container(height: height, width: wCash, color: _kCashSolid),
              Positioned(
                  left: wCash,
                  child: Container(
                      height: height, width: wSaving, color: _kSavingSolid)),
            ]);
          },
        );
      }),
    );
  }
}

class _AssetLegend extends StatelessWidget {
  final int cash;
  final int saving;
  const _AssetLegend({super.key, required this.cash, required this.saving});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: _kCashSolid),
        const SizedBox(width: 6),
        Text('현금성  ${money.format(cash)} 원',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(width: 16),
        _LegendDot(color: _kSavingSolid),
        const SizedBox(width: 6),
        Text('예·적금  ${money.format(saving)} 원',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({super.key, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

/* ─────────────────────────────────────────────────────────
 * 코호트 비교 재사용 위젯 (네가 준 코드 그대로 포함)
 * ───────────────────────────────────────────────────────── */
class BenchmarkRatio {
  final double cash; // 0.0 ~ 1.0
  final double deposit; // 0.0 ~ 1.0
  const BenchmarkRatio({required this.cash, required this.deposit});
}

class BenchmarkDashboard extends StatefulWidget {
  const BenchmarkDashboard({
    super.key,
    required this.mineCashRatio,
    required this.mineDepositRatio,
    this.initialSegment,
    this.localBenchmarks = const {
      '20대 남성': BenchmarkRatio(cash: 0.36, deposit: 0.64),
      '20대 여성': BenchmarkRatio(cash: 0.42, deposit: 0.58),
    },
    this.onFetchBenchmark,
    this.title = '내 비중 vs 벤치마크',
    this.colorCash = const Color(0xFF40C4FF),
    this.colorDeposit = const Color(0xFF7C88FF),
  });

  final double mineCashRatio;
  final double mineDepositRatio;
  final String? initialSegment;
  final Map<String, BenchmarkRatio> localBenchmarks;
  final Future<BenchmarkRatio> Function(String segment)? onFetchBenchmark;
  final String title;
  final Color colorCash;
  final Color colorDeposit;

  @override
  State<BenchmarkDashboard> createState() => _BenchmarkDashboardState();
}

class _BenchmarkDashboardState extends State<BenchmarkDashboard> {
  late String _selectedSegment;
  BenchmarkRatio? _bm;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _selectedSegment = widget.initialSegment ??
        (widget.localBenchmarks.isNotEmpty
            ? widget.localBenchmarks.keys.first
            : '기본');
    _loadFor(_selectedSegment);
  }

  Future<void> _loadFor(String segment) async {
    setState(() {
      _loading = widget.onFetchBenchmark != null;
      _error = null;
      _bm = null;
    });

    if (widget.onFetchBenchmark != null) {
      try {
        final r = await widget.onFetchBenchmark!(segment);
        if (!mounted) return;
        setState(() {
          _bm = r;
          _loading = false;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }

    final local = widget.localBenchmarks[segment];
    setState(() {
      _bm = local ??
          (widget.localBenchmarks.isNotEmpty
              ? widget.localBenchmarks.values.first
              : const BenchmarkRatio(cash: 0, deposit: 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final bm = _bm ??
        (widget.localBenchmarks[_selectedSegment] ??
            (widget.localBenchmarks.isNotEmpty
                ? widget.localBenchmarks.values.first
                : const BenchmarkRatio(cash: 0, deposit: 1)));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (widget.localBenchmarks.isNotEmpty)
                PopupMenuButton<String>(
                  initialValue: _selectedSegment,
                  onSelected: (v) {
                    setState(() => _selectedSegment = v);
                    _loadFor(v);
                  },
                  itemBuilder: (c) => widget.localBenchmarks.keys
                      .map((k) => PopupMenuItem(value: k, child: Text(k)))
                      .toList(),
                  child: Row(children: [
                    Text(_selectedSegment,
                        style: const TextStyle(fontSize: 12)),
                    const Icon(Icons.keyboard_arrow_down, size: 18),
                  ]),
                ),
            ]),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '서버에서 벤치마크를 불러오지 못해 로컬값을 표시합니다.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.red),
                ),
              ),
            _CompareRow(
                label: '현금성',
                mine: widget.mineCashRatio,
                bm: bm.cash,
                color: widget.colorCash),
            const SizedBox(height: 10),
            _CompareRow(
                label: '예·적금',
                mine: widget.mineDepositRatio,
                bm: bm.deposit,
                color: widget.colorDeposit),
          ],
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final double mine;
  final double bm;
  final Color color;
  const _CompareRow({
    required this.label,
    required this.mine,
    required this.bm,
    required this.color,
  });

  String _pct(double v) => '${(v.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const SizedBox(
          width: 64, child: Text('현금성', style: TextStyle(fontSize: 12))),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CompareBar(mine: mine, benchmark: bm, color: color),
            const SizedBox(height: 4),
            Text('내 비중 ${_pct(mine)} / 벤치마크 ${_pct(bm)}',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    ]).copyWithLabel(label);
  }
}

extension on Row {
  /// 위의 _CompareRow에서 라벨만 바꾸기 위한 간단 헬퍼
  Row copyWithLabel(String label) {
    final children = this.children.toList();
    children[0] = SizedBox(
        width: 64, child: Text(label, style: const TextStyle(fontSize: 12)));
    return Row(children: children);
  }
}

class _CompareBar extends StatelessWidget {
  final double mine;
  final double benchmark;
  final Color color;
  const _CompareBar(
      {required this.mine, required this.benchmark, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(
              color: const Color(0xFFE9ECF1),
              borderRadius: BorderRadius.circular(999)),
        ),
        FractionallySizedBox(
          widthFactor: benchmark.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
                color: color.withOpacity(.35),
                borderRadius: BorderRadius.circular(999)),
          ),
        ),
        FractionallySizedBox(
          widthFactor: mine.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(999)),
          ),
        ),
      ]),
    );
  }
}

/* ─────────────────────────────────────────────────────────
 * 데모 페이지
 * ───────────────────────────────────────────────────────── */
class _DemoPage extends StatelessWidget {
  final String title;
  const _DemoPage({required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
          child: Text('$title 페이지 (데모)', style: const TextStyle(fontSize: 18))),
    );
  }
}
