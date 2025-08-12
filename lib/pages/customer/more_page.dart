import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    this.onStartChatbot,
    this.onFaq,
    this.onOneToOne,
    this.onConnectAgent,
    this.onMyProfile,
    this.onMySettings,
  });

  /// 네 라우팅에 맞게 콜백만 붙여줘
  final VoidCallback? onStartChatbot;
  final VoidCallback? onFaq;
  final VoidCallback? onOneToOne;
  final VoidCallback? onConnectAgent;

  // "내 정보" 섹션 예시 콜백 (원하면 쓰기)
  final VoidCallback? onMyProfile;
  final VoidCallback? onMySettings;

  @override
  Widget build(BuildContext context) {
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
              _ChatBanner(onTap: onStartChatbot),
              const SizedBox(height: 22),

              // 섹션: 고객센터
              const _SectionTitle('고객센터'),
              const SizedBox(height: 10),
              _MenuTile(
                leading: _EmojiCircle(
                  child: Text('💬', style: TextStyle(fontSize: 25)),
                ),
                title: '자주 묻는 질문',
                onTap: onFaq,
              ),
              const SizedBox(height: 15),
              _MenuTile(
                leading: _EmojiCircle(
                  child: Text('1:1', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  bg: const Color(0xFFEDEFF2),
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
            // 오른쪽 캐릭터(에셋이 있으면 그걸 쓰고, 없으면 이모지로)
            Positioned(
              right: 60,//이미지 위치
              bottom: 6,
              child: _Mascot(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 12),//상담챗봇 시작하기 글씨 위치
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '궁금할 때 바로바로',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
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
    // 에셋이 있으면 교체: Image.asset('assets/images/mrb.png', width: 48, height: 48)
    return Container(
      padding: const EdgeInsets.all(0),
      child: Image.asset(
        'assets/images/mrb_desk.jpeg',
        width: 70,
        height: 70,
      ),
    );
  }
}
