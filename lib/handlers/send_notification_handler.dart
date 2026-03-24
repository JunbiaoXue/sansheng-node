import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shelf/shelf.dart';

final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();
bool _notifInitialized = false;

Future<void> _ensureInit() async {
  if (!_notifInitialized) {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
    _notifInitialized = true;
  }
}

Future<Response> sendNotificationHandler(Request request) async {
  try {
    await _ensureInit();

    String body;
    try {
      body = await request.readAsString();
    } catch (_) {
      body = '';
    }

    String title = '来自三少六部';
    String message = '';
    try {
      final data = jsonDecode(body);
      title = data['title'] ?? title;
      message = data['message'] ?? '';
    } catch (_) {
      message = body;
    }

    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      '默认通知',
      channelDescription: '默认通知渠道',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      message,
      details,
    );

    return Response.ok(
      jsonEncode({
        'success': true,
        'message': '通知已发送',
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
