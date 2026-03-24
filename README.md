# 三省六部 Node Controller

OpenClaw 安卓节点控制器 - 通过 HTTP API 控制您的安卓设备。

## 功能

- 📷 **拍照** - 获取相机图像
- 📍 **位置** - 获取 GPS 坐标
- 🔔 **通知** - 读取/发送系统通知
- 🔊 **TTS** - 文字转语音播放
- 📱 **截图** - 屏幕截图

## 安装

1. 从 [Releases](https://github.com/JunbiaoXue/sansheng-node/releases) 下载 APK
2. 安装到安卓手机
3. 启动应用，点击"启动服务"
4. 太子即可远程控制您的设备

## API 端点

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /status | 服务状态 |
| GET | /camera | 拍照 |
| GET | /location | 获取位置 |
| GET | /notifications | 通知列表 |
| POST | /notify | 发送通知 |
| POST | /tts | 文字转语音 |
| GET | /screenshot | 屏幕截图 |

## 构建

本项目使用 GitHub Actions 自动构建 APK。

```bash
# 本地构建
flutter pub get
flutter build apk --debug
```
