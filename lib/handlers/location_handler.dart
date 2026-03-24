import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shelf/shelf.dart';

Future<Response> locationHandler(Request request) async {
  try {
    // 检查权限
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
      if (!status.isGranted) {
        return Response.internalServerError(
          body: jsonEncode({'error': '位置权限未授权'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    // 检查定位服务
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Response.internalServerError(
        body: jsonEncode({'error': '定位服务未开启'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // 获取位置
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );

    return Response.ok(
      jsonEncode({
        'success': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'altitude': position.altitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'timestamp': position.timestamp.toIso8601String(),
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
