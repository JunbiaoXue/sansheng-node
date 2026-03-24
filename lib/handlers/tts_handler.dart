import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shelf/shelf.dart';

final FlutterTts _tts = FlutterTts();

Future<Response> ttsHandler(Request request) async {
  try {
    String body;
    try {
      body = await request.readAsString();
    } catch (_) {
      body = '';
    }

    String text;
    try {
      final data = jsonDecode(body);
      text = data['text'] ?? '';
    } catch (_) {
      text = body;
    }

    if (text.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'text is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // 配置 TTS
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // 播放
    await _tts.speak(text);

    return Response.ok(
      jsonEncode({
        'success': true,
        'text': text,
        'message': '正在播放',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
