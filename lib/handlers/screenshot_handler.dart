import 'dart:convert';
import 'package:shelf/shelf.dart';

Future<Response> screenshotHandler(Request request) async {
  try {
    return Response.ok(
      jsonEncode({
        'success': false,
        'error': '截图功能需要设备支持 MediaProjection API',
        'note': '请在手机上安装后测试，部分设备需要额外权限',
        'endpoints': {
          'method': 'GET',
          'path': '/screenshot',
          'returns': 'base64 encoded screenshot',
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
