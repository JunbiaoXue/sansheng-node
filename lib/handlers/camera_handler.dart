import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';

CameraController? _cameraController;
List<CameraDescription>? _cameras;

Future<void> _initCamera() async {
  if (_cameras == null) {
    _cameras = await availableCameras();
    if (_cameras!.isNotEmpty) {
      _cameraController = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
    }
  }
}

Future<Response> cameraHandler(Request request) async {
  try {
    await _initCamera();

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Response.internalServerError(
        body: jsonEncode({'error': '相机未初始化'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // 拍照
    final XFile image = await _cameraController!.takePicture();

    // 获取临时目录
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final savePath = '${dir.path}/camera_$timestamp.jpg';
    await File(image.path).copy(savePath);

    // 读取图片并转为 base64
    final bytes = await File(savePath).readAsBytes();
    final base64 = base64Encode(bytes);

    // 删除临时文件
    await File(savePath).delete();

    return Response.ok(
      jsonEncode({
        'success': true,
        'image': base64,
        'timestamp': timestamp,
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
