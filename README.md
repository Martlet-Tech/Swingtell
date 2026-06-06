# SwingTell 阅读器

一个专注于 **中文 TTS（文字转语音）听书** 体验的跨平台 EPUB 电子书阅读器，集成 **AI 角色聊天** 与 **LLM 多音字校正** 能力。

## 功能特性

### 📖 EPUB 阅读
- 导入 `.epub` 文件，自动解析元数据（书名、作者、封面）
- HTML 章节在 WebView 中渲染，原生滚动体验
- 4 种护眼配色主题（暖纸 / 暗夜 / 绿荫 / 羊皮）
- 字体样式 / 字号自由调节
- 阅读进度自动保存（章节 + 字符偏移 + 百分比）
- 章节列表快速跳转

### 🔊 智能 TTS 听书
- **双引擎自动切换**：优先使用 `flutter_tts`，回退到平台原生 TTS（Android `TextToSpeech`）
- **TTS 选段播放**：点击任意位置，从可见段开始朗读
- **滚动跟随**：朗读时高亮当前句，自动滚动到可视区域
- **无感翻章**：当前章播完后自动加载下一章，不打断播放
- **播放控制**：播放 / 暂停 / 恢复，语速 / 音高调节
- **屏幕常亮**：听书时防止息屏

### 🤖 LLM 多音字校正
- 将文本发送到兼容 OpenAI 的 API，对中文多音字进行上下文消歧
- 使用同音替代字替换多音字，让 TTS 朗读更准确
- 环形缓冲区实现流式 LLM 请求与 TTS 播放的异步管道
- 支持「本地模式」（直读）与「LLM 校正模式」切换

### 💬 AI 角色聊天
- 创建自定义聊天角色（名称 + 系统提示词）
- 流式 SSE 对话，兼容 OpenAI API
- 角色 / 会话数据持久化存储
- **角色导入 / 导出**（`.echar` 格式，包含头像与聊天记录）

### ⚙️ 设置
- AI API 地址 / Key / 模型名配置
- 阅读主题、字体、TTS 参数全局保存

## 技术栈

| 层次 | 技术 |
|---|---|
| 语言 / 框架 | Dart 3.11+ / Flutter (Material 3) |
| 状态管理 | Provider + ChangeNotifier |
| EPUB 解析 | epubx |
| 内容渲染 | webview_flutter |
| 本地存储 | Hive (NoSQL) |
| TTS | flutter_tts + Android 原生 TTS (MethodChannel) |
| AI 聊天 | OpenAI 兼容 API (http streaming) |
| 文件选择 | file_picker |
| 屏幕常亮 | wakelock_plus |

## 项目结构

```
lib/
├── main.dart                  # 入口：服务初始化 + Provider 注入
├── app.dart                   # MaterialApp + 路由
├── core/
│   ├── constants/             # 颜色主题常量
│   ├── models/                # 数据模型（Book, ReadingProgress, ReaderSettings, Chat...）
│   └── services/
│       ├── storage_service.dart       # Hive 初始化 + 图书 CRUD
│       ├── progress_service.dart      # 阅读进度读写
│       ├── settings_service.dart      # 设置读写（ChangeNotifier）
│       ├── epub_service.dart          # EPUB 解析 / HTML 生成
│       ├── chat_service.dart          # OpenAI 流式聊天
│       ├── chat_storage_service.dart  # 角色 / 消息持久化 + .echar 导入导出
│       └── tts/
│           ├── tts_pipeline.dart           # TTS 接口抽象
│           ├── tts_pipeline_impl.dart      # 双引擎管线 + LLM 校正
│           ├── tts_text_corrector.dart     # 文本校正器抽象
│           ├── native_tts.dart             # Android 原生 TTS 桥接
│           ├── llm_correction_worker.dart  # LLM 多音字校正工作器
│           └── correction_ring_buffer.dart # 流式环形缓冲区
├── features/
│   ├── home/                  # 启动页（读书 / AI 聊天入口）
│   ├── bookshelf/             # 书架（网格展示 + 新增 / 删除）
│   ├── reader/                # 阅读器（WebView + 手势 + 顶部/底部栏 + TTS 控制面板）
│   ├── chat/                  # AI 聊天（角色列表 / 对话 / 角色编辑 / 导入导出）
│   └── settings/              # AI API 配置
└── shared/widgets/            # 通用组件（图书封面卡片）
```

## 快速开始

```bash
# 1. 获取依赖
flutter pub get

# 2. 代码生成（Hive TypeAdapter）
dart run build_runner build --delete-conflicting-outputs

# 3. 运行
flutter run

# 构建
flutter build apk        # Android
flutter build ios        # iOS
flutter build windows    # Windows
flutter build linux      # Linux
flutter build macos      # macOS
flutter build web        # Web
```

> **注意**：Android 11+ 上 `flutter_tts` 可能因包可见性限制无法发现 TTS 引擎，系统会自动回退到原生 TTS。

## 依赖

- `epubx` — EPUB 解析
- `webview_flutter` — 章节渲染
- `hive` / `hive_flutter` — 本地持久化
- `flutter_tts` — 跨平台 TTS
- `provider` — 状态管理
- `http` — AI API 请求
- `file_picker` — 导入图书 / 角色
- `wakelock_plus` — 屏幕常亮
- `share_plus` — 分享
- `image` — 封面 / 头像处理
- `archive` — `.echar` 角色包打包

## 许可证

MIT
