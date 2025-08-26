// lib/pages/home_page.dart
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reframe/constants/number_format.dart';
import 'package:reframe/model/account.dart';
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/pages/account/account_detail_page.dart';
import 'package:reframe/pages/auth/login_page.dart';
import 'package:reframe/pages/chat/bnk_chat_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/pages/deposit/deposit_detail_page.dart';
import 'package:reframe/pages/savings_test/screens/start_screen.dart';
import 'package:reframe/service/account_service.dart';
import 'package:reframe/service/deposit_service.dart';
import 'package:reframe/service/subscriber_service.dart';

// 실제 존재 경로
import 'package:reframe/pages/my_service_test_page.dart'; // 자산추이
import 'package:reframe/event/pages/coupons_screen.dart'; // 쿠폰함

/// 문자열 정리:
/// - <br>, </br>, <br/> (대소문자 무시) → 공백
/// - 나머지 HTML 태그 제거
/// - &nbsp; 같은 공백 엔티티 치환
/// - 연속 공백 1칸으로 정규화
String normalizeHtmlPlainText(String? input) {
  if (input == null || input.isEmpty) return '';

  var t = input;

  // 1) <br>, </br>, <br/> → 공백 (대소문자 무시)
  t = t.replaceAll(
    RegExp(r'<\s*\/?\s*br\s*\/?\s*>', caseSensitive: false),
    ' ',
  );

  // 2) HTML 엔티티 일부 공백 계열 치환
  t = t.replaceAll(RegExp(r'&nbsp;|&#160;', caseSensitive: false), ' ');

  // 3) 기타 태그 제거
  t = t.replaceAll(RegExp(r'<[^>]+>'), ' ');

  // 4) 공백 정규화
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

  return t;
}

/// ===================================================================
///  홈 페이지
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

  // 추천 슬라이드(가로, 카드 세로형)
  late final PageController _recController =
      PageController(viewportFraction: 0.62, keepPage: true, initialPage: 1000);
  int _recIndex = 0;

  // 추천 항목(Top5 + 더보기)
  List<_RecommendItem> _recommendItems = [];

  // 마이메뉴
  static const _kMyMenuPrefsKey = 'home_my_menu_keys_v1';
  final List<_MyMenuItem> _allMenus = const [
    _MyMenuItem(key: 'ai', title: 'AI 챗봇', icon: Icons.smart_toy_rounded),
    _MyMenuItem(key: 'trend', title: '자산추이', icon: Icons.show_chart_rounded),
    _MyMenuItem(
        key: 'event2',
        title: '운세',
        icon: Icons.auto_awesome_rounded), // 이벤트2(운세)
    _MyMenuItem(
        key: 'coupon', title: '쿠폰함', icon: Icons.local_activity_rounded),
    _MyMenuItem(key: 'event', title: '이벤트', icon: Icons.card_giftcard_rounded),
  ];
  List<String> _selectedKeys = const ['ai', 'trend', 'event2']; // 초기 3개

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreMyMenuSelection();
      await _checkBiometricSupport();
      await _loadTop5BySubscribers();
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
      // 필요 시 안내 가능
    }
  }

  /// 가입자수 Top5 로드(실패 시 정렬 없이 5개)
  Future<void> _loadTop5BySubscribers() async {
    try {
      final List<DepositProduct> products = await fetchAllProducts();
      final withId = products.where((p) => p.productId != null).toList();
      if (withId.isEmpty) {
        if (mounted) setState(() => _recommendItems = []);
        return;
      }

      final ids = withId.map((p) => p.productId!).toList();
      Map<int, int> counts = {};
      try {
        counts = await SubscriberService.fetchDistinctUsersBulk(ids);
      } catch (_) {
        counts = {};
      }

      withId.sort((a, b) =>
          (counts[b.productId] ?? 0).compareTo(counts[a.productId] ?? 0));

      final top5 = withId.take(5).toList();
      if (!mounted) return;
      setState(() {
        _recommendItems = top5
            .map((p) => _RecommendItem(
                  productId: p.productId!,
                  title: p.name ?? '상품 ${p.productId}',
                  caption: p.summary ?? '인기 상품',
                  subscribers: counts[p.productId] ?? 0,
                ))
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _recommendItems = []);
    }
  }

  // 마이메뉴 저장/복원
  Future<void> _restoreMyMenuSelection() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getStringList(_kMyMenuPrefsKey);
    if (saved != null && saved.isNotEmpty) {
      setState(() => _selectedKeys = saved.take(3).toList());
    }
  }

  Future<void> _saveMyMenuSelection(List<String> keys) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kMyMenuPrefsKey, keys.take(3).toList());
  }

  // 라우팅
  Future<T?> _push<T>(Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  // 로그아웃
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

  // 평균자산 폴백
  Future<int> _fetchAverageAssetPerUser() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return 12000000;
  }

  // 마이메뉴 라우팅
  void _openMenu(String key) {
    switch (key) {
      case 'ai':
        _push(const BnkChatScreen());
        break;
      case 'trend':
        _push(const MyServiceTestPage());
        break;
      case 'event2': // 운세
        _push(const StartScreen());
        break;
      case 'coupon': // 쿠폰함
        _push(const CouponsScreen());
        break;
      case 'event': // 이벤트(기획전/목록) → 임시로 쿠폰함 재사용
        _push(const CouponsScreen());
        break;
      default:
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('준비 중인 메뉴입니다.')));
    }
  }

  // 마이메뉴 편집
  Future<void> _editMyMenu() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final temp = _selectedKeys.toSet();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 8,
          ),
          child: StatefulBuilder(builder: (ctx, setSheet) {
            void toggle(String k) {
              if (temp.contains(k)) {
                temp.remove(k);
              } else {
                if (temp.length >= 3) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('최대 3개까지 선택할 수 있어요.')),
                  );
                  return;
                }
                temp.add(k);
              }
              setSheet(() {});
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('마이메뉴 편집',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('최대 3개 선택 (현재 ${temp.length}개)',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allMenus.map((m) {
                    final selected = temp.contains(m.key);
                    return ChoiceChip(
                      label: Text(m.title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      selected: selected,
                      onSelected: (_) => toggle(m.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, temp.toList()),
                        child: const Text('저장'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _selectedKeys = result.take(3).toList());
      _saveMyMenuSelection(_selectedKeys);
    }
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

            // 내 계좌 통합 정렬
            final allAccounts = [...demand, ...product]
              ..sort((a, b) => (b.balance ?? 0).compareTo(a.balance ?? 0));

            if (_visibleCount > allAccounts.length) {
              _visibleCount = math.min(3, allAccounts.length);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                _TotalHeaderCard(
                  total: total,
                  cash: cashTotal,
                  saving: savingTotal,
                  onDeposit: () => _push(DepositMainPage()),
                ),
                const SizedBox(height: 12),
                _AverageCompareCard(
                  myTotal: total,
                  onFetchAverage: _fetchAverageAssetPerUser,
                ),
                const SizedBox(height: 16),

                // 추천 서비스(가로 슬라이드 / 세로형 카드 / 간격 넉넉 / 6번째 전체보기-대형)
                _RecommendHorizontalSection(
                  controller: _recController,
                  items: _recommendItems,
                  onMore: () => _push(DepositMainPage()),
                  onTapItem: (pid) => _push(DepositDetailPage(productId: pid)),
                  onIndexChanged: (i) => setState(() => _recIndex = i),
                ),

                const SizedBox(height: 16),

                // 내 계좌
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
                            ),
                          );
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

                // 마이메뉴(편집)
                _MyMenuSection(
                  allItems: _allMenus,
                  selectedKeys: _selectedKeys,
                  onTapItem: _openMenu,
                  onEdit: _editMyMenu,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ─────────────────────────────────────────────────────────
 * 상단 총자산 / 평균자산 카드 (미변경)
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
              Text(
                money.format(total),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
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

class _AverageCompareCard extends StatefulWidget {
  final int myTotal;
  final Future<int> Function() onFetchAverage;

  const _AverageCompareCard({
    required this.myTotal,
    required this.onFetchAverage,
  });

  @override
  State<_AverageCompareCard> createState() => _AverageCompareCardState();
}

class _AverageCompareCardState extends State<_AverageCompareCard> {
  int? _avg;
  Object? _err;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final v = await widget.onFetchAverage();
      if (!mounted) return;
      setState(() {
        _avg = v;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int my = widget.myTotal;
    final int avg = _avg ?? 0;
    final double myD = my.toDouble();
    final double avgD = avg.toDouble();
    final double maxV = [myD, avgD, 1.0].reduce((a, b) => a > b ? a : b);
    final double myRatio = (myD / maxV).clamp(0.0, 1.0);
    final double avgRatio = (avgD / maxV).clamp(0.0, 1.0);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Expanded(
                child: Text('평균자산 대비 내 자산',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '평균자산을 불러오지 못해 0으로 표시합니다.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.red),
                ),
              ),
            const SizedBox(height: 8),
            _AvgRow(
                label: '내 총자산',
                value: my,
                ratio: myRatio,
                color: const Color(0xFF2962FF)),
            const SizedBox(height: 10),
            _AvgRow(
                label: '평균자산',
                value: avg,
                ratio: avgRatio,
                color: const Color(0xFF7C88FF)),
          ],
        ),
      ),
    );
  }
}

class _AvgRow extends StatelessWidget {
  final String label;
  final int value;
  final double ratio;
  final Color color;
  const _AvgRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
          width: 64, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 16,
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9ECF1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            Text(money.format(value) + ' 원',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    ]);
  }
}

/* ─────────────────────────────────────────────────────────
 * 추천 슬라이드 [가로 섹션] - 세로형 카드 / 간격 넉넉 / 큰 전체보기
 *  - 밝은 파스텔 5종 / 통일된 레이아웃(제목·요약 고정 높이)
 *  - 텍스트는 normalizeHtmlPlainText로 <br> → 공백 치환
 * ───────────────────────────────────────────────────────── */
class _RecommendItem {
  final int productId;
  final String title;
  final String caption;
  final int subscribers;
  const _RecommendItem({
    required this.productId,
    required this.title,
    required this.caption,
    required this.subscribers,
  });
}

class _RecommendHorizontalSection extends StatelessWidget {
  final PageController controller;
  final List<_RecommendItem> items;
  final void Function(int index)? onIndexChanged;
  final void Function(int productId) onTapItem;
  final VoidCallback onMore;

  const _RecommendHorizontalSection({
    super.key,
    required this.controller,
    required this.items,
    required this.onTapItem,
    required this.onMore,
    this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0.4,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('실시간 추천 서비스', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('추천 상품이 없습니다'),
            ],
          ),
        ),
      );
    }

    final listWithMore = List<_RecommendItem?>.from(items.take(5))..add(null);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0.4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('실시간 추천 서비스',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SizedBox(
              height: 308, // 카드가 세로로 길게 보이도록
              child: PageView.builder(
                controller: controller,
                scrollDirection: Axis.horizontal,
                onPageChanged: onIndexChanged,
                itemBuilder: (ctx, rawIndex) {
                  final i = rawIndex % listWithMore.length;
                  final data = listWithMore[i];

                  // 각 아이템 간격을 넉넉히
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: data == null
                        ? const _MoreTallCard()
                        : _RecommendTallCard(
                            item: data,
                            styleIndex: i % 5,
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ‘전체 보기’ (대형) 카드
class _MoreTallCard extends StatelessWidget {
  const _MoreTallCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 236,
        child: _GlassContainer(
          gradient: const [Color(0xFFEBF2FF), Color(0xFFFFEEF5)],
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DepositMainPage()),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.grid_view_rounded, size: 44),
                  SizedBox(height: 12),
                  Text('전체 보기',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  Text('더 많은 상품을 둘러보세요',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 공통 글라스 컨테이너
class _GlassContainer extends StatelessWidget {
  final Widget child;
  final List<Color>? gradient;
  const _GlassContainer({required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient ??
                    [const Color(0xFFF2F6FF), const Color(0xFFFFF1F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.5),
                  Colors.white.withOpacity(0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: const SizedBox.expand()),
          Container(
            decoration: BoxDecoration(
              border:
                  Border.all(color: Colors.white.withOpacity(0.55), width: 1.2),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 14,
                    offset: Offset(0, 8)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 세로형 추천 카드 (밝은 파스텔 5종 + 통일 레이아웃: 제목/요약 고정)
class _RecommendTallCard extends StatelessWidget {
  final _RecommendItem item;
  final int styleIndex; // 0~4

  static const double _cardWidth = 228;
  static const double _titleHeight = 52; // 2줄 고정
  static const double _summaryHeight = 44; // 2줄 고정

  const _RecommendTallCard({
    super.key,
    required this.item,
    required this.styleIndex,
  });

  // 밝은 파스텔 5종 (가벼운 대비)
  List<Color> get _bg {
    switch (styleIndex % 5) {
      case 0:
        return [
          const Color(0xFFEEF2FF),
          const Color(0xFFFFF0F6)
        ]; // 라이트 라일락 → 핑크
      case 1:
        return [
          const Color(0xFFEFF8FF),
          const Color(0xFFFFF7E8)
        ]; // 라이트 블루 → 라이트 옐로
      case 2:
        return [
          const Color(0xFFF3EDFF),
          const Color(0xFFEAF3FF)
        ]; // 라이트 퍼플 → 스카이
      case 3:
        return [
          const Color(0xFFFFEEF3),
          const Color(0xFFEFF7FF)
        ]; // 라이트 핑크 → 페일 블루
      default:
        return [
          const Color(0xFFF6FAFF),
          const Color(0xFFFFF0FF)
        ]; // 화이트 블루 → 라이트 라벤더
    }
  }

  // 미세한 데코(통일성 유지: 과하지 않게)
  Widget _accent() {
    switch (styleIndex % 5) {
      case 0:
        return Align(
          alignment: Alignment.topLeft,
          child: Container(
            margin: const EdgeInsets.only(top: 10, left: 10),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 4)
              ],
            ),
          ),
        );
      case 1:
        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.85),
              borderRadius: BorderRadius.circular(999),
            ),
            child:
                const Text('추천', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        );
      case 2:
        return IgnorePointer(
            child: CustomPaint(painter: _DiagonalPainter(opacity: .16)));
      case 3:
        return IgnorePointer(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: Colors.white.withOpacity(.75), width: 1.6),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tones = _bg;
    final title = normalizeHtmlPlainText(item.title);
    final caption = normalizeHtmlPlainText(item.caption);

    return Center(
      child: SizedBox(
        width: _cardWidth,
        child: _GlassContainer(
          gradient: tones,
          child: Stack(
            children: [
              _accent(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목(2줄 고정)
                    SizedBox(
                      height: _titleHeight,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 요약(2줄 고정)
                    SizedBox(
                      height: _summaryHeight,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    const Spacer(),

                    Text('가입자수 ${_fmtSubs(item.subscribers)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  DepositDetailPage(productId: item.productId),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(.92),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('신청하기',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
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

/// 대각선 패턴(은은하게)
class _DiagonalPainter extends CustomPainter {
  final double opacity;
  const _DiagonalPainter({this.opacity = .22});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 2;
    const step = 16.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/* ─────────────────────────────────────────────────────────
 * 마이메뉴/계좌/공통 (그대로)
 * ───────────────────────────────────────────────────────── */
class _MyMenuItem {
  final String key;
  final String title;
  final IconData icon;
  const _MyMenuItem(
      {required this.key, required this.title, required this.icon});
}

class _MyMenuSection extends StatelessWidget {
  final List<_MyMenuItem> allItems;
  final List<String> selectedKeys;
  final ValueChanged<String> onTapItem;
  final VoidCallback onEdit;

  const _MyMenuSection({
    super.key,
    required this.allItems,
    required this.selectedKeys,
    required this.onTapItem,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final visible =
        allItems.where((m) => selectedKeys.contains(m.key)).take(3).toList();

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
                  onPressed: onEdit,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('편집',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              itemCount: visible.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 78,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (ctx, i) {
                final m = visible[i];
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
                Text(
                  balanceText,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
 * 아이콘/컬러 + 자산 구성 바/범례 (미변경)
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
                    height: height, width: wSaving, color: _kSavingSolid),
              ),
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
