import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  final _gatewayController = TextEditingController(
    text: 'ws://118.145.117.25:7891',
  );
  bool _connected = false;
  String _status = '点击连接 Gateway';
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _pendingRequests = <String, Completer<Map<String, dynamic>>>{};

  // 设备信息
  final _deviceId = 'sansheng-node-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _connect() async {
    final gatewayUrl = _gatewayController.text.trim();
    if (gatewayUrl.isEmpty) {
      setState(() => _status = '请输入 Gateway 地址');
      return;
    }

    setState(() => _status = '正在连接...');

    try {
      // 连接 WebSocket
      _channel = WebSocketChannel.connect(Uri.parse(gatewayUrl));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          setState(() {
            _connected = false;
            _status = '连接错误: $error';
          });
        },
        onDone: () {
          setState(() {
            _connected = false;
            _status = '连接已断开';
          });
        },
      );

      // 等待连接完成
      await Future.delayed(const Duration(seconds: 2));

      if (_channel != null) {
        setState(() {
          _connected = true;
          _status = '已连接到 Gateway\n设备ID: $_deviceId';
        });
      }
    } catch (e) {
      setState(() => _status = '连接失败: $e');
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final type = data['type'] as String?;

      if (type == 'event') {
        final event = data['event'] as String?;
        if (event == 'connect.challenge') {
          _handleChallenge(data['payload']);
        }
      } else if (type == 'res') {
        final id = data['id'] as String?;
        if (id != null && _pendingRequests.containsKey(id)) {
          _pendingRequests[id]!.complete(data);
          _pendingRequests.remove(id);
        }
      } else if (type == 'invoke') {
        _handleInvoke(data);
      }
    } catch (e) {
      debugPrint('消息解析错误: $e');
    }
  }

  Future<void> _handleChallenge(Map<String, dynamic> payload) async {
    final nonce = payload['nonce'] as String;
    final timestamp = payload['ts'] as int;

    // 发送 connect 请求（作为 node）
    final requestId = _generateId();
    final connectRequest = {
      'type': 'req',
      'id': requestId,
      'method': 'connect',
      'params': {
        'minProtocol': 3,
        'maxProtocol': 3,
        'client': {
          'id': 'sansheng-node',
          'version': '1.0.0',
          'platform': 'android',
          'mode': 'node',
        },
        'role': 'node',
        'scopes': [],
        'caps': ['camera', 'location', 'notifications', 'tts', 'screen'],
        'commands': [
          'camera.snap',
          'location.get',
          'notifications.list',
          'notifications.send',
          'tts.speak',
          'screen.capture',
        ],
        'permissions': {
          'camera.capture': true,
          'location.get': true,
          'notifications.list': true,
          'notifications.send': true,
          'tts.speak': true,
          'screen.capture': true,
        },
        'auth': {'token': ''},  // 简化处理
        'locale': 'zh-CN',
        'userAgent': 'SanshengNode/1.0.0',
        'device': {
          'id': _deviceId,
        },
      },
    };

    _channel?.sink.add(jsonEncode(connectRequest));
  }

  Future<void> _handleInvoke(Map<String, dynamic> invoke) async {
    final id = invoke['id'] as String?;
    final command = invoke['command'] as String?;
    final args = invoke['args'] as Map<String, dynamic>? ?? {};

    try {
      String result;
      switch (command) {
        case 'camera.snap':
          result = await _handleCamera(args);
          break;
        case 'location.get':
          result = await _handleLocation(args);
          break;
        case 'notifications.list':
          result = await _handleNotificationsList(args);
          break;
        case 'notifications.send':
          result = await _handleNotificationSend(args);
          break;
        case 'tts.speak':
          result = await _handleTts(args);
          break;
        case 'screen.capture':
          result = await _handleScreenCapture(args);
          break;
        default:
          result = jsonEncode({'error': 'Unknown command: $command'});
      }

      // 发送响应
      final response = {
        'type': 'invoke-res',
        'id': id,
        'ok': true,
        'result': jsonDecode(result),
      };
      _channel?.sink.add(jsonEncode(response));
    } catch (e) {
      final response = {
        'type': 'invoke-res',
        'id': id,
        'ok': false,
        'error': e.toString(),
      };
      _channel?.sink.add(jsonEncode(response));
    }
  }

  Future<String> _handleCamera(Map<String, dynamic> args) async {
    // 相机处理（需要真机测试）
    return jsonEncode({'success': false, 'message': '相机功能需要真机测试'});
  }

  Future<String> _handleLocation(Map<String, dynamic> args) async {
    // 位置处理
    return jsonEncode({'success': false, 'message': 'GPS 功能需要真机测试'});
  }

  Future<String> _handleNotificationsList(Map<String, dynamic> args) async {
    return jsonEncode({'success': false, 'message': '通知功能需要真机测试'});
  }

  Future<String> _handleNotificationSend(Map<String, dynamic> args) async {
    return jsonEncode({'success': false, 'message': '通知功能需要真机测试'});
  }

  Future<String> _handleTts(Map<String, dynamic> args) async {
    return jsonEncode({'success': false, 'message': 'TTS 功能需要真机测试'});
  }

  Future<String> _handleScreenCapture(Map<String, dynamic> args) async {
    return jsonEncode({'success': false, 'message': '截图功能需要真机测试'});
  }

  void _disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    setState(() {
      _connected = false;
      _status = '已断开连接';
    });
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}';
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
            // Gateway 配置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔗 Gateway 地址',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _gatewayController,
                      decoration: const InputDecoration(
                        hintText: 'ws://118.145.117.25:7891',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('手机连接到太子所在服务器',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 连接状态
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _connected ? Colors.green.shade900 : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    _connected ? Icons.check_circle : Icons.circle_outlined,
                    size: 48,
                    color: _connected ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 连接/断开按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _connected ? null : _connect,
                    icon: const Icon(Icons.link),
                    label: const Text('连接'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _connected ? _disconnect : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('断开'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 可用功能
            const Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📋 支持的命令',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 12),
                      Text('camera.snap - 拍照'),
                      Text('location.get - 获取位置'),
                      Text('notifications.list - 通知列表'),
                      Text('notifications.send - 发送通知'),
                      Text('tts.speak - 文字转语音'),
                      Text('screen.capture - 屏幕截图'),
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
