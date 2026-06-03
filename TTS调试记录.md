# TTS 调试记录

## 问题

Android 14+ 上 `flutter_tts` 报 `not bound to TTS engine`，`getEngines`/`getLanguages` 返回空列表。

## 根因

Android 11+ 的包可见性限制。`AndroidManifest.xml` 缺少 `<queries>` 声明时，`queryIntentServices` 无法发现 TTS 引擎，导致 `flutter_tts` 绑定失败。

## 修复

在 `android/app/src/main/AndroidManifest.xml` 的 `<queries>` 块中加入：

```xml
<intent>
    <action android:name="android.intent.action.TTS_SERVICE"/>
</intent>
```

## 架构（双路径）

```
init()
  ├─ flutter_tts.getEngines → 有引擎 → 用 flutter_tts
  └─ 空列表 → NativeTts (MethodChannel + TtsHelper.kt) → 用 Android TextToSpeech API
```

`NativeTts` + `TtsHelper.kt` 作为 fallback，覆盖 flutter_tts 无法绑定的场景（某些定制 ROM 等）。

## 验证

点击「测试 TTS 朗读」按钮，设备正常播放中文语音。日志出现 `[TTS] 使用 flutter_tts 引擎` 即表示成功。
