import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html;

class SaveGame {
  final String name;
  final DateTime timestamp;
  final int currentRound;
  final int currentPlayerIndex;
  final List<PlayerState> players;
  final List<String> actionLog;

  SaveGame({
    required this.name,
    required this.timestamp,
    required this.currentRound,
    required this.currentPlayerIndex,
    required this.players,
    required this.actionLog,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'timestamp': timestamp.toIso8601String(),
        'currentRound': currentRound,
        'currentPlayerIndex': currentPlayerIndex,
        'players': players.map((p) => p.toJson()).toList(),
        'actionLog': actionLog,
      };

  factory SaveGame.fromJson(Map<String, dynamic> json) {
    return SaveGame(
      name: json['name'],
      timestamp: DateTime.parse(json['timestamp']),
      currentRound: json['currentRound'],
      currentPlayerIndex: json['currentPlayerIndex'],
      players: (json['players'] as List)
          .map((p) => PlayerState.fromJson(p))
          .toList(),
      actionLog: (json['actionLog'] as List).cast<String>(),
    );
  }
}

class PlayerState {
  final String name;
  final bool isBot;
  final String? botDifficulty;
  final List<Map<String, int?>> scores;
  final int bonus;

  PlayerState({
    required this.name,
    required this.isBot,
    this.botDifficulty,
    required this.scores,
    required this.bonus,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'isBot': isBot,
        'botDifficulty': botDifficulty,
        'scores': scores.map((scoreMap) => 
          scoreMap.map((key, value) => MapEntry(key, value))).toList(),
        'bonus': bonus,
      };

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    var scoresList = (json['scores'] as List).map((scoreMap) {
      Map<String, int?> convertedMap = {};
      (scoreMap as Map<String, dynamic>).forEach((key, value) {
        convertedMap[key] = value as int?;
      });
      return convertedMap;
    }).toList();

    return PlayerState(
      name: json['name'],
      isBot: json['isBot'],
      botDifficulty: json['botDifficulty'],
      scores: scoresList,
      bonus: json['bonus'] ?? 0,
    );
  }
}

class SaveGameManager {
  static const String savePrefix = 'kniffel_save_';

  static Future<void> saveGame(SaveGame saveGame) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = '$savePrefix${saveGame.name}';
      await prefs.setString(key, jsonEncode(saveGame.toJson()));
    } else {
      final dir = await _saveDir;
      final file = File(path.join(dir, '${saveGame.name}.json'));
      await file.writeAsString(jsonEncode(saveGame.toJson()));
    }
  }

  static Future<List<SaveGame>> listSaves() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final saves = <SaveGame>[];
      final keys = prefs.getKeys().where((key) => key.startsWith(savePrefix));
      
      for (final key in keys) {
        final content = prefs.getString(key);
        if (content != null) {
          saves.add(SaveGame.fromJson(jsonDecode(content)));
        }
      }
      return saves..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      final dir = await _saveDir;
      final directory = Directory(dir);
      if (!await directory.exists()) return [];

      final saves = <SaveGame>[];
      await for (final file in directory.list()) {
        if (file.path.endsWith('.json')) {
          final content = await File(file.path).readAsString();
          saves.add(SaveGame.fromJson(jsonDecode(content)));
        }
      }
      return saves..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
  }

  static Future<SaveGame?> loadGame(String name) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString('$savePrefix$name');
      if (content == null) return null;
      return SaveGame.fromJson(jsonDecode(content));
    } else {
      final dir = await _saveDir;
      final file = File(path.join(dir, '$name.json'));
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      return SaveGame.fromJson(jsonDecode(content));
    }
  }

  static Future<void> deleteSave(String name) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$savePrefix$name');
    } else {
      final dir = await _saveDir;
      final file = File(path.join(dir, '$name.json'));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<String> get _saveDir async {
    final dir = await getApplicationDocumentsDirectory();
    final saveDir = path.join(dir.path, 'kniffel_saves');
    await Directory(saveDir).create(recursive: true);
    return saveDir;
  }

  static Future<Uint8List> exportSave(SaveGame saveGame) async {
    final jsonData = saveGame.toJson();
    final jsonString = jsonEncode(jsonData);
    return utf8.encode(jsonString);
  }

  static Future<SaveGame> importSave(Uint8List bytes) async {
    final jsonString = utf8.decode(bytes);
    final jsonData = jsonDecode(jsonString);
    return SaveGame.fromJson(jsonData);
  }

  static Future<void> downloadSave(SaveGame saveGame) async {
    if (kIsWeb) {
      final bytes = await exportSave(saveGame);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement()
        ..href = url
        ..setAttribute('download', '${saveGame.name}.kniffel')
        ..style.display = 'none';
      
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } else {
      final bytes = await exportSave(saveGame);
      final directory = await getApplicationDocumentsDirectory();
      final downloadsPath = path.join(directory.path, 'Downloads');
      await Directory(downloadsPath).create(recursive: true);
      
      final file = File(path.join(downloadsPath, '${saveGame.name}.kniffel'));
      await file.writeAsBytes(bytes);
    }
  }

  static Future<SaveGame?> uploadSave(List<int> bytes) async {
    try {
      return await importSave(Uint8List.fromList(bytes));
    } catch (e) {
      print('Error importing save: $e');
      return null;
    }
  }
}
