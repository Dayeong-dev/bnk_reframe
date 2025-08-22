// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:reframe/constants/number_format.dart';

// 필요 페이지들 직접 import (위젯 push용)
import 'package:reframe/event/pages/fortune_hub_page.dart';
import 'package:reframe/model/account.dart';
import 'package:reframe/pages/chat/bnk_chat_page.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/pages/savings_test/screens/start_screen.dart';
import 'package:reframe/pages/walk/step_debug_page.dart';
import 'package:reframe/service/account_service.dart';
// TODO: 저축성향/챗봇 페이지가 있다면 여기 import 해주세요.
// import 'package:reframe/pages/savings/savings_start_page.dart';
// import 'package:reframe/pages/chat/bnk_chat_page.dart';

import 'auth/splash_page.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricSupport();
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
      _showBiometricRegisterDialog();
    }
  }

  void _showBiometricRegisterDialog() {
    // showDialog(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     title: const Text("생체 인증 등록"),
    //     content: const Text("다음 로그인부터 생체 인증을 사용하시겠습니까?"),
    //     actions: [
    //       TextButton(
    //         onPressed: () {
    //           Navigator.pop(context);
    //         },
    //         child: const Text("아니요"),
    //       ),
    //       TextButton(
    //         onPressed: () async {
    //           Navigator.pop(context);
    //           final didAuthenticate = await _auth.authenticate(
    //             localizedReason: "생체 인증 등록",
    //           );
    //           if (!mounted) return;
    //           if (didAuthenticate) {
    //             await _secureStorage.write(
    //               key: 'biometricEnabled',
    //               value: 'true',
    //             );
    //             if (!mounted) return;
    //
    //             ScaffoldMessenger.of(context).showSnackBar(
    //               const SnackBar(content: Text("생체 인증이 등록되었습니다.")),
    //             );
    //           }
    //         },
    //         child: const Text("네"),
    //       ),
    //     ],
    //   ),
    // );
  }

  Future<void> _initSecureStorage() async {
    await _secureStorage.deleteAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Secure Storage를 지웠습니다.")));
  }

  // ✅ 탭 내부 네비게이터로 push (하단바 유지)
  Future<T?> _push<T>(Widget page) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Account>>(
          future: fetchAccounts(null),
          builder: (context, snapshot) {
            // 로딩
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            // 에러
            if (snapshot.hasError) {
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
                      Text(
                        '${snapshot.error}',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {}),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final data = snapshot.data ?? [];
            // 빈 상태
            if (data.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 40),
                      const SizedBox(height: 12),
                      const Text('등록된 계좌가 없습니다.'),
                      const SizedBox(height: 8),
                      Text(
                        '상품을 가입하거나 계좌를 추가해 보세요.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => _push(DepositMainPage()),
                        child: const Text('예·적금 보러가기'),
                      ),
                    ],
                  ),
                ),
              );
            }

            String _showTypeText(AccountType? type) {
              switch (type) {
                case AccountType.demand:
                  return '입출금';
                case AccountType.product:
                  return '상품계좌';
                default:
                  return '기타';
              }
            }

            // 리스트 렌더링
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: data.length,
              separatorBuilder: (context, items) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final account = data[idx];
                return _AccountCard(
                  title: account.accountName ?? 'BNK 부산은행 계좌',
                  subtitle: '${_showTypeText(account.accountType)} · ${account.accountNumber}',
                  balanceText: account.balance != null ? '${money.format(account.balance)} 원' : '- 원',
                  isDefault: (account.isDefault == 1 ?? false),
                  onTap: () {
                    // 필요 시 상세 페이지로 이동
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String balanceText;
  final bool isDefault;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _AccountCard({
    required this.title,
    required this.subtitle,
    required this.balanceText,
    this.isDefault = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final badge = isDefault
        ? Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '기본계좌',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    )
        : null;

    return Card(
      elevation: 0.8,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              // 텍스트
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          badge,
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 잔액 + 트레일링
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
      ),
    );
  }
}
