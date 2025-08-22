// lib/pages/chat/bnk_chat_page.dart
// BnkChatScreen — 전송버튼: 배경 없는 IconButton(suffixIcon), 말풍선/입력창 굴곡(14), 드래그 가능한 음성모드 FAB

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
  final String? id;
  final DateTime timestamp;
  ChatMessage({
    required this.sender,
    required this.text,
    this.id,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class BnkChatScreen extends StatefulWidget {
  const BnkChatScreen({super.key});
  @override
  State<BnkChatScreen> createState() => _BnkChatScreenState();
}

class _BnkChatScreenState extends State<BnkChatScreen> {
  // Palette
  static const _brandBlue = Color(0xFF2962FF);
  static const _brandPurple = Color(0xFF7C4DFF);
  static const _aiBubble = Color(0xFFEDEFF2);
  static const _card = Colors.white;

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _consented = false; // 동의 전에는 입력/전송 비활성
  bool _sending = false;

  // API
  static const String _baseUrl = apiBaseUrl;
  static const String _apiPath = '/api/chat/memory';

  // STT/TTS
  late final stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  final FlutterTts _tts = FlutterTts();
  TtsState _ttsState = TtsState.stopped;

  bool _voiceMode = false;

  // Draggable FAB pos
  double? _fabLeft;
  double? _fabTop;
  static const double _fabSize = 64;
  static const double _fabMargin = 16;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    // 전송 아이콘 활성/비활성 자동 업데이트용
    _controller.addListener(() => setState(() {}));
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
    _tts.setErrorHandler((_) => setState(() => _ttsState = TtsState.stopped));
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
    setState(() => _messages
        .add(ChatMessage(sender: Sender.ai, text: '답변을 생성 중입니다…', id: id)));
    _scrollToBottom();
    return id;
  }

  void _replaceById(String id, String newText) {
    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) setState(() => _messages[i].text = newText);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

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
        body: jsonEncode(text),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _replaceById(loadingId, res.body);
        await _speak(res.body);
      } else {
        _replaceById(loadingId, '⚠️ 오류: ${res.statusCode} ${res.reasonPhrase}');
        await _speak('오류가 발생했습니다. 다시 시도해 주세요.');
      }
    } catch (e) {
      _replaceById(loadingId, '⚠️ 네트워크 오류: $e');
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
        onResult: (r) => setState(() => _controller.text = r.recognizedWords),
      );
      setState(() => _isListening = true);
    }
  }

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
      if (!_isListening) await _toggleListening();
    } else {
      if (_isListening) {
        await _speech.stop();
        if (mounted) setState(() => _isListening = false);
      }
    }
  }

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

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ===== Bubbles =====
  Widget _buildBubble(ChatMessage m) {
    final isAi = m.sender == Sender.ai;
    final userGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7C4DFF), Color(0xFF2962FF)],
    );

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: isAi ? _aiBubble : null,
        gradient: isAi ? null : userGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
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
                Text(_time(m.timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== Inner Input Bar (전송버튼: 배경 없는 IconButton) =====
  Widget _buildInnerInputBar() {
    final listening = _voiceMode || _isListening;
    final canSend =
        _consented && !_sending && _controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: Row(
          children: [
            // Mic/Stop
            InkWell(
              onTap: _consented ? _toggleListening : null,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
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

            // TextField (+ 배경 없는 전송 아이콘)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
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
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: '메시지를 입력하세요',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                    // ← 배경 없는 전송 버튼
                    suffixIcon: IconButton(
                      tooltip: '전송',
                      splashRadius: 20,
                      onPressed: canSend ? _sendMessage : null,
                      icon: Icon(
                        Icons.send_rounded,
                        size: 22,
                        color: Color(0xFF2962FF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Draggable Voice FAB (기본 위치를 더 위로) =====
  Widget _buildDraggableVoiceFab(BoxConstraints cons) {
    final size = cons.biggest;
    final kb = MediaQuery.of(context).viewInsets.bottom;

    // 초기 위치: 우하단에서 입력창과 안 겹치게 220px 위로
    _fabLeft ??= size.width - _fabSize - _fabMargin;
    _fabTop ??= size.height - _fabSize - (kb > 0 ? kb : 0) - 185;

    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final minLeft = _fabMargin;
    final maxLeft = size.width - _fabSize - _fabMargin;
    final minTop = _fabMargin + kToolbarHeight;
    final maxTop = size.height - _fabSize - (kb > 0 ? kb : 0) - _fabMargin;

    return Positioned(
      left: clamp(_fabLeft!, minLeft, maxLeft),
      top: clamp(_fabTop!, minTop, maxTop),
      child: Opacity(
        opacity: _consented ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggleVoiceMode,
              onPanUpdate: (d) {
                setState(() {
                  _fabLeft = clamp(_fabLeft! + d.delta.dx, minLeft, maxLeft);
                  _fabTop = clamp(_fabTop! + d.delta.dy, minTop, maxTop);
                });
              },
              child: AnimatedScale(
                scale: _voiceMode || _isListening ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: _fabSize,
                  height: _fabSize,
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
                    child: Image.asset('assets/images/mrb_airpod_max.jpeg',
                        fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
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
      body: LayoutBuilder(
        builder: (_, cons) {
          return Stack(
            children: [
              // 카드(메시지 + 내부 입력바)
              Positioned.fill(
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                itemCount: _messages.length,
                                itemBuilder: (_, i) =>
                                    _buildBubble(_messages[i]),
                              ),
                            ),
                            _buildInnerInputBar(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 드래그 가능한 음성모드 FAB (기본 위치 상향)
              _buildDraggableVoiceFab(cons),

              // 개인정보 동의 모달
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
                          const Text('개인정보 수집 및 이용 동의',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
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
                              onPressed: () {
                                setState(() => _consented = true);
                                _appendAi('개인정보 수집에 동의하셨습니다', speak: true);
                                _appendAi(
                                    '안녕하세요! 무엇을 도와드릴까요?\n예) “가까운 지점 알려줘”, “적금 추천해줘”');
                              },
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
          );
        },
      ),
    );
  }
}
