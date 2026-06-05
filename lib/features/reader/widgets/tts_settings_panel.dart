import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/reader_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/tts/tts_pipeline.dart';
import '../../../core/constants/app_constants.dart';

class TtsSettingsPanel extends StatelessWidget {
  const TtsSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final ttsPipeline = context.read<TtsPipeline>();
    final s = settingsService.settings;
    final theme = kColorThemes[s.colorThemeIndex];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: theme.barBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('TTS 朗读设置', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _SliderRow(
            label: '语速',
            value: s.ttsSpeechRate,
            divisions: 10,
            displayValue: '${(s.ttsSpeechRate * 100).toInt()}%',
            onChanged: (v) {
              ttsPipeline.updateVoiceSettings(rate: v);
              _updateSettings(settingsService, s, ttsSpeechRate: v);
            },
          ),
          const SizedBox(height: 8),
          _SliderRow(
            label: '语调',
            value: (s.ttsPitch - 0.5) / 1.5,
            divisions: 10,
            displayValue: '${s.ttsPitch.toStringAsFixed(1)}x',
            onChanged: (v) {
              final pitch = 0.5 + v * 1.5;
              ttsPipeline.updateVoiceSettings(pitch: pitch);
              _updateSettings(settingsService, s, ttsPitch: pitch);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('保持不息屏', style: TextStyle(fontSize: 14)),
              const Spacer(),
              Switch(
                value: s.keepScreenOn,
                onChanged: (v) {
                  _updateSettings(settingsService, s, keepScreenOn: v);
                },
              ),
            ],
          ),

          // ── 朗读模式选择 ──
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text('朗读模式', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: '本地 TTS',
                  subtitle: '系统引擎原样朗读',
                  selected: s.ttsCorrectionMode == TtsCorrectionMode.local,
                  onTap: () {
                    ttsPipeline.updateCorrectionMode(TtsCorrectionMode.local);
                    _updateSettings(settingsService, s,
                        ttsCorrectionMode: TtsCorrectionMode.local);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: 'AI 纠错',
                  subtitle: 'LLM 消多音字歧义',
                  selected: s.ttsCorrectionMode == TtsCorrectionMode.llm,
                  onTap: () {
                    ttsPipeline.updateCorrectionMode(TtsCorrectionMode.llm);
                    _updateSettings(settingsService, s,
                        ttsCorrectionMode: TtsCorrectionMode.llm);
                  },
                ),
              ),
            ],
          ),

          // ── LLM 参数（仅 AI 纠错模式显示）──
          if (s.ttsCorrectionMode == TtsCorrectionMode.llm) ...[
            const SizedBox(height: 16),
            const Text('LLM 参数',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _LLMParamSlider(
              label: '总缓冲字数',
              value: s.llmBufferChars.toDouble(),
              min: 500,
              max: 5000,
              step: 100,
              suffix: '字',
              onChanged: (v) {
                _updateSettings(settingsService, s, llmBufferChars: v.toInt());
              },
            ),
            const SizedBox(height: 8),
            _LLMParamSlider(
              label: '单次通讯字数',
              value: s.llmBatchChars.toDouble(),
              min: 200,
              max: 1500,
              step: 50,
              suffix: '字',
              hint: '越大单次 LLM 调用越慢但批次数少',
              onChanged: (v) {
                _updateSettings(settingsService, s, llmBatchChars: v.toInt());
              },
            ),
          ],
        ],
      ),
    );
  }

  void _updateSettings(SettingsService svc, ReaderSettings current,
      {double? ttsSpeechRate,
      double? ttsPitch,
      bool? keepScreenOn,
      TtsCorrectionMode? ttsCorrectionMode,
      int? llmBufferChars,
      int? llmBatchChars}) {
    svc.update(current.copyWith(
      ttsSpeechRate: ttsSpeechRate,
      ttsPitch: ttsPitch,
      keepScreenOn: keepScreenOn,
      ttsCorrectionMode: ttsCorrectionMode,
      llmBufferChars: llmBufferChars,
      llmBatchChars: llmBatchChars,
    ));
  }
}

// ── 基础滑块组件 ──

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Text(displayValue, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        Slider(
          value: value,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── 模式选择按钮组件 ──

class _ModeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withOpacity(0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? theme.colorScheme.primary : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── LLM 参数滑块组件 ──

class _LLMParamSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String suffix;
  final String? hint;
  final ValueChanged<double> onChanged;

  const _LLMParamSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.suffix,
    this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text('${value.toInt()}$suffix',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          onChanged: onChanged,
        ),
        if (hint != null)
          Text(hint!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
