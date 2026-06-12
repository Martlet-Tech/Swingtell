import 'package:flutter/material.dart';
import 'timeline_viewmodel.dart';

class TimelineSetupScreen extends StatefulWidget {
  final TimelineViewModel vm;
  const TimelineSetupScreen({super.key, required this.vm});

  @override
  State<TimelineSetupScreen> createState() => _TimelineSetupScreenState();
}

class _TimelineSetupScreenState extends State<TimelineSetupScreen> {
  DateTime? _historyDate;
  late TextEditingController _dateCtrl;

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _historyDate ?? DateTime(1949, 10, 1),
      firstDate: DateTime(1),
      lastDate: DateTime.now().subtract(const Duration(days: 1)),
      helpText: '选择一个历史日期作为世界线起点',
    );
    if (picked != null) {
      setState(() {
        _historyDate = picked;
        _dateCtrl.text =
            '${picked.year}年${picked.month}月${picked.day}日';
      });
    }
  }

  void _confirm() {
    if (_historyDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个历史日期')),
      );
      return;
    }
    widget.vm.setAnchor(DateTime.now(), _historyDate!);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final previewDate = _historyDate;
    return Scaffold(
      appBar: AppBar(title: const Text('设定世界线')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '选择一个历史日期，\n从今天起你将跟随这条时间线。',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          const Text(
            '历史起点日期',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _dateCtrl,
            readOnly: true,
            decoration: InputDecoration(
              hintText: '点击选择日期',
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onTap: _pickDate,
          ),
          if (previewDate != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '预览',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _previewRow('今天', _formatDate(DateTime.now())),
                  const SizedBox(height: 4),
                  _previewRow('对应历史上', _formatDate(previewDate)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('确认设定'),
              onPressed: _confirm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Row(
      children: [
        Text('$label：', style: const TextStyle(fontSize: 14)),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}年${dt.month}月${dt.day}日';
}
