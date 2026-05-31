import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/app_logger.dart';
import '../../utils/constants.dart';
import 'tts_settings_sheet.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _buildSection('朗读'),
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: const Text('语音设置'),
            subtitle: const Text('语速、音调、语音引擎'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => TtsSettingsSheet.show(context),
          ),
          const Divider(indent: 72),
          _buildSection('调试'),
          _ShareLogTile(),
          const Divider(indent: 72),
          _buildSection('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            trailing: Text(
              'v${AppConstants.appVersion}',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShareLogTile extends StatefulWidget {
  @override
  State<_ShareLogTile> createState() => _ShareLogTileState();
}

class _ShareLogTileState extends State<_ShareLogTile> {
  bool _sharing = false;

  Future<void> _shareLogs() async {
    setState(() => _sharing = true);
    try {
      final path = AppLogger.instance.latestLogPath;
      if (path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无日志文件'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      final xFile = XFile(path);
      if (mounted) {
        await Share.shareXFiles([xFile], subject: 'SwingTell 运行日志');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.bug_report),
      title: const Text('分享运行日志'),
      subtitle: const Text('发送日志给开发者以排查问题'),
      trailing: _sharing
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.chevron_right),
      onTap: _sharing ? null : _shareLogs,
    );
  }
}
