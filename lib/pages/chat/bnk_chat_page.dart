import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

enum Sender { ai, user, system }
enum TtsState { playing, stopped }

class ChatMessage {
  final Sender sender;
  String text;
  final String? id; // for replacing loading message
  final DateTime timestamp; // ⏰ 시간 필드

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
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _consented = false;
  bool _sending = false;

  // Networking
  static const String _baseUrl = 'http://192.168.100.135:8090';
  static const String _apiPath = '/api/chat/memory';

  // Speech to Text
  late final stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;

  // Voice Mode
  bool _voiceMode = false; // 하단 이미지 버튼으로 토글되는 음성 모드

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
    await _tts.setSpeechRate(0.45); // 0.0 ~ 1.0
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // iOS에서 스피커로 기본 출력 (선택)
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker],
    );

    _tts.setStartHandler(() => setState(() => _ttsState = TtsState.playing));
    _tts.setCompletionHandler(() => setState(() => _ttsState = TtsState.stopped));
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

  // UI helpers
  void _showIntro() {
    _appendAi('안녕하세요! BNK 챗봇입니다. 무엇을 도와드릴까요?');
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
        text: '답변을 생성 중입니다...',
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Consent
  Future<void> _agree() async {
    setState(() => _consented = true);
    _appendAi('개인정보 수집에 동의하셨습니다', speak: true);
    _showIntro();
  }

  // Networking send
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
        body: jsonEncode(text), // JSON 문자열 literal
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
      final err = '⚠️ 오류 발생: $e';
      _replaceById(loadingId, err);
      await _speak('네트워크 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<bool> _ensureMicPermission() async {
    var status = await Permission.microphone.status;

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('마이크 권한이 영구적으로 거부되었습니다. 설정에서 허용해 주세요.'),
            action: SnackBarAction(
              label: '설정 열기',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
      return false;
    }

    final req = await Permission.microphone.request();
    return req.isGranted;
  }

  // Speech to Text (manual toggle)
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

  // Voice mode toggle (bottom-right image button)
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

  // Text to Speech
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f2f5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('BNK 챗봇', style: TextStyle(color: Color(0xffd7191f))),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xffd7191f)),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                    ],
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isAi = m.sender == Sender.ai;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
                          children: [
                            if (isAi) ...[
                              Padding(
                                padding: const EdgeInsets.only(right: 6, top: 0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.asset(
                                    'assets/images/mrb.png',
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isAi
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    constraints:
                                    const BoxConstraints(maxWidth: 360),
                                    decoration: BoxDecoration(
                                      color: isAi
                                          ? const Color(0xffe2e2e2)
                                          : const Color(0xffd7191f),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      m.text,
                                      style: TextStyle(
                                        color: isAi
                                            ? const Color(0xff333333)
                                            : Colors.white,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(m.timestamp), // ⏰ 시간 표시
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                constraints: const BoxConstraints(maxWidth: 500),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: _consented,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: !_consented
                              ? '동의 후 이용할 수 있습니다'
                              : (_voiceMode || _isListening
                              ? '듣는 중… 말한 뒤 전송을 누르세요'
                              : '말하거나 입력하세요'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _consented && !_sending ? _sendMessage : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffd7191f),
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('전송'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 하단 우측 음성 모드 버튼 + 라벨
          Positioned(
            right: 16,
            bottom: 90,
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
                        decoration: const BoxDecoration(shape: BoxShape.circle),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: Text(
                    '음성모드',
                    style: TextStyle(
                      fontSize: 12,
                      color: (_voiceMode || _isListening)
                          ? const Color(0xffd7191f)
                          : const Color(0xff666666),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 개인정보 동의 모달
          if (!_consented)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '개인정보 수집 및 이용 동의',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      const Text('챗봇 이용을 위해 개인정보 수집에 동의해 주세요.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _agree,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffd7191f),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                        child: const Text('동의합니다'),
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
