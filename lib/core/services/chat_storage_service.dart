import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/chat_character.dart';
import '../models/chat_message.dart';

class ChatStorageService {
  Future<Directory> get _baseDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/characters');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _charDir(String characterId) async {
    final base = await _baseDir;
    final dir = Directory('${base.path}/$characterId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── 角色卡读写 ─────────────────────────────────

  Future<void> saveCharacter(ChatCharacter c) async {
    final dir = await _charDir(c.id);
    await File('${dir.path}/profile.json').writeAsString(jsonEncode(c.toJson()));
  }

  Future<ChatCharacter?> loadCharacter(String characterId) async {
    final dir = await _charDir(characterId);
    final file = File('${dir.path}/profile.json');
    if (!await file.exists()) return null;
    return ChatCharacter.fromJson(jsonDecode(await file.readAsString()));
  }

  Future<List<ChatCharacter>> loadAllCharacters() async {
    final base = await _baseDir;
    final entries = await base.list().toList();
    final result = <ChatCharacter>[];
    for (final entry in entries) {
      if (entry is Directory) {
        final file = File('${entry.path}/profile.json');
        if (await file.exists()) {
          result.add(ChatCharacter.fromJson(jsonDecode(await file.readAsString())));
        }
      }
    }
    result.sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
    return result;
  }

  Future<void> deleteCharacter(String characterId) async {
    final dir = await _charDir(characterId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ── 消息读写 ─────────────────────────────────

  Future<List<ChatMessage>> loadMessages(String characterId) async {
    final dir = await _charDir(characterId);
    final file = File('${dir.path}/messages.json');
    if (!await file.exists()) return [];
    final list = jsonDecode(await file.readAsString()) as List;
    return list.map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<void> appendMessage(String characterId, ChatMessage msg) async {
    final messages = await loadMessages(characterId);
    messages.add(msg);
    final dir = await _charDir(characterId);
    await File('${dir.path}/messages.json')
        .writeAsString(jsonEncode(messages.map((m) => m.toJson()).toList()));
  }

  Future<void> saveMessages(String characterId, List<ChatMessage> messages) async {
    final dir = await _charDir(characterId);
    await File('${dir.path}/messages.json')
        .writeAsString(jsonEncode(messages.map((m) => m.toJson()).toList()));
  }

  // ── 导出 ──────────────────────────────────────

  Future<File> exportCharacter(String characterId) async {
    final dir = await _charDir(characterId);
    final character = await loadCharacter(characterId);
    if (character == null) throw Exception('角色不存在');
    final base = await _baseDir;
    final zipPath = '${base.path}/${character.name}.echar';

    final archive = Archive();
    for (final f in ['profile.json', 'messages.json', 'avatar.jpg']) {
      final file = File('${dir.path}/$f');
      if (await file.exists()) {
        archive.addFile(ArchiveFile(f, await file.length(), await file.readAsBytes()));
      }
    }
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) throw Exception('压缩失败');
    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(zipData);
    return zipFile;
  }

  Future<File> exportAllCharacters() async {
    final base = await _baseDir;
    final archive = Archive();
    final entries = await base.list().toList();
    for (final entry in entries) {
      if (entry is Directory) {
        final charId = path.basename(entry.path);
        for (final f in ['profile.json', 'messages.json', 'avatar.jpg']) {
          final file = File('${entry.path}/$f');
          if (await file.exists()) {
            archive.addFile(ArchiveFile(
              '$charId/$f', await file.length(), await file.readAsBytes(),
            ));
          }
        }
      }
    }
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) throw Exception('压缩失败');
    final zipFile = File('${base.path}/all_characters.echar');
    await zipFile.writeAsBytes(zipData);
    return zipFile;
  }

  // ── 导入 ──────────────────────────────────────

  Future<ImportResult> importCharacter(String echarFilePath) async {
    final bytes = await File(echarFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    String? profileContent;
    for (final f in archive) {
      if (f.name == 'profile.json') {
        profileContent = f.content as String;
        break;
      }
    }
    if (profileContent == null) throw Exception('缺少 profile.json');
    final character = ChatCharacter.fromJson(jsonDecode(profileContent));

    final base = await _baseDir;
    final existingDir = Directory('${base.path}/${character.id}');
    final exists = await existingDir.exists();

    if (!exists) {
      await existingDir.create(recursive: true);
      for (final f in archive) {
        final fileName = path.basename(f.name);
        if (fileName == 'profile.json' || fileName == 'messages.json' || fileName == 'avatar.jpg') {
          await File('${existingDir.path}/$fileName').writeAsBytes(f.content as List<int>);
        }
      }
    }

    return ImportResult(character: character, isExisting: exists);
  }
}

class ImportResult {
  final ChatCharacter character;
  final bool isExisting;
  const ImportResult({required this.character, required this.isExisting});
}
