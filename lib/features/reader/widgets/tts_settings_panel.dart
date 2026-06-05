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
        ],
      ),
    );
  }

  void _updateSettings(SettingsService svc, ReaderSettings current,
      {double? ttsSpeechRate, double? ttsPitch, bool? keepScreenOn}) {
    svc.update(current.copyWith(
      ttsSpeechRate: ttsSpeechRate,
      ttsPitch: ttsPitch,
      keepScreenOn: keepScreenOn,
    ));
  }
}

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
