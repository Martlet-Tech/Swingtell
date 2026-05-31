import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';

enum TtsEngineType { system, ai, premium }

class TtsSettingsSheet extends ConsumerStatefulWidget {
  /// Called immediately when speed or pitch changes, so the reader can apply.
  final void Function(double speed, double pitch)? onChanged;

  const TtsSettingsSheet({super.key, this.onChanged});

  /// Show as a modal bottom sheet. Returns when dismissed.
  static Future<void> show(BuildContext context, {void Function(double speed, double pitch)? onChanged}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TtsSettingsSheet(onChanged: onChanged),
    );
  }

  @override
  ConsumerState<TtsSettingsSheet> createState() => _TtsSettingsSheetState();
}

class _TtsSettingsSheetState extends ConsumerState<TtsSettingsSheet> {
  double _speed = 1.0;
  double _pitch = 1.0;
  TtsEngineType _engine = TtsEngineType.system;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    final speed = await settings.getSpeed();
    final pitch = await settings.getPitch();
    if (mounted) {
      setState(() {
        _speed = speed;
        _pitch = pitch;
      });
    }
  }

  Future<void> _saveSpeed(double v) async {
    final settings = ref.read(settingsServiceProvider);
    await settings.setSpeed(v);
    if (mounted) setState(() => _speed = v);
    widget.onChanged?.call(v, _pitch);
  }

  Future<void> _savePitch(double v) async {
    final settings = ref.read(settingsServiceProvider);
    await settings.setPitch(v);
    if (mounted) setState(() => _pitch = v);
    widget.onChanged?.call(_speed, v);
  }

  Future<void> _openSystemTtsSettings() async {
    try {
      await const MethodChannel('swingtell_tts').invokeMethod('openTtsSettings');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('朗读设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade200)),
            const SizedBox(height: 20),

            // Speed
            _buildSliderRow(
              icon: Icons.speed,
              label: '语速',
              value: _speed,
              min: 0.5,
              max: 3.0,
              divisions: 25,
              displayValue: '${_speed.toStringAsFixed(1)}x',
              onChanged: _saveSpeed,
            ),
            const SizedBox(height: 16),

            // Pitch
            _buildSliderRow(
              icon: Icons.music_note,
              label: '音调',
              value: _pitch,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              displayValue: _pitch.toStringAsFixed(1),
              onChanged: _savePitch,
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),

            // Engine selector
            Text('语音引擎', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
            const SizedBox(height: 8),
            _buildEngineTile(TtsEngineType.system, '系统 TTS', '使用手机内置文字转语音', true),
            _buildEngineTile(TtsEngineType.ai, 'AI API Key', '自备 OpenAI / Azure TTS Key', false),
            _buildEngineTile(TtsEngineType.premium, 'SwingTell 会员', '官方服务器高品质语音', false),

            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openSystemTtsSettings,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('系统 TTS 详细设置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey.shade300, fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 44, child: Text(displayValue, style: TextStyle(color: Colors.grey.shade400, fontSize: 13))),
      ],
    );
  }

  Widget _buildEngineTile(TtsEngineType engine, String title, String subtitle, bool available) {
    return RadioListTile<TtsEngineType>(
      value: engine,
      groupValue: _engine,
      title: Text(title, style: TextStyle(color: available ? null : Colors.grey.shade600)),
      subtitle: Text(
        available ? subtitle : '$subtitle — 即将推出',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      contentPadding: EdgeInsets.zero,
      dense: true,
      onChanged: available
          ? (v) {
              if (v != null) setState(() => _engine = v);
            }
          : null,
    );
  }
}
