// lib/pages/home_page.dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:reframe/constants/number_format.dart';

// 모델/서비스/페이지
import 'package:reframe/model/account.dart';
import 'package:reframe/pages/account/account_detail_page.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBiometricSupport());
  }

  Future<void> _checkBiometricSupport() async {
    final canCheckBiometrics = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    final available = await _auth.getAvailableBiometrics();
    final alreadyEnabled = await _secureStorage.read(key: 'biometricEnabled');

    if (canCheckBiometrics && isSupported && available.isNotEmpty && alreadyEnabled == null) {
      // 필요 시 등록 다이얼로그 표시 (주석 처리)
    }
  }

  // 탭 내부 push
  Future<T?> _push<T>(Widget page) {
    return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BNK Reframe", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.settings, size: 20))],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Account>>(
          future: fetchAccounts(null),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(error: '${snapshot.error}', onRetry: () => setState(() {}));
            }
            final accounts = snapshot.data ?? [];

            // 기본계좌 (없어도 안전)
            Account? defaultAcc;
            for (final a in accounts) {
              if (a.isDefault == 1) { defaultAcc = a; break; }
            }

            // 상품 계좌 목록
            final productAccounts = accounts
                .where((a) => a.accountType == AccountType.product)
                .toList();

            // 자산 합계
            final cashTotal = accounts
                .where((a) => a.accountType == AccountType.demand)
                .fold<int>(0, (s, a) => s + (a.balance ?? 0));
            final savingTotal = accounts
                .where((a) => a.accountType == AccountType.product)
                .fold<int>(0, (s, a) => s + (a.balance ?? 0));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                if (defaultAcc != null)
                  _HeaderCard(
                    accountSubtitle: defaultAcc.accountNumber ?? '-',
                    balanceText: '${money.format(defaultAcc.balance ?? 0)} 원',
                    cash: cashTotal,
                    saving: savingTotal,
                    isDefault: (defaultAcc.isDefault == 1),
                    onDeposit: () => _push(DepositMainPage()),
                  )
                else
                  _EmptyDefaultHeader(onCreate: () => _push(DepositMainPage())),
                const SizedBox(height: 32),

                // 섹션: 가입한 상품
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('가입한 상품', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        '${productAccounts.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF556070),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: '새로고침',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (productAccounts.isEmpty)
                  _EmptyAccounts(onExplore: () => _push(DepositMainPage()))
                else
                  ...productAccounts.map(
                        (a) => _AccountCard(
                      title: a.accountName ?? 'BNK 부산은행 계좌',
                      subtitle: a.accountNumber ?? '-',
                      balanceText: '${money.format(a.balance ?? 0)} 원',
                      leading: _productBadgeIcon(a), // ← 추가
                      onTap: () {
                        if (a.accountType == AccountType.product) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AccountDetailPage(accountId: a.id)),
                          );
                        }
                      },
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

/// 기본계좌 헤더 카드
class _HeaderCard extends StatelessWidget {
  final String accountSubtitle; // 계좌번호
  final String balanceText;
  final int cash;     // 현금성 합계
  final int saving;   // 예·적금 합계
  final bool isDefault;
  final VoidCallback onDeposit;

  const _HeaderCard({
    required this.accountSubtitle,
    required this.balanceText,
    required this.cash,
    required this.saving,
    required this.isDefault,
    required this.onDeposit,
  });

  @override
  Widget build(BuildContext context) {
    final total = (cash + saving);

    final _balanceValue = int.tryParse(
      balanceText.replaceAll(RegExp(r'[^0-9]'), ''),
    ) ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      // decoration: BoxDecoration(
      //   color: Colors.white,
      //   borderRadius: BorderRadius.circular(20),
      //   boxShadow: [
      //     BoxShadow(
      //       color: Colors.grey.shade300,
      //       blurRadius: 10,
      //       offset: Offset(0, 0), // changes position of shadow
      //     ),
      //   ],
      // ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            accountSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              MoneyCountUp(
                value: _balanceValue,           // or: defaultAcc.balance ?? 0
                formatter: money,               // 너가 쓰는 NumberFormat
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                animateOnFirstBuild: true,      // 첫 진입 애니메이션 ON
                initialFrom: 0,                 // 0부터 시작
              ),
              const SizedBox(width: 6),
              Text(
                '원',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 130,
            height: 44,
            child: OutlinedButton(
              onPressed: onDeposit,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black54,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: Colors.grey.shade500),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded),
                  SizedBox(width: 2),
                  Text(
                      "예적금 만들기",
                      style: TextStyle(fontWeight: FontWeight.bold)
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Icon(Icons.monetization_on_rounded, size: 16, color: Colors.black38),
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
          const SizedBox(height: 10),
          _AssetLegend(cash: cash, saving: saving),
        ],
      ),
    );
  }
}

/// 기본계좌가 없을 때 상단 카드
class _EmptyDefaultHeader extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyDefaultHeader({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 10))],
        border: Border.all(color: const Color(0xFFF0F2F5)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/illustrations/empty-account.png',
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Color(0xFF93A0AF)),
            ),
          ),
          const SizedBox(height: 14),
          Text('기본 계좌가 없습니다.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            '지금 통장을 만들어 기본계좌로 설정해 보세요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text("통장 만들기"),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
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
          const Icon(Icons.account_balance_wallet_outlined, size: 40, color: Color(0xFF8B95A1)),
          const SizedBox(height: 10),
          const Text('계좌가 없습니다.'),
          const SizedBox(height: 4),
          Text('지금 통장을 만들어 시작해 보세요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280))),
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
            Text(error, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
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
  final Widget? leading; // ← 추가

  const _AccountCard({
    required this.title,
    required this.subtitle,
    required this.balanceText,
    this.onTap,
    this.trailing,
    this.leading, // ← 추가
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,                // ← 아이콘 배지
              const SizedBox(width: 12),
            ],
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.7)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 금액 + 트레일링
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

class _IconMeta {
  final IconData icon;
  final Color color;
  const _IconMeta(this.icon, this.color);
}

// 브랜드 컬러 재활용
const _kBlue   = _kCashGradEnd;   // 파랑
const _kRed    = _kSavingGradEnd; // 빨강 (#FE504F)
const _kGreen  = Color(0xFF10B981);
const _kIndigo = Color(0xFF4061F6);
const _kGray   = Color(0xFF6B7280);

_IconMeta _iconMetaForProduct(Account a) {
  // productType이 있으면 우선 사용, 없으면 accountName/number에서 추론
  final pt = (() {
    try {
      final v = a.productType; // 존재하면 사용
      if (v == null) return '';
      return v.toString();
    } catch (_) { return ''; }
  })();

  final hint = '${pt} ${a.accountName ?? ''}'.toLowerCase();

  // 걷기/헬스 기반 적금
  if (hint.contains('walk') || hint.contains('step') || hint.contains('health') || hint.contains('걷') || hint.contains('헬스')) {
    return _IconMeta(Icons.directions_walk_rounded, _kGreen);
  }
  // 적금(정기적금/자유적금)
  if (hint.contains('savings') || hint.contains('installment') || hint.contains('적금')) {
    return _IconMeta(Icons.savings_outlined, _kRed);
  }
  // 정기예금/예금
  if (hint.contains('deposit') || hint.contains('예금') || hint.contains('정기')) {
    return _IconMeta(Icons.account_balance_rounded, _kIndigo);
  }
  // 입출금/지급결제
  if (a.accountType == AccountType.demand || hint.contains('입출금') || hint.contains('checking')) {
    return _IconMeta(Icons.account_balance_wallet_outlined, _kBlue);
  }
  // 기본
  return _IconMeta(Icons.account_balance_outlined, _kGray);
}

// 실제로 카드 왼쪽에 그릴 배지
Widget _productBadgeIcon(Account a) {
  final m = _iconMetaForProduct(a);
  return Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: m.color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: Icon(m.icon, color: m.color, size: 22),
  );
}



// ===== 자산 구성 바 & 범례 (레드 톤) =====
const _kCashGradStart = Color(0xFF8CD3FF);
const _kCashGradEnd = Color(0xFF39B6FF);
const _kSavingGradStart = Color(0xFFFFA3A1); // 연한 레드
const _kSavingGradEnd = Color(0xFFFE504F);   // 지정 레드
const _kCashDot = _kCashGradEnd;
const _kSavingDot = _kSavingGradEnd;

class _AssetBreakdownBar extends StatelessWidget {
  final int cash;
  final int saving;
  final double height;
  final Duration duration;
  final Curve curve;

  /// 애니메이션 타임라인에서 파랑이 차지하는 구간(0~1)
  /// 예: 0.6이면 60% 시간 동안 파랑, 이후 40% 동안 빨강
  final double split;

  const _AssetBreakdownBar({
    super.key,
    required this.cash,
    required this.saving,
    this.height = 8,
    this.duration = const Duration(milliseconds: 1000),
    this.curve = Curves.easeOutCubic,
    this.split = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    final total = (cash + saving).toDouble();
    final cashRatio   = total == 0 ? 0.0 : cash   / total;
    final savingRatio = total == 0 ? 0.0 : saving / total;
    final safeSplit   = split.clamp(0.1, 0.9); // 너무 극단값 방지

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;

          // t: 0→1까지 한 번 애니메이션
          return TweenAnimationBuilder<double>(
            key: ValueKey('$cash-$saving'), // 값 바뀌면 다시 애니메이션
            tween: Tween(begin: 0, end: 1),
            duration: duration,
            curve: curve,
            builder: (context, t, _) {
              if (total == 0) {
                return Container(height: height, color: const Color(0xFFF0F3F7));
              }

              // 1) 파랑 구간: 0 ~ split
              final cashPhaseEnd   = safeSplit;
              final cashProgress   = (t <= cashPhaseEnd)
                  ? (t / cashPhaseEnd)              // 0→1로 보간
                  : 1.0;                             // 이후에는 고정

              // 2) 빨강 구간: split ~ 1
              final savingPhaseStart = safeSplit;
              final savingProgress   = (t <= savingPhaseStart)
                  ? 0.0
                  : ((t - savingPhaseStart) / (1 - savingPhaseStart));

              final wCash   = w * cashRatio   * cashProgress;
              final wSaving = w * savingRatio * savingProgress;

              return Stack(
                children: [
                  // 트랙
                  Container(height: height, color: Colors.grey.shade300),

                  // 파랑(현금성) 먼저 채움
                  Container(
                    height: height,
                    width: wCash,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [_kCashGradStart, _kCashGradEnd]),
                    ),
                  ),

                  // 그 다음 빨강(예·적금) 채움 — 파랑 끝에서부터
                  Positioned(
                    left: wCash,
                    child: Container(
                      height: height,
                      width: wSaving,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [_kSavingGradStart, _kSavingGradEnd]),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
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
        _LegendDot(color: _kCashDot),
        const SizedBox(width: 6),
        Text('현금성  ${money.format(cash)} 원', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(width: 16),
        _LegendDot(color: _kSavingDot),
        const SizedBox(width: 6),
        Text('예·적금  ${money.format(saving)} 원', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({super.key, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
