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

Future<Response> notificationListHandler(Request request) async {
  try {
    await _ensureInit();

    // 获取活动通知
    final notifications = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.getActiveNotifications();

    if (notifications == null || notifications.isEmpty) {
      return Response.ok(
        jsonEncode({
          'success': true,
          'count': 0,
          'notifications': [],
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final list = notifications.map((n) => {
      'id': n.id,
      'channelId': n.channelId,
      'title': n.title,
      'body': n.body,
    }).toList();

    return Response.ok(
      jsonEncode({
        'success': true,
        'count': list.length,
        'notifications': list,
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
