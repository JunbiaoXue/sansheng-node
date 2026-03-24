import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'handlers/camera_handler.dart';
import 'handlers/location_handler.dart';
import 'handlers/notification_handler.dart';
import 'handlers/screenshot_handler.dart';
import 'handlers/tts_handler.dart';
import 'handlers/send_notification_handler.dart';
import 'handlers/status_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SanshengNodeApp());
}

class SanshengNodeApp extends StatelessWidget {
  const SanshengNodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '三省六部 Node',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const NodeHomePage(),
    );
  }
}

class NodeHomePage extends StatefulWidget {
  const NodeHomePage({super.key});

  @override
  State<NodeHomePage> createState() => _NodeHomePageState();
}

class _NodeHomePageState extends State<NodeHomePage> {
  final _serverUrlController = TextEditingController(
    text: 'http://YOUR_SERVER:7892',
  );
  bool _serverRunning = false;
  String _status = '点击启动服务';
  HttpServer? _server;

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  Future<void> _startServer() async {
    final serverUrl = _serverUrlController.text.trim();
    if (serverUrl.isEmpty) {
      setState(() => _status = '请输入服务器地址');
      return;
    }

    try {
      final handler = Pipeline()
          .addMiddleware(logRequests())
          .addHandler(_createRouter());

      final port = 7892;
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

      setState(() {
        _serverRunning = true;
        _status = '服务已启动\n端口: $port\n手机IP: 请在设置中查看';
      });
    } catch (e) {
      setState(() => _status = '启动失败: $e');
    }
  }

  Future<void> _stopServer() async {
    await _server?.close();
    setState(() {
      _serverRunning = false;
      _status = '服务已停止';
    });
  }

  Handler _createRouter() {
    final router = Router();

    // 状态检查
    router.get('/status', statusHandler);

    // 拍照
    router.get('/camera', cameraHandler);

    // 获取位置
    router.get('/location', locationHandler);

    // 读取通知列表
    router.get('/notifications', notificationListHandler);

    // 发送通知
    router.post('/notify', sendNotificationHandler);

    // TTS 播放
    router.post('/tts', ttsHandler);

    // 截图
    router.get('/screenshot', screenshotHandler);

    // 健康检查
    router.get('/', (Request request) {
      return Response.ok(jsonEncode({
        'name': 'Sansheng Node Controller',
        'version': '1.0.0',
        'endpoints': [
          'GET /status - 服务状态',
          'GET /camera - 拍照',
          'GET /location - 获取位置',
          'GET /notifications - 通知列表',
          'POST /notify - 发送通知',
          'POST /tts - 文字转语音',
          'GET /screenshot - 屏幕截图',
        ],
      }), headers: {'Content-Type': 'application/json'});
    });

    return router;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📱 三省六部 Node'),
        centerTitle: true,
        backgroundColor: Colors.amber.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 服务器配置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔗 Gateway 服务器地址',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        hintText: 'http://118.145.117.25:7891',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('太子会通过这个地址连接您的手机',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 服务状态
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _serverRunning ? Colors.green.shade900 : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    _serverRunning ? Icons.check_circle : Icons.circle_outlined,
                    size: 48,
                    color: _serverRunning ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 启动/停止按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _serverRunning ? null : _startServer,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('启动服务'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _serverRunning ? _stopServer : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止服务'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 可用功能列表
            const Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📋 可用功能',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 12),
                      Text('GET  /status       - 服务状态'),
                      Text('GET  /camera      - 拍照'),
                      Text('GET  /location    - 获取位置'),
                      Text('GET  /notifications - 通知列表'),
                      Text('POST /notify      - 发送通知'),
                      Text('POST /tts         - 文字转语音'),
                      Text('GET  /screenshot  - 屏幕截图'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
