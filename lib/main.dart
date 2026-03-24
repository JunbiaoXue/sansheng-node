import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  
  // 设备信息
  final _deviceId = 'sansheng-node-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPolling() async {
    final server = _serverController.text.trim();
    if (server.isEmpty) {
      setState(() => _status = '请输入服务器地址');
      return;
    }

    setState(() => _status = '正在连接服务器...');

    // 测试服务器是否可达
    try {
      final testUrl = '$server/api/live-status';
      final response = await http.get(
        Uri.parse(testUrl),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        _connected = true;
        setState(() => _status = '✅ 已连接到服务器\n设备ID: $_deviceId');
        
        // 开始轮询命令
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          _pollCommands();
        });
        
        _addLog('服务器连接成功');
      } else {
        setState(() => _status = '服务器响应异常: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _status = '连接失败: $e');
      _addLog('连接失败: $e');
    }
  }

  Future<void> _pollCommands() async {
    if (!_connected) return;
    
    final server = _serverController.text.trim();
    try {
      // 从服务器获取待执行的命令
      // 这个接口需要服务器配合实现
      final url = '$server/api/node/$_deviceId/poll';
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['command'] != null) {
          await _executeCommand(data['command'], data['id']);
        }
      }
    } catch (e) {
      // 轮询失败不影响连接状态
    }
  }

  Future<void> _executeCommand(Map<String, dynamic> cmd, String cmdId) async {
    final command = cmd['command'] as String?;
    final args = cmd['args'] as Map<String, dynamic>? ?? {};
    
    _addLog('执行命令: $command');
    
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
          result = jsonEncode({'success': false, 'message': 'Unknown command'});
      }
      
      // 上报结果给服务器
      await _reportResult(cmdId, result);
    } catch (e) {
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
      ).timeout(const Duration(seconds: 5));
      
      _addLog('结果已上报');
      setState(() => _lastResult = result);
    } catch (e) {
      _addLog('上报失败: $e');
    }
  }

  Future<String> _handleCamera(Map<String, dynamic> args) async {
    return jsonEncode({'success': false, 'message': '相机功能需要真机测试'});
  }

  Future<String> _handleLocation(Map<String, dynamic> args) async {
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

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _connected = false;
    setState(() => _status = '已停止连接');
    _addLog('连接已停止');
  }

  void _addLog(String msg) {
    final now = TimeOfDay.now();
    setState(() {
      _logs.insert(0, '[${now.hour}:${now.minute.toString().padLeft(2,'0')}] $msg');
      if (_logs.length > 10) _logs.removeLast();
    });
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
                    const Text('🖥️ 服务器地址',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _serverController,
                      decoration: const InputDecoration(
                        hintText: 'http://118.145.117.25:7891',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('手机主动连接服务器获取命令',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
              ),
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
            const Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📜 日志',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 8),
                      Text('等待连接...', style: TextStyle(color: Colors.grey)),
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
