import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

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
  // 服务器地址列表（手机主动连接这些服务器获取命令）
  final _serverController = TextEditingController(
    text: 'http://118.145.117.25:7891',
  );
  
  bool _connected = false;
  String _status = '点击「连接」开始';
  String _lastResult = '';
  Timer? _pollTimer;
  final List<String> _logs = [];
  
  // 设备信息 - 使用固定ID方便测试
  final _deviceId = 'phone-001';

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _addLog(String msg) {
    final now = TimeOfDay.now();
    final time = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _logs.insert(0, '[$time] $msg');
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  Future<void> _startPolling() async {
    final server = _serverController.text.trim();
    if (server.isEmpty) {
      setState(() => _status = '请输入服务器地址');
      return;
    }

    setState(() => _status = '正在连接服务器...');
    _addLog('尝试连接: $server');

    // 测试服务器是否可达
    try {
      final testUrl = '$server/api/live-status';
      _addLog('测试: $testUrl');
      
      final response = await http.get(
        Uri.parse(testUrl),
      ).timeout(const Duration(seconds: 10));
      
      _addLog('响应状态: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        _connected = true;
        setState(() => _status = '✅ 已连接\n设备ID: $_deviceId');
        
        // 开始轮询命令
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          _pollCommands();
        });
        
        _addLog('✅ 连接成功，开始轮询');
      } else {
        setState(() => _status = '服务器响应异常: ${response.statusCode}');
        _addLog('❌ 服务器响应异常: ${response.statusCode}');
      }
    } catch (e, st) {
      _addLog('❌ 连接失败: $e');
      setState(() => _status = '连接失败: $e');
    }
  }

  Future<void> _stopPolling() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _connected = false;
    setState(() {
      _status = '点击「连接」开始';
    });
    _addLog('已断开连接');
  }

  Future<void> _pollCommands() async {
    if (!_connected) return;
    
    final server = _serverController.text.trim();
    try {
      final url = '$server/api/node/$_deviceId/poll';
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _addLog('DEBUG poll resp: \${response.body}');  // debug
        final cmdRaw = data['command'];
        _addLog('DEBUG cmdRaw: \$cmdRaw (\${cmdRaw.runtimeType})');  // debug
        if (cmdRaw != null) {
          // 支持两种格式：字符串或对象
          final command = cmdRaw is String ? cmdRaw : (cmdRaw as Map<String, dynamic>)['command'] as String? ?? '';
          final args = cmdRaw is Map<String, dynamic> ? (cmdRaw as Map<String, dynamic>)['args'] as Map<String, dynamic>? ?? <String, dynamic>{} : <String, dynamic>{};
          _addLog('📋 收到命令: \$command');
          final cmdId = 'cmd_\${DateTime.now().millisecondsSinceEpoch}';
          await _executeCommand({'command': command, 'args': args}, cmdId);
        }
        // else: 没有命令，安静轮询
      } else {
        _addLog('⚠️ poll失败: \${response.statusCode}');
      }
      }
    } catch (e) {
      _addLog('⚠️ poll异常: $e');
    }
  }

  Future<void> _executeCommand(Map<String, dynamic> cmd, String cmdId) async {
    final command = cmd['command'] as String?;
    final args = cmd['args'] as Map<String, dynamic>? ?? {};
    
    _addLog('⚡ 执行: $command');
    
    String result;
    try {
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
          result = jsonEncode({'success': false, 'message': 'Unknown command: $command'});
      }
      
      _addLog('✅ 执行完成: $result');
      await _reportResult(cmdId, result);
    } catch (e, st) {
      _addLog('❌ 执行异常: $e');
      await _reportResult(cmdId, jsonEncode({'success': false, 'error': e.toString()}));
    }
  }

  Future<void> _reportResult(String cmdId, String result) async {
    final server = _serverController.text.trim();
    try {
      final url = '$server/api/node/$_deviceId/result';
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': cmdId,
          'deviceId': _deviceId,
          'result': result,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));
      
      _addLog('📤 结果已上报');
      setState(() => _lastResult = result);
    } catch (e) {
      _addLog('⚠️ 上报失败: $e');
    }
  }

  Future<String> _handleCamera(Map<String, dynamic> args) async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (photo == null) {
        return jsonEncode({'success': false, 'message': '用户取消了拍照'});
      }
      
      // 读取图片bytes
      final bytes = await photo.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      return jsonEncode({
        'success': true,
        'message': '拍照成功',
        'filename': photo.name,
        'size': bytes.length,
        'base64': base64Image,
      });
    } catch (e) {
      return jsonEncode({'success': false, 'message': '拍照失败: $e'});
    }
  }

  Future<String> _handleLocation(Map<String, dynamic> args) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return jsonEncode({
        'success': true,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'altitude': pos.altitude,
        'speed': pos.speed,
        'timestamp': pos.timestamp.toIso8601String(),
      });
    } catch (e) {
      return jsonEncode({'success': false, 'message': '定位失败: $e'});
  }
    }

  Future<String> _handleNotificationsList(Map<String, dynamic> args) async {
    try {
      // 读取系统通知需要NotificationManager等
      // 这里返回占位信息
      return jsonEncode({'success': true, 'message': '通知读取开发中', 'notes': 'Android 13需要NOTIFICATION_POLICY_ACCESS权限'});
    } catch (e) {
      return jsonEncode({'success': false, 'message': '通知读取失败: $e'});
    }

  Future<String> _handleNotificationSend(Map<String, dynamic> args) async {
    try {
      const title = '三省六部通知';
      const body = args['text'] as String? ?? '测试消息';
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'sansheng_node', 'Node通知', channelDescription: '三省六部Node通知',
          importance: Importance.high, priority: Priority.high,
        ),
      );
      await FlutterLocalNotificationsPlugin().show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title, body, details,
      );
      return jsonEncode({'success': true, 'message': '通知已发送: $body'});
    } catch (e) {
      return jsonEncode({'success': false, 'message': '通知发送失败: $e'});
    }

  Future<String> _handleTts(Map<String, dynamic> args) async {
    try {
      final text = args['text'] as String? ?? '';
      if (text.isEmpty) return jsonEncode({'success': false, 'message': 'TTS text is empty'});
      await flutterTts.setLanguage('zh-CN');
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setVolume(1.0);
      await flutterTts.speak(text);
      return jsonEncode({'success': true, 'message': 'TTS播放成功: $text'});
    } catch (e) {
      return jsonEncode({'success': false, 'message': 'TTS播放失败: $e'});
    }

  Future<String> _handleScreenCapture(Map<String, dynamic> args) async {
    try {
      // 截图需要native实现，这里返回占位
      return jsonEncode({'success': false, 'message': '截图功能需要额外配置'});
    } catch (e) {
      return jsonEncode({'success': false, 'message': '截图失败: $e'});
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('三省六部 Node'),
        centerTitle: true,
        backgroundColor: Colors.indigo.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 服务器地址输入
            TextField(
              controller: _serverController,
              decoration: InputDecoration(
                labelText: '服务器地址',
                hintText: 'http://118.145.117.25:7891',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.cloud),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // 连接状态
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _connected ? Colors.green.shade900 : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    _connected ? Icons.cloud_done : Icons.cloud_off,
                    size: 40,
                    color: _connected ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 连接/断开按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _connected ? null : _startPolling,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('连接'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _connected ? _stopPolling : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('断开'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 最新结果
            if (_lastResult.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📋 最新执行结果:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_lastResult, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),

            // 日志
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📜 日志',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _logs.isEmpty
                            ? const Text('等待连接...', style: TextStyle(color: Colors.grey))
                            : ListView.builder(
                                itemCount: _logs.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      _logs[index],
                                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                    ),
                                  );
                                },
                              ),
                      ),
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
