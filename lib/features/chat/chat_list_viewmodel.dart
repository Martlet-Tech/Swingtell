import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/chat_character.dart';
import '../../core/services/chat_storage_service.dart';

class ChatListViewModel extends ChangeNotifier {
  final ChatStorageService _storage;
  List<ChatCharacter> _characters = [];
  bool _loading = true;

  ChatListViewModel(this._storage);

  List<ChatCharacter> get characters => _characters;
  bool get isLoading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _characters = await _storage.loadAllCharacters();
    _loading = false;
    notifyListeners();
  }

  Future<String> createCharacter(String name, String systemPrompt) async {
    final id = const Uuid().v4();
    final char = ChatCharacter(
      id: id,
      name: name,
      systemPrompt: systemPrompt,
    );
    await _storage.saveCharacter(char);
    _characters.insert(0, char);
    notifyListeners();
    return id;
  }

  Future<void> updateCharacter(ChatCharacter updated) async {
    await _storage.saveCharacter(updated);
    final idx = _characters.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _characters[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteCharacter(String id) async {
    await _storage.deleteCharacter(id);
    _characters.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<File?> exportCharacter(String id) async {
    try {
      return await _storage.exportCharacter(id);
    } catch (e) {
      debugPrint('[Chat] 导出失败: $e');
      return null;
    }
  }

  Future<File?> exportAll() async {
    try {
      return await _storage.exportAllCharacters();
    } catch (e) {
      debugPrint('[Chat] 导出全部失败: $e');
      return null;
    }
  }

  Future<ChatCharacter?> importCharacter() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['echar'],
    );
    if (result == null || result.files.isEmpty) return null;
    final filePath = result.files.single.path;
    if (filePath == null) return null;
    try {
      final importResult = await _storage.importCharacter(filePath);
      if (!importResult.isExisting) {
        _characters.insert(0, importResult.character);
        notifyListeners();
      }
      return importResult.character;
    } catch (e) {
      debugPrint('[Chat] 导入失败: $e');
      return null;
    }
  }
}
