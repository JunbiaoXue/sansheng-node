import 'dart:convert';
import 'package:shelf/shelf.dart';

Future<Response> cameraHandler(Request request) async {
  try {
    return Response.ok(
      jsonEncode({
        'success': false,
        'error': '相机功能需要真机测试',
        'note': '请在手机上安装后测试，模拟器不支持相机',
        'endpoints': {
          'method': 'GET',
          'path': '/camera',
          'returns': 'base64 encoded image',
        },
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
