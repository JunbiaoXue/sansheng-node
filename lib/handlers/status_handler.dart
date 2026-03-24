import 'dart:convert';
import 'package:shelf/shelf.dart';

Future<Response> statusHandler(Request request) async {
  return Response.ok(
    jsonEncode({
      'status': 'online',
      'name': 'Sansheng Node Controller',
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'capabilities': [
        'camera',
        'location',
        'notifications',
        'tts',
        'screenshot',
      ],
    }),
    headers: {'Content-Type': 'application/json'},
  );
}
