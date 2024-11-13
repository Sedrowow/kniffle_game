// main.dart
import 'dart:async';

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
      _checkAIAvailability();
      _checkOpenAIAvailability();
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

  void _checkOpenAIAvailability() async {
    bool availability = await widget.aiService.checkOpenAIAvailability();
    if (mounted) {
      setState(() {
        isOpenAIAvailable = availability;
      });
    }
  }

  void _checkAIAvailability() async {
    bool availability = await widget.aiService.checkAIAvailability();
    if (mounted) {
      setState(() {
        isAIAvailable = availability;
      });
    }
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
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: saves.length,
            itemBuilder: (context, index) {
              final save = saves[index];
              return ListTile(
                title: Text(save.name),
                subtitle: Text('${save.timestamp}\n'
                    'Round ${save.currentRound} - ${save.players.length} Players'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GameScreen(
                        players: save.players
                            .map((p) => {
                                  'name': p.name,
                                  'isBot': p.isBot,
                                  'botDifficulty':
                                      p.botDifficulty ?? 'easy',
                                })
                            .toList(),
                        loadedGame: save,
                      ),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await SaveGameManager.deleteSave(save.name);
                    if (!mounted) return;
                    Navigator.pop(context);
                    _showLoadGameDialog();
                  },
                ),
              );
            },
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
}
