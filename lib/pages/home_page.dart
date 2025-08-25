// lib/pages/home_page.dart
import 'dart:ui' show FontFeature;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:reframe/constants/number_format.dart';
import 'package:reframe/main.dart';

// 모델/서비스/페이지
import 'package:reframe/model/account.dart';
import 'package:reframe/pages/account/account_detail_page.dart';
import 'package:reframe/pages/auth/login_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/service/account_service.dart';

import '../constants/text_animation.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _secureStorage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  // 데이터 로딩
  late final Future<List<Account>> _accountsFuture = fetchAccounts(null);

  // 내 계좌 섹션 "더보기"
  int _visibleCount = 3;

  // 코호트(벤치마크) 선택
  final List<String> _ageBands = const ['20s', '30s', '40s'];
  String _selectedAgeBand = '20s';
  String _selectedGender = 'F'; // 'M' | 'F'

  // 추천 슬라이드
  final PageController _recController =
      PageController(viewportFraction: 0.86, keepPage: true);
  int _recPage = 0;

  // 마이메뉴 (최대 3개)
  static const _kMenuStorageKey = 'home_my_menu';
  final List<_MyMenuItem> _menuPool = const [
    _MyMenuItem(key: 'ai', title: 'AI 챗봇', icon: Icons.smart_toy_rounded),
    _MyMenuItem(key: 'trend', title: '자산추이', icon: Icons.show_chart_rounded),
    _MyMenuItem(key: 'event', title: '이벤트', icon: Icons.card_giftcard_rounded),
    _MyMenuItem(
        key: 'test', title: '저축성향테스트', icon: Icons.psychology_alt_rounded),
    _MyMenuItem(
        key: 'coupon', title: '쿠폰함', icon: Icons.local_activity_rounded),
  ];
  List<String> _myMenuKeys = ['ai', 'trend', 'event']; // 기본 3개

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkBiometricSupport();
      await _loadMyMenu();
    });
  }

  Future<void> _checkBiometricSupport() async {
    final canCheckBiometrics = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    final available = await _auth.getAvailableBiometrics();
    final alreadyEnabled = await _secureStorage.read(key: 'biometricEnabled');
    if (canCheckBiometrics &&
        isSupported &&
        available.isNotEmpty &&
        alreadyEnabled == null) {
      // 필요 시 생체 등록 유도 다이얼로그 표시 가능
    }
  }

  Future<void> _loadMyMenu() async {
    final saved = await _secureStorage.read(key: _kMenuStorageKey);
    if (saved != null && saved.isNotEmpty) {
      final keys = saved.split(',').where((k) => k.trim().isNotEmpty).toList();
      if (keys.isNotEmpty) {
        setState(() => _myMenuKeys = keys.take(3).toList());
      }
    }
  }

  Future<void> _saveMyMenu() async {
    await _secureStorage.write(
        key: _kMenuStorageKey, value: _myMenuKeys.join(','));
  }

  Future<T?> _push<T>(Widget page) {
    return Navigator.of(context)
        .push<T>(MaterialPageRoute(builder: (_) => page));
  }

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
  void dispose() {
    _recController.dispose();
    super.dispose();
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
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Account>>(
          future: _accountsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(
                  error: '${snapshot.error}', onRetry: () => setState(() {}));
            }
            final accounts = snapshot.data ?? [];

            // 분류
            final productAccounts = accounts
                .where((a) => a.accountType == AccountType.product)
                .toList();
            final demandAccounts = accounts
                .where((a) => a.accountType == AccountType.demand)
                .toList();

            // 합계
            final cashTotal =
                demandAccounts.fold<int>(0, (s, a) => s + (a.balance ?? 0));
            final savingTotal =
                productAccounts.fold<int>(0, (s, a) => s + (a.balance ?? 0));
            final total = cashTotal + savingTotal;

            // "내 계좌"는 잔액 내림차순으로 정렬
            final allMyAccounts = [...demandAccounts, ...productAccounts]
              ..sort((a, b) => (b.balance ?? 0).compareTo(a.balance ?? 0));

            if (_visibleCount > allMyAccounts.length) {
              _visibleCount = math.min(3, allMyAccounts.length);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                // ===== 상단: 총 자산 =====
                _TotalHeaderCard(
                  total: total,
                  cash: cashTotal,
                  saving: savingTotal,
                  onDeposit: () => _push(DepositMainPage()),
                ),

                const SizedBox(height: 12),

                // ===== 코호트 선택 + 벤치마크 =====
                _CohortPicker(
                  ageBands: _ageBands,
                  selectedAgeBand: _selectedAgeBand,
                  selectedGender: _selectedGender,
                  onChanged: (age, gender) => setState(() {
                    _selectedAgeBand = age;
                    _selectedGender = gender;
                  }),
                ),
                const SizedBox(height: 8),
                FutureBuilder<_BenchmarkData>(
                  future: _fetchBenchmark(
                      ageBand: _selectedAgeBand, gender: _selectedGender),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const _BenchmarkSkeleton();
                    }
                    final bm = snap.data;
                    if (bm == null) return const SizedBox.shrink();
                    return _BenchmarkCard(
                      title: '동일 코호트 평균과 비교',
                      cohortLabel:
                          '${_selectedAgeBand.toUpperCase()} · ${_selectedGender == 'M' ? '남성' : '여성'}',
                      myCash: cashTotal,
                      mySaving: savingTotal,
                      avgCash: bm.cashAvg,
                      avgSaving: bm.savingAvg,
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ===== 추천 슬라이드 (Top5) =====
                _RecommendCarousel(
                  controller: _recController,
                  onPageChanged: (i) => setState(() => _recPage = i),
                  page: _recPage,
                ),

                const SizedBox(height: 20),

                // ===== 내 계좌 (잔액 높은 순 3개) + 더보기/간략히 보기 =====
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text('내 계좌',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    const Spacer(),
                    if (allMyAccounts.length > 3)
                      Text(
                        '총 ${allMyAccounts.length}개',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.black54),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (allMyAccounts.isEmpty)
                  _EmptyAccounts(onExplore: () => _push(DepositMainPage()))
                else ...[
                  ...allMyAccounts.take(_visibleCount).map(
                        (a) => _AccountCard(
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
                        ),
                      ),
                  if (allMyAccounts.length > 3)
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        // 한번만 눌러도 전체 펼치기 → 버튼 즉시 "간략히 보기"로 변환
                        onPressed: () {
                          setState(() {
                            if (_visibleCount < allMyAccounts.length) {
                              _visibleCount = allMyAccounts.length; // 전부 펼치기
                            } else {
                              _visibleCount = math.min(3, allMyAccounts.length);
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                        ),
                        icon: Icon(
                          (_visibleCount < allMyAccounts.length)
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 22,
                        ),
                        label: Text(
                          (_visibleCount < allMyAccounts.length)
                              ? '더보기'
                              : '간략히 보기',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],

                const SizedBox(height: 16),

                // ===== 마이메뉴 (최대 3개, 편집 가능) =====
                _MyMenuSection(
                  pool: _menuPool,
                  selectedKeys: _myMenuKeys,
                  onTapItem: (key) => _openMenu(key),
                  onTapEdit: () => _openMenuEditor(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===== 벤치마크 (목데이터) — API 붙일 때 이 함수만 교체 =====
  Future<_BenchmarkData> _fetchBenchmark(
      {required String ageBand, required String gender}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final base = switch (ageBand) {
      '20s' => 600000,
      '30s' => 1400000,
      '40s' => 2200000,
      _ => 1000000,
    };
    final bias = (gender == 'M') ? 1.08 : 0.97;
    final cashAvg = (base * 0.42 * bias).round();
    final savingAvg = (base * 1.9 * bias).round();
    return _BenchmarkData(cashAvg: cashAvg, savingAvg: savingAvg);
  }

  // ===== 메뉴 실행 라우팅 (데모 페이지)
  void _openMenu(String key) {
    Widget page;
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
      default:
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('준비 중인 메뉴입니다.')));
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // === 편집 시트: 네비게이션 바 위로 뜨고 배경 어둡게 보이도록 설정
  Future<void> _openMenuEditor() async {
    final current = [..._myMenuKeys];

    // ✅ 전역 네비게이터 컨텍스트 확보 (main.dart에 선언된 navigatorKey 사용)
    final BuildContext rootCtx = navigatorKey.currentContext ?? context;

    await showModalBottomSheet(
      context: rootCtx, // ✅ 루트 컨텍스트로 고정
      useRootNavigator: true, // ✅ 루트 네비게이터 사용
      isScrollControlled: true,
      showDragHandle: true,
      barrierColor: Colors.black.withOpacity(0.45), // ✅ 배경 어둡게
      useSafeArea: true, // ✅ 상태바/네비바 침범 방지
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
                const SizedBox(height: 6),
                const Text('마이메뉴 편집 (최대 3개)',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _menuPool.map((m) {
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
                        setState(() {
                          _myMenuKeys = current.take(3).toList();
                        });
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

/* =============================== 위젯/모듈 =============================== */

/// 상단 총자산 카드 (카운트업 + 자산구성 바)
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
            textBaseline: TextBaseline.alphabetic, // ✅ 숫자-원 기준선 맞춤
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

/* ---------- 벤치마크 ---------- */

class _BenchmarkData {
  final int cashAvg;
  final int savingAvg;
  const _BenchmarkData({required this.cashAvg, required this.savingAvg});
}

class _CohortPicker extends StatelessWidget {
  final List<String> ageBands;
  final String selectedAgeBand;
  final String selectedGender;
  final void Function(String ageBand, String gender) onChanged;

  const _CohortPicker({
    super.key,
    required this.ageBands,
    required this.selectedAgeBand,
    required this.selectedGender,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            const Text('코호트', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: selectedAgeBand,
              underline: const SizedBox.shrink(),
              items: ageBands
                  .map((e) => DropdownMenuItem(
                      value: e, child: Text(e.replaceFirst('s', '대'))))
                  .toList(),
              onChanged: (v) => onChanged(v ?? selectedAgeBand, selectedGender),
            ),
            const SizedBox(width: 8),
            ToggleButtons(
              isSelected: [selectedGender == 'M', selectedGender == 'F'],
              onPressed: (i) => onChanged(selectedAgeBand, i == 0 ? 'M' : 'F'),
              constraints: const BoxConstraints(minHeight: 30, minWidth: 38),
              borderRadius: BorderRadius.circular(8),
              children: const [
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('남')),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('여')),
              ],
            ),
            const Spacer(),
            const Icon(Icons.insights_rounded, size: 18, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _BenchmarkCard extends StatelessWidget {
  final String title;
  final String cohortLabel;
  final int myCash, mySaving, avgCash, avgSaving;

  const _BenchmarkCard({
    super.key,
    required this.title,
    required this.cohortLabel,
    required this.myCash,
    required this.mySaving,
    required this.avgCash,
    required this.avgSaving,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int mine, int avg) {
      final diff = mine - avg;
      final pct = (avg == 0) ? 0.0 : (diff / avg * 100);
      final up = diff >= 0;
      final icon = up ? Icons.trending_up_rounded : Icons.trending_down_rounded;
      final color = up ? _kPrimary : const Color(0xFFEF5350);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Row(
          children: [
            SizedBox(
                width: 64,
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            Expanded(
              child: Text('${money.format(mine)} 원',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${money.format(avg)} 원',
                  textAlign: TextAlign.right,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.black54)),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: color.withOpacity(.4)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text('${pct.abs().toStringAsFixed(0)}%',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, color: color)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0.4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE6EAF0)),
                  ),
                  child: Text(cohortLabel,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  SizedBox(width: 64),
                  Expanded(
                      child: Text('내 자산',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text('코호트 평균',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(width: 54),
                ],
              ),
            ),
            row('현금성', myCash, avgCash),
            row('예·적금', mySaving, avgSaving),
          ],
        ),
      ),
    );
  }
}

class _BenchmarkSkeleton extends StatelessWidget {
  const _BenchmarkSkeleton();
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(height: 106, padding: const EdgeInsets.all(12)),
    );
  }
}

/* ---------- 추천 슬라이드 ---------- */

class _RecommendItem {
  final String title;
  final String caption;
  final int subscribers; // 가입자수
  final String emoji; // 심볼
  final List<Color> gradient;
  const _RecommendItem({
    required this.title,
    required this.caption,
    required this.subscribers,
    required this.emoji,
    required this.gradient,
  });
}

// 파스텔 톤 (블루와 조화)
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
        const Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 6),
              child: Text('실시간 추천 서비스',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170, // 🔧 카드 가시성 확보
          child: PageView.builder(
            controller: controller,
            itemCount: _kPastelCards.length,
            onPageChanged: onPageChanged,
            itemBuilder: (ctx, i) {
              final it = _kPastelCards[i];
              return LayoutBuilder(
                builder: (ctx, c) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child:
                        _RecommendCard(index: i, item: it, width: c.maxWidth),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // 인디케이터
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_kPastelCards.length, (i) {
            final active = (i == page);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? _kPrimary : Colors.black26,
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
  final double width;
  const _RecommendCard(
      {required this.index, required this.item, required this.width});

  @override
  Widget build(BuildContext context) {
    final rank = index + 1;
    return Card(
      elevation: 4,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: width,
        decoration:
            BoxDecoration(gradient: LinearGradient(colors: item.gradient)),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            // 랭크+이모지
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.3), shape: BoxShape.circle),
              child: Center(
                  child:
                      Text(item.emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            // 텍스트
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
                          color: Colors.white.withOpacity(.75),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 6),
                  Text('가입자수 ${_fmtSubs(item.subscribers)}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // CTA
            FilledButton.tonal(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.title} 상세로 이동 (데모)')),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(.82),
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

/* ---------- 마이메뉴 ---------- */

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
                  label: const Text('편집'),
                ),
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
                        Icon(m.icon, size: 26, color: _kPrimary),
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

/* ---------- 공통 카드/계좌 ---------- */

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
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
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
                if (trailing != null) ...[
                  const SizedBox(height: 4),
                  trailing!,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------- 아이콘/컬러/자산바 ---------- */

class _IconMeta {
  final IconData icon;
  final Color color;
  const _IconMeta(this.icon, this.color);
}

const _kPrimary = Color(0xFF2962FF); // 브랜드 블루
const _kCashSolid = _kPrimary; // 현금성
const _kSavingSolid = Color(0xFF80A4FF); // 예적금
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

            return Stack(
              children: [
                Container(height: height, color: _kTrack),
                Container(height: height, width: wCash, color: _kCashSolid),
                Positioned(
                    left: wCash,
                    child: Container(
                        height: height, width: wSaving, color: _kSavingSolid)),
              ],
            );
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

/* ---------- 데모 페이지 ---------- */

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
