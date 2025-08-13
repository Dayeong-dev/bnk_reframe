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
  ChatMessage({required this.sender, required this.text, this.id});
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
    // iOS/Android 공통 설정
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.45); // 0.0 ~ 1.0
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

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
    _appendAi("안녕하세요! BNK 챗봇입니다. 무엇을 도와드릴까요?");
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
        headers: { 'Content-Type': 'application/json' },
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

  // Speech to Text
  Future<void> _toggleListening() async {
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
      final available = await _speech.initialize(
        onStatus: (s) => setState(() => _isListening = s == 'listening'),
        onError: (e) => debugPrint('STT error: $e'),
      );
      if (!available) return;

      await _speech.listen(
        localeId: 'ko_KR',
        listenMode: stt.ListenMode.confirmation,
        onResult: (result) {
          final recognized = result.recognizedWords;
          setState(() => _controller.text = recognized);
          if (result.finalResult && recognized.trim().isNotEmpty) {
            // 자동 전송을 원하면 아래 주석을 해제하세요.
            // _sendMessage();
          }
        },
      );
      setState(() => _isListening = true);
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
        actions: [
          IconButton(
            tooltip: _ttsState == TtsState.playing ? '읽기 중지' : '다시 읽어주기',
            onPressed: () async {
              if (_ttsState == TtsState.playing) {
                await _stopSpeaking();
              } else {
                // 마지막 AI 메시지를 다시 읽어주기
                final lastAi = _messages.lastWhere(
                      (m) => m.sender == Sender.ai,
                  orElse: () => ChatMessage(sender: Sender.ai, text: ''),
                );
                await _speak(lastAi.text);
              }
            },
            icon: Icon(_ttsState == TtsState.playing ? Icons.stop_circle : Icons.volume_up),
          ),
        ],
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                constraints: const BoxConstraints(maxWidth: 360),
                                decoration: BoxDecoration(
                                  color: isAi ? const Color(0xffe2e2e2) : const Color(0xffd7191f),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  m.text,
                                  style: TextStyle(
                                    color: isAi ? const Color(0xff333333) : Colors.white,
                                    height: 1.35,
                                  ),
                                ),
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
                    IconButton(
                      onPressed: _consented ? _toggleListening : null,
                      tooltip: _isListening ? '듣는 중…' : '음성 입력',
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                      color: const Color(0xffd7191f),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: _consented,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: _consented ? '말하거나 입력하세요' : '동의 후 이용할 수 있습니다',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _consented && !_sending ? _sendMessage : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffd7191f),
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('전송'),
                    ),
                  ],
                ),
              ),
            ],
          ),

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
                      const Text('개인정보 수집 및 이용 동의', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      const Text('챗봇 이용을 위해 개인정보 수집에 동의해 주세요.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _agree,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffd7191f),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
