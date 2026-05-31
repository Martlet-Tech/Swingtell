# SwingTell / 斯温特尔

AI 听书 Android App — 读取本地 EPUB，设备 TTS 朗读。

## 构建环境

| 工具 | 版本 |
|------|------|
| Flutter | 3.41.7 (`v3.41.7-pinned` 分支) |
| Dart | 3.11.5 |
| Android SDK | 36 |
| Gradle | 8.x (wrapper 管理) |

**Flutter 路径**: `D:\Programs\flutter\`

**Android SDK**: `D:\Programs\Android_SDK\`

**代理**: Clash 127.0.0.1:7893，已配 `~/.bashrc` 和 `~/.gradle/gradle.properties`

### 构建命令

```bash
source ~/.bashrc
flutter run                    # 运行到已连接设备
flutter run -d <device_id>     # 指定设备
flutter build apk              # 打包 APK
```

### 开发目录结构

```
src_github/Swingtell/     ← git 仓库
  lib/
    models/               ← 数据模型
    providers/            ← Riverpod 状态管理
    services/             ← 业务逻辑（TTS、解析、存储）
    ui/                   ← 页面
      home/               ← 首页
      reader/             ← 阅读器
      settings/           ← 设置
    utils/                ← 常量、工具
books/                    ← 测试用 EPUB
```

## License

GPL-3.0
