import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/reader_settings.dart';

class FontSettingsPopup extends StatefulWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  const FontSettingsPopup({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<FontSettingsPopup> createState() => _FontSettingsPopupState();
}

class _FontSettingsPopupState extends State<FontSettingsPopup> {
  late ReaderSettings _s;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
  }

  void _update(ReaderSettings updated) {
    setState(() => _s = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = kColorThemes[_s.colorThemeIndex];
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.barBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black.withValues(alpha: 0.26))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('字体设置', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          _FontFamilySelector(
            value: _s.fontFamily,
            onChanged: (v) => _update(_s.copyWith(fontFamily: v)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('字号', style: TextStyle(fontSize: 14)),
              const Spacer(),
              _SizeButton(
                icon: Icons.remove,
                onTap: _s.fontSize > 14
                    ? () => _update(_s.copyWith(fontSize: (_s.fontSize - 2).clamp(14, 24)))
                    : null,
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 28,
                child: Text(
                  '${_s.fontSize.toInt()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              _SizeButton(
                icon: Icons.add,
                onTap: _s.fontSize < 24
                    ? () => _update(_s.copyWith(fontSize: (_s.fontSize + 2).clamp(14, 24)))
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FontFamilySelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FontFamilySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _SegOption(label: '衬线', value: 'serif', selected: value == 'serif', onTap: onChanged),
          const SizedBox(width: 3),
          _SegOption(label: '无衬线', value: 'sans-serif', selected: value == 'sans-serif', onTap: onChanged),
          const SizedBox(width: 3),
          _SegOption(label: '等宽', value: 'monospace', selected: value == 'monospace', onTap: onChanged),
        ],
      ),
    );
  }
}

class _SegOption extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;

  const _SegOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [BoxShadow(blurRadius: 4, color: Colors.black.withValues(alpha: 0.08))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? Colors.black87 : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SizeButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: onTap == null ? Colors.grey.shade300 : Colors.black87),
        ),
      ),
    );
  }
}
