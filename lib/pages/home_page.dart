// lib/pages/home_page.dart
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:reframe/event/pages/start_page.dart';
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

/* ───────────────────────────────── 유틸 ───────────────────────────────── */
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

/* ───────────────────────────────── 홈 화면 ───────────────────────────────── */
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

/* 첫 진입 게이트 로딩 번들(계좌 + 평균자산) */
class _HomeBundle {
  final List<Account> accounts;
  final int avgUserTotal;
  _HomeBundle({required this.accounts, required this.avgUserTotal});
}

class _HomePageState extends State<HomePage> {
  final _secureStorage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  // 페이지 게이트: 계좌 + 평균자산 모두 끝난 뒤 화면 표시
  late Future<_HomeBundle> _homeFuture = _loadHomeBundle();

  int _visibleCount = 3;

  // ⭐ 추천 슬라이더: 3개 그리드 한 페이지, 양쪽 ‘반 잘림’ 피킹
  late final PageController _recController =
  PageController(viewportFraction: 0.9, keepPage: true);

  List<_RecommendItem> _recommendItems = [];

  // 마이메뉴
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreMyMenuSelection();
      await _checkBiometricSupport();
      await _loadTop5BySubscribers(); // 추천은 비차단 로딩
    });
  }

  /* ---------- 초기 동시 로딩 ---------- */
  Future<_HomeBundle> _loadHomeBundle() async {
    final accounts = await fetchAccounts(null);
    final avg = await _fetchAverageAssetPerUser();
    return _HomeBundle(accounts: accounts, avgUserTotal: avg);
  }

  Future<void> _checkBiometricSupport() async {
    final canCheck = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    final available = await _auth.getAvailableBiometrics();
    final enabled = await _secureStorage.read(key: 'biometricEnabled');
    if (canCheck && supported && available.isNotEmpty && enabled == null) {
      // 필요시 안내 가능
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
      final topN = withId.take(9).toList(); // 3x3까지
      if (!mounted) return;
      setState(() {
        _recommendItems = topN
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

  /* 마이메뉴 복구/저장 */
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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE6EAF0)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('로그아웃',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('정말 로그아웃하시겠어요?'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Color(0xFFE6EAF0)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('아니요'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                            '/login', (Route<dynamic> route) => false // 이전 모든 라우트 제거
                        );
                        _secureStorage.deleteAll();
                      },
                      child: const Text('네'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  /* 평균자산 안전 파서 */
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
        _push(const StartPage());
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

  /* ───────── 마이메뉴 편집 모달: 배경/그림자 제거, 아이콘+텍스트만 ───────── */
  Future<void> _editMyMenu() async {
    // ⬇️ 여기로 올립니다: 다이얼로그 생애주기 동안 유지될 임시 선택값
    var temp = _selectedKeys.toSet();

    final result = await showDialog<List<String>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE6EAF0)),
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            final primary = Theme.of(ctx).colorScheme.primary;

            void toggle(String k) {
              if (temp.contains(k)) {
                temp.remove(k);
              } else {
                if (temp.length >= 3) {
                  ScaffoldMessenger.of(context).showSnackBar( // ← ctx 대신 context 사용 권장
                    const SnackBar(content: Text('최대 3개까지 선택할 수 있어요.')),
                  );
                  return;
                }
                temp.add(k);
              }
              setSheet(() {}); // 동일한 temp를 다시 그리기
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('마이메뉴 편집',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('최대 ${temp.length}/3개 선택',
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    itemCount: _allMenus.length,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisExtent: 96,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (ctx, i) {
                      final m = _allMenus[i];
                      final selected = temp.contains(m.key);
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => toggle(m.key),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(m.icon, size: 28, color: Colors.black87),
                                  const SizedBox(height: 8),
                                  Text(m.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800, fontSize: 12)),
                                ],
                              ),
                            ),
                            if (selected)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Icon(Icons.check_circle,
                                    size: 22, color: primary),
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
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: const BorderSide(color: Color(0xFFE6EAF0)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, temp.toList()),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
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

    if (result != null) {
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
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _homeFuture = _loadHomeBundle();
            });
            await _homeFuture;
          },
          child: FutureBuilder<_HomeBundle>(
            future: _homeFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const ColoredBox(
                  color: Colors.white,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return _ErrorView(
                  error: '${snap.error}',
                  onRetry: () => setState(() {}),
                );
              }

              final bundle = snap.data!;
              final accounts = bundle.accounts;
              final avgAsset = bundle.avgUserTotal;

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
                  const Padding(
                    padding: EdgeInsets.only(left: 6, bottom: 8),
                    child: Text('내 계좌',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
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
                          style:
                          TextButton.styleFrom(foregroundColor: Colors.black),
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

                  // 평균자산

                  _RaisedSection(
                    child: _AverageCompareCard(
                      myTotal: _hideAssets ? 0 : total,
                      avgTotal: avgAsset,
                      showMasked: _hideAssets,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 마이메뉴
                  _RaisedSection(
                    child: _MyMenuSection(
                      allItems: _allMenus,
                      selectedKeys: _selectedKeys,
                      onTapItem: _openMenu,
                      onEdit: _editMyMenu,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ⭐ 실시간 추천: 제목 + 3개 피킹 슬라이더(양쪽 패딩 없음)

                  _RaisedSection(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    child: _RecommendSimpleSection(
                      items: _recommendItems,
                      onTapItem: (pid) =>
                          _push(DepositDetailPage(productId: pid)),
                      onMore: () => _push(DepositMainPage()),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── 공통 섹션 래퍼(입체감) ───────────────────────── */
class _RaisedSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _RaisedSection({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6)),
          BoxShadow(
              color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

/* ───────────────────────── UI CHUNKS ───────────────────────── */
// (아래 부분은 이전과 동일 – 총자산 헤더, 평균자산 바, 추천 카드, 계좌 카드 등)

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

/* 평균자산 */
class _AverageCompareCard extends StatelessWidget {
  final int myTotal;
  final int avgTotal;
  final bool showMasked;
  const _AverageCompareCard({
    required this.myTotal,
    required this.avgTotal,
    this.showMasked = false,
  });
  @override
  Widget build(BuildContext context) {
    final double myD = myTotal.toDouble();
    final double avgD = avgTotal.toDouble();
    final double maxV = [myD, avgD, 1.0].reduce((a, b) => a > b ? a : b);
    final double myRatio = (myD / maxV).clamp(0.0, 1.0);
    final double avgRatio = (avgD / maxV).clamp(0.0, 1.0);

    String fmt(int v) => money.format(v);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvgRow(
            label: '내 총자산',
            valueText: showMasked ? '••••• 원' : '${fmt(myTotal)} 원',
            ratio: showMasked ? 0.0 : myRatio,
            color: const Color(0xFF2962FF),
          ),
          const SizedBox(height: 12),
          _AvgRow(
            label: '평균자산',
            valueText: '${fmt(avgTotal)} 원',
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
    const double _barH = 10; // 막대바 높이

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1) 라벨과 막대바를 같은 줄에 배치
        Row(
          crossAxisAlignment: CrossAxisAlignment.center, // 라벨 ↔ 막대바 높이 맞춤
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: _barH,
                child: Stack(
                  children: [
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
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // 2) 값 텍스트는 막대바 밑에 배치
        Padding(
          padding: const EdgeInsets.only(left: 72), // 라벨 영역만큼 들여쓰기
          child: Text(
            valueText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────── 모델: 사진 경로 추가 ───────────────────────── */
class _RecommendItem {
  final int productId;
  final String title;
  final String caption;
  final int subscribers;
  final String? photoAssetPath; // 예: 'assets/images/recommend/p1.png'

  const _RecommendItem({
    required this.productId,
    required this.title,
    required this.caption,
    required this.subscribers,
    this.photoAssetPath,
  });
}

/* ───────────────────────── 실시간 추천 (깔끔 카드형) ─────────────────────────
   - 가로 스크롤
   - 카드 높이/폭 외부에서 조절 (itemHeight, itemWidth) → 이 값이 "실제" 적용됨
   - 마지막 카드 "더보기"
*/
class _RecommendSimpleSection extends StatelessWidget {
  final List<_RecommendItem> items;
  final void Function(int productId) onTapItem;
  final VoidCallback onMore;

  // 카드 크기 파라미터 (필요 시 호출부에서 조절)
  final double itemWidth;
  final double itemHeight;

  const _RecommendSimpleSection({
    super.key,
    required this.items,
    required this.onTapItem,
    required this.onMore,
    this.itemWidth = 168, // 기본 카드 너비
    this.itemHeight = 200, // 기본 카드 높이 (← 섹션이 이 높이로 고정됨)
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 타이틀
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("윤다영님을 위한",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
              SizedBox(height: 2),
              Text("실시간 추천 서비스예요",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.black)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 섹션 높이를 카드 높이로 "딱" 고정 → 내부 컨텐츠가 정확히 이 높이에 맞춰짐
        SizedBox(
          height: itemHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: items.length + 1, // 마지막은 "더보기"
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              if (i == items.length) {
                return SizedBox(
                  width: 120,
                  height: itemHeight,
                  child: _MoreCard(onTap: onMore, height: itemHeight),
                );
              }
              final item = items[i];
              return SizedBox(
                width: itemWidth,
                height: itemHeight, // ← 이 값이 실제 적용(부모 SizedBox가 강제)
                child: _RecommendFlatCard(
                  item: item,
                  onTap: () => onTapItem(item.productId),
                  rank: i + 1,
                  styleIndex: i, // 카드마다 다른 스타일
                  height: itemHeight,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ──────────────────────── 카드: 사진 중심 · 디바이더 없음 ────────────────────────
   - 제목 1줄, 섬머리 2줄
   - 중앙 사진(상품별로 서로 다른 사진 넣기)
   - 사진 없으면 매트 아이콘 fallback
*/
class _RecommendFlatCard extends StatelessWidget {
  final _RecommendItem item;
  final VoidCallback onTap;
  final int rank;
  final int styleIndex;
  final double height;

  const _RecommendFlatCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.rank,
    required this.styleIndex,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final s = _iconStyleFor(styleIndex);
    final title = normalizeHtmlPlainText(item.title);
    final caption = normalizeHtmlPlainText(item.caption);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        // 내부 Container는 높이 지정 불필요(부모 SizedBox가 이미 height를 고정함)
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EAF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 순위
            Text(
              '$rank위',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: s.accent,
              ),
            ),
            const SizedBox(height: 10),

            // 가운데 사진(우선) / 아이콘(fallback)
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: s.bg, // 사진 없을 때 보이는 매트 배경
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: (item.photoAssetPath != null &&
                      item.photoAssetPath!.isNotEmpty)
                      ? Image.asset(
                    item.photoAssetPath!,
                    fit: BoxFit.cover,
                    // 타입 명시(안전)
                    errorBuilder: (BuildContext context, Object error,
                        StackTrace? stackTrace) {
                      return Icon(s.icon, size: 34, color: s.fg);
                    },
                  )
                      : Icon(s.icon, size: 34, color: s.fg),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 아래 텍스트 영역 전체를 확장하고, 섬머리 앞에 Spacer로 밀기
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Spacer(), // ← 이게 섬머리를 아래로 밀어줍니다.
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54, height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ────────────────────────────── "더보기" 카드 ────────────────────────────── */
class _MoreCard extends StatelessWidget {
  final VoidCallback onTap;
  final double height;
  const _MoreCard({super.key, required this.onTap, required this.height});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height, // 섹션 높이에 맞춰 동일하게
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EAF0)),
        ),
        child: const Center(
          child: Text(
            "더보기",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

/* ────────────────────────────── 아이콘 스타일 세트 ────────────────────────────── */
class _IconStyle {
  final IconData icon;
  final Color bg; // 아이콘/사진 배경(매트)
  final Color fg; // 아이콘 색
  final Color accent; // 포인트(순위 색)
  const _IconStyle(this.icon, this.bg, this.fg, this.accent);
}

_IconStyle _iconStyleFor(int i) {
  switch (i % 5) {
    case 0:
      return const _IconStyle(Icons.savings_rounded, Color(0xFFF5F6FA),
          Colors.black87, Color(0xFF3B82F6));
    case 1:
      return const _IconStyle(Icons.account_balance_rounded, Color(0xFFF4F1FF),
          Color(0xFF4B5563), Color(0xFF7C3AED));
    case 2:
      return const _IconStyle(Icons.trending_up_rounded, Color(0xFFEFFAF5),
          Color(0xFF1F2937), Color(0xFF10B981));
    case 3:
      return const _IconStyle(Icons.shield_rounded, Color(0xFFFFF7ED),
          Color(0xFF374151), Color(0xFFF59E0B));
    default:
      return const _IconStyle(Icons.star_rounded, Color(0xFFFFF1F5),
          Color(0xFF111827), Color(0xFFEF4444));
  }
}

/* ───── 계좌/공통 카드 등 (동일) ───── */
class _IconMeta {
  final IconData icon;
  final Color fill;
  const _IconMeta(this.icon, this.fill);
}

_IconMeta _iconMetaForProduct(Account a) {
  String pt = '';
  try {
    pt = (a.productType ?? '').toString();
  } catch (_) {}
  final hint = '${pt} ${a.accountName ?? ''}'.toLowerCase();
  if (hint.contains('walk') || hint.contains('step') || hint.contains('헬스')) {
    return const _IconMeta(Icons.directions_walk_rounded, Color(0xFFB8FFDA));
  }
  if (hint.contains('savings') ||
      hint.contains('installment') ||
      hint.contains('적금')) {
    return const _IconMeta(Icons.savings_outlined, Color(0xFFFFD6E8));
  }
  if (hint.contains('deposit') || hint.contains('예금') || hint.contains('정기')) {
    return const _IconMeta(Icons.account_balance_rounded, Color(0xFFD7E0FF));
  }
  if (a.accountType == AccountType.demand ||
      hint.contains('입출금') ||
      hint.contains('checking')) {
    return const _IconMeta(
        Icons.account_balance_wallet_outlined, Color(0xFFFFF1D6));
  }
  return const _IconMeta(Icons.account_balance_outlined, Color(0xFFE7E4FF));
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

/* 마이메뉴 그라데이션(섹션 타일용) */
const List<List<Color>> _menuGradients = [
  [Color(0xFFE3F2FF), Color(0xFFD7E0FF)],
  [Color(0xFFFFF1D6), Color(0xFFFFD6E8)],
  [Color(0xFFE7E4FF), Color(0xFFD4EEFF)],
  [Color(0xFFFFE2EE), Color(0xFFDDEBFF)],
  [Color(0xFFEAF6FF), Color(0xFFF0E1FF)],
];

/* 마이메뉴 섹션 */
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

    return Column(
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
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
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
    );
  }
}

class _MyMenuItem {
  final String key;
  final String title;
  final IconData icon;
  const _MyMenuItem(
      {required this.key, required this.title, required this.icon});
}
