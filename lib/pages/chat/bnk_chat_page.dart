// lib/pages/chat/bnk_chat_page.dart
//
// ✅ 이번 수정 포인트(“모든 서비스” MorePage와 톤&무드 맞춤)
// 1) AppBar: MorePage와 동일한 화이트 톤, 블랙 타이틀/아이콘, 살짝 낮은 음영
// 2) 말풍선:
//    - AI: 연한 그레이(가독성 ↑), 둥근 18
//    - User: MorePage 배너 그라디언트(보라→블루)로 통일, 화이트 텍스트
// 3) 입력영역: 라운드 12, 내부 아이콘(mic/stop/mode), 전송 버튼 원형 그라디언트
// 4) 음성모드 FAB: 화이트 카드 + 약한 그림자(= MorePage 타일 느낌)
// 5) 동의모달: 화이트 카드 + 라운드 + 그림자(섹션 카드 톤)
// 6) 타임스탬프: 회색 600, 좌우 정렬 유지
// 7) 라우트 연동: MorePage의 '/chat-debug'로 진입하는 경우를 가정(아래 예시)
//
// 🔗 라우팅 예시
// routes: { '/chat-debug': (_) => const BnkChatPage(), }
//
// ⚠️ 네트워크: POST('$_baseUrl$_apiPath')에 body=jsonEncode(text) 그대로 유지
// ⚠️ 음성/STT: permission_handler + speech_to_text / TTS: flutter_tts 그대로 유지

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../constants/api_constants.dart';

enum Sender { ai, user, system }

enum TtsState { playing, stopped }

class ChatMessage {
  final Sender sender;
  String text;
  final String? id; // for replacing loading message
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.text,
    this.id,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class BnkChatPage extends StatefulWidget {
  const BnkChatPage({super.key});

  @override
  State<BnkChatPage> createState() => _BnkChatPageState();
}

class _BnkChatPageState extends State<BnkChatPage> {
  // ===== Palette (MorePage 배너와 톤 맞춤) =====
  static const _brandBlue = Color(0xFF2962FF);
  static const _brandPurple = Color(0xFF7C4DFF);
  static const _aiBubble = Color(0xFFEDEFF2); // 연그레이
  static const _bg = Color(0xFFF0F2F5); // 페이지 배경 (MorePage와 동일톤 계열)
  static const _card = Colors.white;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _consented = false;
  bool _sending = false;

  // Networking
  static const String _baseUrl = apiBaseUrl;
  static const String _apiPath = '/api/chat/memory';

  // Speech to Text
  late final stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;

  // Voice Mode
  bool _voiceMode = false;

  // Text to Speech
  final FlutterTts _tts = FlutterTts();
  TtsState _ttsState = TtsState.stopped;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    _speechAvailable = await _speech.initialize(
      onStatus: (s) => setState(() => _isListening = s == 'listening'),
      onError: (e) => debugPrint('STT error: $e'),
    );
    setState(() {});
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker],
    );
    _tts.setStartHandler(() => setState(() => _ttsState = TtsState.playing));
    _tts.setCompletionHandler(
        () => setState(() => _ttsState = TtsState.stopped));
    _tts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      setState(() => _ttsState = TtsState.stopped);
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ===== UI helpers =====
  void _showIntro() {
    _appendAi('안녕하세요! 무엇을 도와드릴까요?\n예) “가까운 지점 알려줘”, “적금 추천해줘”');
  }

  void _appendAi(String text, {bool speak = false}) {
    setState(() => _messages.add(ChatMessage(sender: Sender.ai, text: text)));
    _scrollToBottom();
    if (speak) _speak(text);
  }

  void _appendUser(String text) {
    setState(() => _messages.add(ChatMessage(sender: Sender.user, text: text)));
    _scrollToBottom();
  }

  String _addLoading() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _messages.add(ChatMessage(
        sender: Sender.ai,
        text: '답변을 생성 중입니다…',
        id: id,
      ));
    });
    _scrollToBottom();
    return id;
  }

  void _replaceById(String id, String newText) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      setState(() => _messages[idx].text = newText);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ===== Consent =====
  Future<void> _agree() async {
    setState(() => _consented = true);
    _appendAi('개인정보 수집에 동의하셨습니다', speak: true);
    _showIntro();
  }

  // ===== Networking =====
  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _appendUser(text);

    final loadingId = _addLoading();

    try {
      setState(() => _sending = true);
      final uri = Uri.parse('$_baseUrl$_apiPath');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(text), // 서버 스펙: raw JSON string
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _replaceById(loadingId, res.body);
        await _speak(res.body);
      } else {
        final err = '⚠️ 오류: ${res.statusCode} ${res.reasonPhrase}';
        _replaceById(loadingId, err);
        await _speak('오류가 발생했습니다. 다시 시도해 주세요.');
      }
    } catch (e) {
      final err = '⚠️ 네트워크 오류: $e';
      _replaceById(loadingId, err);
      await _speak('네트워크 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  // ===== STT / 권한 =====
  Future<bool> _ensureMicPermission() async {
    var status = await Permission.microphone.status;

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('마이크 권한이 영구적으로 거부되었습니다. 설정에서 허용해 주세요.'),
            action: SnackBarAction(label: '설정 열기', onPressed: openAppSettings),
          ),
        );
      }
      return false;
    }

    final req = await Permission.microphone.request();
    return req.isGranted;
  }

  Future<void> _toggleListening() async {
    if (!await _ensureMicPermission()) return;

    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 기기에서 음성 인식을 사용할 수 없습니다.')),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      final ok = await _speech.initialize(
        onStatus: (s) => setState(() => _isListening = s == 'listening'),
        onError: (e) => debugPrint('STT error: $e'),
      );
      if (!ok) return;

      await _speech.listen(
        localeId: 'ko_KR',
        listenMode: stt.ListenMode.confirmation,
        onResult: (r) {
          final recognized = r.recognizedWords;
          setState(() => _controller.text = recognized);
          // 자동 전송 원하면 아래 주석 해제
          // if (r.finalResult && recognized.trim().isNotEmpty) _sendMessage();
        },
      );
      setState(() => _isListening = true);
    }
  }

  // ===== Voice Mode =====
  Future<void> _toggleVoiceMode() async {
    if (!_consented) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('동의 후 이용할 수 있습니다')),
        );
      }
      return;
    }
    setState(() => _voiceMode = !_voiceMode);
    if (_voiceMode) {
      if (!_isListening) {
        await _toggleListening();
      }
    } else {
      if (_isListening) {
        await _speech.stop();
        setState(() => _isListening = false);
      }
    }
  }

  // ===== TTS =====
  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.setLanguage('ko-KR');
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _tts.stop();
      setState(() => _ttsState = TtsState.stopped);
    } catch (_) {}
  }

  String _formatTimestamp(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ===== UI Parts =====
  Widget _buildBubble(ChatMessage m) {
    final isAi = m.sender == Sender.ai;

    final userGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_brandPurple, _brandBlue], // MorePage 배너와 동일 계열
    );

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: isAi ? _aiBubble : null,
        gradient: isAi ? null : userGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        m.text,
        style: TextStyle(
          color: isAi ? const Color(0xFF1F2937) : Colors.white,
          height: 1.35,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
      ),
    );

    final avatar = isAi
        ? Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/mrb.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
          )
        : const SizedBox(width: 0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isAi) avatar,
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                bubble,
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(m.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final listening = _voiceMode || _isListening;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      constraints: const BoxConstraints(maxWidth: 520),
      child: Row(
        children: [
          // Mic / Stop
          InkWell(
            onTap: _consented ? _toggleListening : null,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Icon(
                listening ? Icons.stop_circle_outlined : Icons.mic_none,
                color: listening ? _brandBlue : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // TextField
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3)),
                ],
              ),
              child: TextField(
                controller: _controller,
                enabled: _consented,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: !_consented
                      ? '동의 후 이용할 수 있습니다'
                      : (listening ? '듣는 중… 말한 뒤 전송을 누르세요' : '메시지를 입력하세요'),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send
          InkWell(
            onTap: _consented && !_sending ? _sendMessage : null,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: _consented && !_sending
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_brandPurple, _brandBlue],
                      )
                    : null,
                color: _consented && !_sending ? null : Colors.grey,
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AppBar: MorePage 톤(화이트/블랙)
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.6,
        centerTitle: false,
        titleSpacing: 12,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          '상담챗봇',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _ttsState == TtsState.playing ? '읽기 중지' : '읽어주기',
            onPressed: () {
              if (_ttsState == TtsState.playing) {
                _stopSpeaking();
              } else if (_messages.isNotEmpty) {
                _speak(_messages.last.text);
              }
            },
            icon: Icon(
              _ttsState == TtsState.playing
                  ? Icons.volume_off
                  : Icons.volume_up,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 6),
              // 대화 카드
              Expanded(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildBubble(_messages[index]),
                  ),
                ),
              ),
              _buildInputBar(),
            ],
          ),

          // 음성 모드 카드형 FAB (MorePage 타일 톤)
          Positioned(
            right: 16,
            bottom: 96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _toggleVoiceMode,
                  child: AnimatedScale(
                    scale: _voiceMode || _isListening ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    child: Opacity(
                      opacity: _consented ? 1.0 : 0.4,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _card,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4)),
                          ],
                          border: Border.all(
                            color: (_voiceMode || _isListening)
                                ? _brandBlue
                                : const Color(0xFFE5E7EB),
                            width: 1.2,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/mrb_airpod_max.jpeg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6)
                    ],
                  ),
                  child: Text(
                    '음성모드',
                    style: TextStyle(
                      fontSize: 12,
                      color: (_voiceMode || _isListening)
                          ? _brandBlue
                          : const Color(0xFF666666),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 개인정보 동의 모달 (카드형)
          if (!_consented)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 12)
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '개인정보 수집 및 이용 동의',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '챗봇 이용을 위해 개인정보 수집에 동의해 주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF4B5563)),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _agree,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            backgroundColor: _brandBlue,
                          ),
                          child: const Text('동의합니다',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
