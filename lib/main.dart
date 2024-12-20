import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kniffle_game/ai_service.dart';
import 'game_screen.dart';
import 'bot.dart';
import 'package:http/http.dart' as http;
import 'savegame.dart';

Future<void> main() async {
  // Load environment variables
  await dotenv.load();

  // Ensure platform bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();  
  
  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide the AIService with a real HTTP client
    final aiService = AIService(httpClient: http.Client());

    return MaterialApp(
      title: 'Kniffel Game',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: PlayerSetupScreen(
        aiService: aiService,
      ),
    );
  }
}

class PlayerSetupScreen extends StatefulWidget {
  final SaveGame? loadedGame;
  final AIService aiService;
  
  const PlayerSetupScreen({super.key, this.loadedGame, required this.aiService});

  @override
  _PlayerSetupScreenState createState() => _PlayerSetupScreenState();
}

class _PlayerSetupScreenState extends State<PlayerSetupScreen> {
  int playerCount = 1; // Default to 1 player

  List<TextEditingController> controllers = [];
  List<bool> isBot = [];
  List<BotDifficulty> botDifficulties = [];

  bool isOpenAIAvailable = false;
  bool isAIAvailable = false;

  @override
  void initState() {
    super.initState();
    if (widget.loadedGame != null) {
      // Initialize with loaded game data
      playerCount = widget.loadedGame!.players.length;
      controllers = List.generate(
        playerCount,
        (i) => TextEditingController(text: widget.loadedGame!.players[i].name),
      );
      isBot = widget.loadedGame!.players.map((p) => p.isBot).toList();
      botDifficulties = widget.loadedGame!.players
          .map((p) => p.botDifficulty != null
              ? _parseBotDifficulty(p.botDifficulty!)
              : BotDifficulty.easy)
          .toList();
    } else {
      _checkAIAvailability().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
      _checkOpenAIAvailability().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
      controllers =
          List.generate(playerCount, (index) => TextEditingController());
      isBot = List.generate(playerCount, (index) => false);

      if (isOpenAIAvailable) {
        botDifficulties = List.generate(playerCount, (index) => BotDifficulty.openai);
      } else {
        botDifficulties = List.generate(playerCount, (index) => BotDifficulty.hard);
      }
    }
  }

  BotDifficulty _parseBotDifficulty(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return BotDifficulty.easy;
      case 'medium':
        return BotDifficulty.medium;
      case 'hard':
        return BotDifficulty.hard;
      case 'openai':
        return BotDifficulty.openai;
      case 'ai':
        return BotDifficulty.ai;
      default:
        return BotDifficulty.hard;
    }
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _checkOpenAIAvailability() async {
    bool availability = await widget.aiService.checkOpenAIAvailability();
    if (mounted) {
      setState(() {
        isOpenAIAvailable = availability;
      });
    }
  }

  Future<bool> _checkAIAvailability() async {
    bool availability = await widget.aiService.checkAIAvailability();
    if (mounted) {
      setState(() {
        isAIAvailable = availability;
      });
    }
    return availability;
  }

  void updatePlayerCount(int newCount) {
    setState(() {
      if (newCount > playerCount) {
        // Add new controllers and bot settings
        controllers.addAll(
          List.generate(
              newCount - playerCount, (index) => TextEditingController()),
        );
        isBot.addAll(List.generate(newCount - playerCount, (index) => false));
        botDifficulties.addAll(List.generate(
            newCount - playerCount, (index) => BotDifficulty.easy));
      } else if (newCount < playerCount) {
        // Remove excess controllers and bot settings
        controllers = controllers.sublist(0, newCount);
        isBot = isBot.sublist(0, newCount);
        botDifficulties = botDifficulties.sublist(0, newCount);
      }
      playerCount = newCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Players'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _showLoadGameDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            for (int index = 0; index < playerCount; index++)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controllers[index],
                      decoration: InputDecoration(
                          labelText: 'Player ${index + 1} Name'),
                    ),
                  ),
                  Checkbox(
                    value: isBot[index],
                    onChanged: (value) {
                      setState(() {
                        isBot[index] = value ?? false;
                      });
                    },
                  ),
                  if (isBot[index])
                    DropdownButton<BotDifficulty>(
                      value: botDifficulties[index],
                      items: BotDifficulty.values
                          .where((difficulty) {
                            if (!isAIAvailable &&
                                difficulty == BotDifficulty.ai) return false;
                            if (!isOpenAIAvailable &&
                                difficulty == BotDifficulty.openai) {
                              return false;
                            }
                            return true;
                          })
                          .map((difficulty) => DropdownMenuItem<BotDifficulty>(
                                value: difficulty,
                                child:
                                    Text(difficulty.toString().split('.').last),
                              ))
                          .toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            botDifficulties[index] = newValue;
                          });
                        }
                      },
                    ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (playerCount > 1) {
                      updatePlayerCount(playerCount - 1);
                    }
                  },
                  child: const Text('-'),
                ),
                Text('Players: $playerCount'),
                ElevatedButton(
                  onPressed: () {
                    updatePlayerCount(playerCount + 1);
                  },
                  child: const Text('+'),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          List<Map<String, dynamic>> players = [];
          for (int i = 0; i < playerCount; i++) {
            players.add({
              'name': controllers[i].text.isNotEmpty
                  ? controllers[i].text
                  : 'Player ${i + 1}',
              'isBot': isBot[i],
              'botDifficulty': botDifficulties[i].toString().split('.').last,
            });
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameScreen(players: players),
            ),
          );
        },
        child: const Icon(Icons.play_arrow_rounded),
      ),
    );
  }

  void _showLoadGameDialog() async {
    final saves = await SaveGameManager.listSaves();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Game'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: _uploadSaveFile,
                child: const Text('Upload Save File'),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: saves.length,
                  itemBuilder: (context, index) {
                    final save = saves[index];
                    return ListTile(
                      title: Text(save.name),
                      subtitle: Text('${save.timestamp}\n'
                          'Round ${save.currentRound} - ${save.players.length} Players'),
                      onTap: () => _loadSaveGame(save),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => SaveGameManager.downloadSave(save),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await SaveGameManager.deleteSave(save.name);
                              if (!mounted) return;
                              Navigator.pop(context);
                              _showLoadGameDialog();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadSaveFile() async {
    if (kIsWeb) {
      final input = html.FileUploadInputElement()..accept = '.kniffel';
      input.click();

      await input.onChange.first;
      if (input.files?.isEmpty ?? true) return;

      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      await reader.onLoad.first;
      final bytes = reader.result as Uint8List;
      _processSaveFile(bytes);
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kniffel'],
      );

      if (result != null) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          _processSaveFile(bytes);
        }
      }
    }
  }

  Future<void> _processSaveFile(Uint8List bytes) async {
    final save = await SaveGameManager.uploadSave(bytes);
    if (save != null) {
      if (!mounted) return;
      _loadSaveGame(save);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid save file')),
      );
    }
  }

  void _loadSaveGame(SaveGame save) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          players: save.players
              .map((p) => {
                    'name': p.name,
                    'isBot': p.isBot,
                    'botDifficulty': p.botDifficulty ?? 'easy',
                  })
              .toList(),
          loadedGame: save,
        ),
      ),
    );
  }
}
