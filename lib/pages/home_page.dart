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

String normalizeHtmlPlainText(String? input) {
  if (input == null || input.isEmpty) return '';
  var t = input;
  t = t.replaceAll(
      RegExp(r'<\s*\/?\s*br\s*\/?\s*>', caseSensitive: false), ' ');
  t = t.replaceAll(RegExp(r'&nbsp;|&#160;', caseSensitive: false), ' ');
  t = t.replaceAll(RegExp(r'<[^>]+>'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _secureStorage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  late final Future<List<Account>> _accountsFuture = fetchAccounts(null);
  int _visibleCount = 3;

  late final PageController _recController =
      PageController(viewportFraction: 0.62, keepPage: true, initialPage: 1000);
  List<_RecommendItem> _recommendItems = [];

  static const _kMyMenuPrefsKey = 'home_my_menu_keys_v1';
  final List<_MyMenuItem> _allMenus = const [
    _MyMenuItem(key: 'ai', title: 'AI 챗봇', icon: Icons.smart_toy_rounded),
    _MyMenuItem(key: 'trend', title: '자산추이', icon: Icons.show_chart_rounded),
    _MyMenuItem(key: 'event2', title: '운세', icon: Icons.auto_awesome_rounded),
    _MyMenuItem(
        key: 'coupon', title: '쿠폰함', icon: Icons.local_activity_rounded),
    _MyMenuItem(key: 'event', title: '이벤트', icon: Icons.card_giftcard_rounded),
  ];
  List<String> _selectedKeys = const ['ai', 'trend', 'event2'];

  bool _hideAssets = false;

  // 파스텔 카드 색상
  static const Color _avgCardColor = Color(0xFFF3F6FF); // 연블루
  static const Color _menuCardColor = Color(0xFFFFF3F8); // 연핑크

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreMyMenuSelection();
      await _checkBiometricSupport();
      await _loadTop5BySubscribers();
    });
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('마이메뉴 구성이 저장되었어요.')),
    );
  }

  Future<T?> _push<T>(Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE0E3E7), width: 1),
        ),
        title:
            const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('정말 로그아웃하시겠어요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('아니요')),
          FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                  '/login', (Route<dynamic> route) => false // 이전 모든 라우트 제거
              );
            },
            child: const Text('네'),
          ),
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

  Future<int> _fetchAverageAssetPerUser() async {
    try {
      final resp = await getGlobalAvg();
      try {
        final dynamic d = resp as dynamic;
        final v = d.avgUserTotal;
        if (v is num) return v.toInt();
      } catch (_) {}
      try {
        final dynamic d = resp as dynamic;
        if (d.toJson != null) {
          final map = Map<String, dynamic>.from(d.toJson() as Map);
          final v = map['avgUserTotal'];
          if (v is num) return v.toInt();
        }
      } catch (_) {}
      return 0;
    } catch (_) {
      return 0;
    }
  }

  void _openMenu(String key) {
    switch (key) {
      case 'ai':
        _push(const BnkChatScreen());
        break;
      case 'trend':
        _push(const MyServiceTestPage());
        break;
      case 'event2':
        _push(const StartScreen());
        break;
      case 'coupon':
        _push(const CouponsScreen());
        break;
      case 'event':
        _push(const CouponsScreen());
        break;
      default:
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('준비 중인 메뉴입니다.')));
    }
  }

  /// 편집: 중앙 다이얼로그 + 실제 타일 스타일
  Future<void> _editMyMenu() async {
    final initial = _selectedKeys.toSet();
    final result = await showDialog<List<String>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            final temp = initial.toSet();
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
              setSheet(() => {});
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('마이메뉴 편집',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('최대 ${temp.length}/3개 선택',
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  // 실제 타일과 동일한 스타일의 선택 그리드
                  GridView.builder(
                    shrinkWrap: true,
                    itemCount: _allMenus.length,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisExtent: 96,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (ctx, i) {
                      final m = _allMenus[i];
                      final grad = _menuGradients[i % _menuGradients.length];
                      final glow = grad.last;
                      final selected = temp.contains(m.key);
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => toggle(m.key),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: grad,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: glow.withOpacity(.35),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 6))
                                ],
                                border: Border.all(
                                    color: Colors.white.withOpacity(.45)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(alignment: Alignment.center, children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.white
                                                    .withOpacity(.6),
                                                blurRadius: 12,
                                                spreadRadius: 2)
                                          ]),
                                    ),
                                    Icon(m.icon,
                                        size: 26, color: Colors.black87),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text(m.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            // 선택 체크 표시
                            Positioned(
                              right: 6,
                              top: 6,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 140),
                                opacity: selected ? 1 : 0.0,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                        color: Colors.white, width: 1.2),
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
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
              ),
            );
          },
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _selectedKeys = result.take(3).toList());
      _saveMyMenuSelection(_selectedKeys);
    }
  }

  String _maskMoney(int value) => _hideAssets ? '•••••' : money.format(value);

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

            final cashTotal =
                demand.fold<int>(0, (s, a) => s + (a.balance ?? 0));
            final savingTotal =
                product.fold<int>(0, (s, a) => s + (a.balance ?? 0));
            final total = cashTotal + savingTotal;

            final allAccounts = [...demand, ...product]
              ..sort((a, b) => (b.balance ?? 0).compareTo(a.balance ?? 0));

            if (_visibleCount > allAccounts.length) {
              _visibleCount = math.min(3, allAccounts.length);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                // 총자산 헤더
                _TotalHeaderPlain(
                  totalText: _maskMoney(total),
                  hideOn: _hideAssets,
                  onToggleHide: () =>
                      setState(() => _hideAssets = !_hideAssets),
                  onDeposit: () => _push(DepositMainPage()),
                ),
                const SizedBox(height: 12),

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
                        balanceText: '${_maskMoney(a.balance ?? 0)} 원',
                        leading: _fancyProductIcon(a),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    AccountDetailPage(accountId: a.id)),
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

                // 평균자산: 카드 배경색 지정
                const _SectionTitle('평균자산'),
                Card(
                  color: _avgCardColor,
                  child: _AverageCompareCard(
                    myTotal: _hideAssets ? 0 : total,
                    showMasked: _hideAssets,
                    onFetchAverage: _fetchAverageAssetPerUser,
                  ),
                ),

                const SizedBox(height: 16),

                // 마이메뉴: 카드 배경색 지정
                Card(
                  color: _menuCardColor,
                  child: _MyMenuSection(
                    allItems: _allMenus,
                    selectedKeys: _selectedKeys,
                    onTapItem: _openMenu,
                    onEdit: _editMyMenu,
                  ),
                ),

                const SizedBox(height: 16),

                // 실시간 추천 - Outlined Card 유지
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE6EAF0)),
                  ),
                  child: _RecommendHorizontalSection(
                    controller: _recController,
                    items: _recommendItems,
                    onMore: () => _push(DepositMainPage()),
                    onTapItem: (pid) =>
                        _push(DepositDetailPage(productId: pid)),
                    onIndexChanged: (_) {},
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ───────────────────────────────── UI CHUNKS ───────────────────────────────── */

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

// 총자산 헤더: “총 자산” 텍스트 옆에 눈 아이콘
class _TotalHeaderPlain extends StatelessWidget {
  final String totalText;
  final bool hideOn;
  final VoidCallback onToggleHide;
  final VoidCallback onDeposit;

  const _TotalHeaderPlain({
    required this.totalText,
    required this.hideOn,
    required this.onToggleHide,
    required this.onDeposit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 타이틀 + 눈 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('총 자산',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(width: 6),
              InkWell(
                onTap: onToggleHide,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    hideOn
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 금액 줄
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                totalText,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Text('원',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      )),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 160,
            height: 44,
            child: OutlinedButton(
              onPressed: onDeposit,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: Colors.grey.shade400),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 20),
                  SizedBox(width: 6),
                  Text('예적금 만들기',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 평균자산 카드 (가독성 업)
class _AverageCompareCard extends StatefulWidget {
  final int myTotal;
  final bool showMasked;
  final Future<int> Function() onFetchAverage;

  const _AverageCompareCard({
    required this.myTotal,
    required this.onFetchAverage,
    this.showMasked = false,
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

    String fmt(int v) => money.format(v);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('내 자산 vs 평균',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('평균자산을 불러오지 못해 0으로 표시합니다.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.red)),
            ),
          const SizedBox(height: 8),
          _AvgRow(
            label: '내 총자산',
            valueText: widget.showMasked ? '••••• 원' : '${fmt(my)} 원',
            ratio: widget.showMasked ? 0.0 : myRatio,
            color: const Color(0xFF2962FF),
          ),
          const SizedBox(height: 12),
          _AvgRow(
            label: '평균자산',
            valueText: '${fmt(avg)} 원',
            ratio: avgRatio,
            color: const Color(0xFF7C88FF),
          ),
        ],
      ),
    );
  }
}

class _AvgRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double ratio;
  final Color color;
  const _AvgRow({
    required this.label,
    required this.valueText,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700))),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 바
              SizedBox(
                height: 18,
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
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.35),
                              blurRadius: 10,
                              spreadRadius: 1)
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────────── 추천 섹션 ───────────────────────────── */

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
        child: const Padding(
          padding: EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('실시간 추천 서비스', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('추천 상품이 없습니다'),
            ],
          ),
        ),
      );
    }

    final listWithMore = List<_RecommendItem?>.from(items.take(5))..add(null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('실시간 추천 서비스',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SizedBox(
            height: 308,
            child: PageView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              onPageChanged: onIndexChanged,
              itemBuilder: (ctx, rawIndex) {
                final i = rawIndex % listWithMore.length;
                final data = listWithMore[i];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: data == null
                      ? const _MoreTallCard()
                      : _RecommendTallCard(item: data, styleIndex: i % 5),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTallCard extends StatelessWidget {
  const _MoreTallCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 236,
        child: _GlassContainer(
          gradient: const [Color(0xFFEBF2FF), Color(0xFFFFEEF5)],
          glowColor: const Color(0xFF7C88FF),
          child: InkWell(
            onTap: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => DepositMainPage()));
            },
            borderRadius: BorderRadius.circular(24),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(18, 22, 18, 22),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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

// 공통 글래스 컨테이너
class _GlassContainer extends StatelessWidget {
  final Widget child;
  final List<Color>? gradient;
  final Color? glowColor;
  const _GlassContainer({required this.child, this.gradient, this.glowColor});

  @override
  Widget build(BuildContext context) {
    final gc = glowColor ?? Colors.black12;
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
                  Colors.white.withOpacity(0.55),
                  Colors.white.withOpacity(0.20)
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
              boxShadow: [
                BoxShadow(
                    color: gc.withOpacity(0.45),
                    blurRadius: 28,
                    spreadRadius: 2)
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _RecommendTallCard extends StatelessWidget {
  final _RecommendItem item;
  final int styleIndex;

  static const double _cardWidth = 228;
  static const double _titleHeight = 52;
  static const double _summaryHeight = 44;

  const _RecommendTallCard(
      {super.key, required this.item, required this.styleIndex});

  List<Color> get _bg {
    switch (styleIndex % 5) {
      case 0:
        return [const Color(0xFFDBE4FF), const Color(0xFFFFE3EC)];
      case 1:
        return [const Color(0xFFCFE9FF), const Color(0xFFFFF0CD)];
      case 2:
        return [const Color(0xFFE2D6FF), const Color(0xFFCCE2FF)];
      case 3:
        return [const Color(0xFFFFD8E6), const Color(0xFFD9ECFF)];
      default:
        return [const Color(0xFFDEEEFF), const Color(0xFFF5E0FF)];
    }
  }

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
          glowColor: const Color(0xFF7C88FF),
          child: Stack(
            children: [
              _accent(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                DepositDetailPage(productId: item.productId),
                          ));
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(.94),
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

/* ───────────────────────────── COMMON ───────────────────────────── */

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Text('마이메뉴', style: TextStyle(fontWeight: FontWeight.w800)),
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
              mainAxisExtent: 88,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (ctx, i) {
              final m = visible[i];
              final grad = _menuGradients[i % _menuGradients.length];
              final glow = grad.last;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTapItem(m.key),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                        colors: grad,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(
                          color: glow.withOpacity(.35),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(0, 6))
                    ],
                    border: Border.all(color: Colors.white.withOpacity(.45)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(alignment: Alignment.center, children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.white.withOpacity(.6),
                                    blurRadius: 12,
                                    spreadRadius: 2)
                              ]),
                        ),
                        Icon(m.icon, size: 26, color: Colors.black87),
                      ]),
                      const SizedBox(height: 8),
                      Text(m.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

const List<List<Color>> _menuGradients = [
  [Color(0xFFE3F2FF), Color(0xFFD7E0FF)],
  [Color(0xFFFFF1D6), Color(0xFFFFD6E8)],
  [Color(0xFFE7E4FF), Color(0xFFD4EEFF)],
  [Color(0xFFFFE2EE), Color(0xFFDDEBFF)],
  [Color(0xFFEAF6FF), Color(0xFFF0E1FF)],
];

/* ───── 계좌 아이콘: 사각형 + 파스텔 채움 + 글로우 ───── */

class _IconMeta {
  final IconData icon;
  final Color fill; // 내부 채움(파스텔)
  const _IconMeta(this.icon, this.fill);
}

_IconMeta _iconMetaForProduct(Account a) {
  String pt = '';
  try {
    pt = (a.productType ?? '').toString();
  } catch (_) {}
  final hint = '${pt} ${a.accountName ?? ''}'.toLowerCase();
  if (hint.contains('walk') || hint.contains('step') || hint.contains('헬스')) {
    return const _IconMeta(
        Icons.directions_walk_rounded, Color(0xFFB8FFDA)); // mint
  }
  if (hint.contains('savings') ||
      hint.contains('installment') ||
      hint.contains('적금')) {
    return const _IconMeta(Icons.savings_outlined, Color(0xFFFFD6E8)); // pink
  }
  if (hint.contains('deposit') || hint.contains('예금') || hint.contains('정기')) {
    return const _IconMeta(
        Icons.account_balance_rounded, Color(0xFFD7E0FF)); // periwinkle
  }
  if (a.accountType == AccountType.demand ||
      hint.contains('입출금') ||
      hint.contains('checking')) {
    return const _IconMeta(
        Icons.account_balance_wallet_outlined, Color(0xFFFFF1D6)); // butter
  }
  return const _IconMeta(
      Icons.account_balance_outlined, Color(0xFFE7E4FF)); // lavender
}

Widget _fancyProductIcon(Account a) {
  final m = _iconMetaForProduct(a);
  return Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: m.fill,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
            color: m.fill.withOpacity(.55),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 8)),
        BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 6,
            offset: const Offset(0, 2)),
      ],
      border: Border.all(color: Colors.white.withOpacity(.6), width: 1),
    ),
    child: Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            width: 28,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Center(child: Icon(m.icon, size: 22, color: Colors.black87)),
      ],
    ),
  );
}

/* ───── 공통 카드/상태 ───── */

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
      borderRadius: BorderRadius.circular(14),
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
