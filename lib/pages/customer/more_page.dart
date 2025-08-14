// lib/pages/more_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:reframe/service/faq_api.dart';
import 'package:reframe/store/faq_store.dart';
import 'package:reframe/pages/customer/faq/faq_list_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    this.onStartChatbot,
    this.onOneToOne,
    this.onConnectAgent,
    this.onMyProfile,
    this.onMySettings,
  });

  final VoidCallback? onStartChatbot;
  final VoidCallback? onOneToOne;
  final VoidCallback? onConnectAgent;
  final VoidCallback? onMyProfile;
  final VoidCallback? onMySettings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 서버 주소만 환경에 맞게 수정하세요.
        Provider<FaqApi>(create: (_) => FaqApi(baseUrl: 'http://192.168.100.135:8090')),
        ChangeNotifierProvider<FaqStore>(
          create: (ctx) => FaqStore(api: ctx.read<FaqApi>()),
        ),
      ],
      // builder의 ctx는 Provider가 적용된 BuildContext 입니다.
      builder: (ctx, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.6,
            centerTitle: true,
            title: const Text(
              '임시',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.2,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 배너 탭 → /chat-debug (콜백이 있으면 콜백 우선)
                  _ChatBanner(
                    onTap: onStartChatbot ?? () => Navigator.of(ctx).pushNamed('/chat-debug'),
                  ),
                  const SizedBox(height: 22),

                  // 섹션: 고객센터
                  const _SectionTitle('고객센터'),
                  const SizedBox(height: 10),

                  // FAQ 목록으로 이동 (동일 인스턴스 전달 보장)
                  _MenuTile(
                    leading: const _EmojiCircle(child: Text('💬', style: TextStyle(fontSize: 25))),
                    title: '자주 묻는 질문',
                    onTap: () {
                      // 현재 스코프의 동일 인스턴스를 새 라우트에 주입
                      final api = ctx.read<FaqApi>();
                      final store = ctx.read<FaqStore>();

                      Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => MultiProvider(
                            providers: [
                              Provider<FaqApi>.value(value: api),
                              ChangeNotifierProvider<FaqStore>.value(value: store),
                            ],
                            child: const FaqListPage(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 15),

                  _MenuTile(
                    leading: const _EmojiCircle(
                      child: Text('1:1', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      bg: Color(0xFFEDEFF2),
                    ),
                    title: '1대1 문의',
                    onTap: onOneToOne,
                  ),
                  const SizedBox(height: 22),

                  // 섹션: 내 정보
                  const _SectionTitle('내 정보'),
                  const SizedBox(height: 10),

                  _MenuTile(
                    leading: const _EmojiCircle(child: Text('👤', style: TextStyle(fontSize: 25))),
                    title: '프로필 관리',
                    onTap: onMyProfile,
                  ),
                  const SizedBox(height: 12),

                  _MenuTile(
                    leading: const _EmojiCircle(child: Text('⚙️', style: TextStyle(fontSize: 25))),
                    title: '설정',
                    onTap: onMySettings,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }
}

class _ChatBanner extends StatelessWidget {
  const _ChatBanner({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        height: 86,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF151515), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(right: 60, bottom: 6, child: _Mascot()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _Pill(text: '궁금할 때 바로바로'),
                  SizedBox(height: 3),
                  Text(
                    '상담챗봇 시작하기',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.leading,
    required this.title,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          height: 85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiCircle extends StatelessWidget {
  const _EmojiCircle({required this.child, this.bg});
  final Widget child;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _Mascot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 에셋 경로는 프로젝트에 맞게 조정
    return Image.asset(
      'assets/images/mrb_desk.jpeg',
      width: 70,
      height: 70,
    );
    // 없으면 이모지 등으로 대체해도 됩니다.
    // return const Text('🤖', style: TextStyle(fontSize: 40));
  }
}
