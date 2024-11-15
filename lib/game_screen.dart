import 'package:flutter/material.dart';
import 'dice_display.dart';
import 'savegame.dart';
import 'scorecard.dart';
import 'bot.dart';

class GameScreen extends StatefulWidget {
  final List<Map<String, dynamic>> players;

  final SaveGame? loadedGame;

  const GameScreen({super.key, required this.players, this.loadedGame});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  List<int> dice = [0, 0, 0, 0, 0];
  List<bool> diceKept = [false, false, false, false, false];
  bool rolling = false;
  bool rolledOnce = false; // Tracks if dice have been rolled at least once
  int rollCount = 0; // Tracks the number of rolls for the player
  int currentPlayerIndex = 0; // Tracks the current player
  int currentRound = 1; // Tracks the current round (1 to 3)
  bool roundEnded = false; // Tracks if the round has ended
  bool botTurn = false; // Tracks if the bot is taking its turn
  List<Scorecard> scorecards = []; // Player scorecards
  Scorecard? selectedScorecard; // For viewing a selected player's scorecard
  List<String> actionLog = [];
  final ScrollController _scrollController = ScrollController();
  // Scroll controller for action log
  final GlobalKey<DiceDisplayState> diceDisplayKey =
      GlobalKey<DiceDisplayState>();

  @override
  void initState() {
    super.initState();
    
    if (widget.loadedGame != null) {
      // Initialize with loaded game state
      currentRound = widget.loadedGame!.currentRound;
      currentPlayerIndex = widget.loadedGame!.currentPlayerIndex;
      actionLog = List.from(widget.loadedGame!.actionLog);
      
      // Initialize scorecards with saved scores
      scorecards = widget.loadedGame!.players.map((playerState) {
        var scorecard = Scorecard(playerName: playerState.name);
        scorecard.scores = List.from(playerState.scores); // Copy saved scores
        scorecard.bonus = playerState.bonus; // Copy saved bonus
        return scorecard;
      }).toList();
    } else {
      scorecards = widget.players
          .map((player) => Scorecard(playerName: player['name']))
          .toList();
    }

    // Start the game by checking if the first player is a bot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.players[currentPlayerIndex]['isBot']) {
        handleBotTurn();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void onDiceChanged(List<int> newDice, List<bool> newDiceKept) {
    setState(() {
      dice = newDice;
      diceKept = newDiceKept;
      rolling = false;
      rolledOnce = true;
    });
  }

  void resetDice() {
    setState(() {
      diceKept = [false, false, false, false, false];
      dice = [0, 0, 0, 0, 0];
      rollCount = 0;
    });
    diceDisplayKey.currentState?.resetDice();
  }

  // Show the scorecard popup for the current player
  void showScoreTable() {
    if (botTurn) return; // Prevent opening scorecards during bot's turn

    showDialog(
      context: context,
      builder: (context) {
        return ScorecardWidget(
          scorecard: scorecards[currentPlayerIndex],
          currentRound: currentRound,
          currentDice: List.from(dice), // Pass a copy of current dice values
        );
      },
    ).then((confirmed) {
      // After score is selected, move to the next player or next round
      if (confirmed == true) {
        resetDice();

        if (allPlayersCompletedRound()) {
          showRoundSummary();
        } else {
          nextTurn();
        }
      }
    });
  }

  // Show the scorecard popup for a specific player
  void showPlayerScorecard(int playerIndex) {
    if (botTurn) return; // Prevent opening scorecards during bot's turn

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height, // Set maximum height to 50% of screen height
            ),
            child: ScorecardWidget(
              scorecard: scorecards[playerIndex],
              currentRound: currentRound,
              currentDice: List.from(dice),
              isDisplayOnly: true,
            ),
          ),
        );
      },
    );
  }

  // Check if all players have filled their scorecards for the current round
  bool allPlayersCompletedRound() {
    return scorecards.every((scorecard) {
      return scorecard.scores.length >= currentRound &&
          scorecard.scores[currentRound - 1].values
              .every((score) => score != null);
    });
  }

  // Show a summary at the end of the round
  void showRoundSummary() {
    setState(() {
      roundEnded = true;
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Round $currentRound Summary'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: scorecards.map((scorecard) {
              final roundBonus = scorecard.calculateBonus(currentRound - 1);
              final roundScore = scorecard.calculateRoundScore(currentRound - 1);
              final totalScore = scorecard.totalScore();
              return ListTile(
                title: Text(scorecard.playerName),
                subtitle: Text(
                  'Round Score: $roundScore\n'
                  '${roundBonus > 0 ? 'Round Bonus: $roundBonus\n' : ''}'
                  'Total Score: $totalScore',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (currentRound < 3) {
                  setState(() {
                    currentRound++; // Move to the next round
                    currentPlayerIndex = 0; // Reset to first player
                    roundEnded = false; // Reset round state
                    for (var scorecard in scorecards) {
                      scorecard.extendScores(); // Extend scores for the next round
                    }
                  });
                  // Start the next player's turn
                  nextTurn();
                } else {
                  // End game after 3 rounds
                  showFinalScores();
                }
              },
              child: Text(currentRound < 3 ? 'Next Round' : 'End Game'),
            ),
          ],
        );
      },
    );
  }

  // Show final scores at the end of the game
  void showFinalScores() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Final Scores'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: scorecards.map((scorecard) {
              int totalScore = scorecard.totalScore();
              return ListTile(
                title: Text(scorecard.playerName),
                subtitle: Text(
                  'Final Score: $totalScore\nBonus: ${scorecard.bonus}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Exit back to main menu
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void nextTurn() {
    setState(() {
      currentPlayerIndex = (currentPlayerIndex + 1) % widget.players.length;
      resetDice();
      actionLog.add(
          "It is now ${widget.players[currentPlayerIndex]['name']}'s turn.");
    });

    if (widget.players[currentPlayerIndex]['isBot']) {
      handleBotTurn();
    }
  }

  void skipEntry() {
    setState(() {
      scorecards[currentPlayerIndex].skipEntry(currentRound - 1);
    });
    resetDice();

    if (allPlayersCompletedRound()) {
      showRoundSummary();
    } else {
      nextTurn();
    }
  }

  void onDiceTapped(int index) {
    if (botTurn) return; // Prevent dice interaction during bot's turn
    setState(() {
      if (dice[index] > 0) {
        diceKept[index] = !diceKept[index];
      }
    });
  }

  // Handle bot's turn
  Future<void> handleBotTurn() async {
    if (!widget.players[currentPlayerIndex]['isBot']) return;

    setState(() {
      botTurn = true;
      resetDice(); // Reset the dice at the start of the bot's turn
    });

    BotDifficulty botDifficulty = _parseBotDifficulty(
        widget.players[currentPlayerIndex]['botDifficulty']);

    Bot bot = Bot(
      name: widget.players[currentPlayerIndex]['name'],
      difficulty: botDifficulty,
    );

    actionLog.add(
        'Bot ${bot.name} with difficulty ${bot.difficulty} is taking its turn.');

    Map<String, int?> currentScores =
        scorecards[currentPlayerIndex].scores[currentRound - 1];

    // Perform up to 3 rolls
    for (int i = 0; i < 3; i++) {
      if (rollCount >= 3) break;

      if (i > 0) { // Only decide dice to keep after the first roll
        // Decide which dice to keep
        diceKept = await bot.decideDiceToKeep(
            currentScores, dice, diceKept);
        setState(() {
          diceKept = diceKept;
        });
        actionLog.add('Bot ${bot.name} decided to keep dice: $diceKept');
      }

      actionLog.add('Bot ${bot.name} is rolling attempt ${i + 1}');
      setState(() {
        rolling = true;
      });

      // Roll only the dice that are not kept
      diceDisplayKey.currentState?.rollDice(keep: diceKept);
      await Future.delayed(const Duration(
          milliseconds: 1500)); // Wait for dice to stop rolling

      setState(() {
        rolling = false;
        // Update dice values from the diceDisplayKey
        dice = List.from(
            diceDisplayKey.currentState?.getDiceValues() ?? dice);
      });

      actionLog.add('Bot ${bot.name} rolled: $dice');

      bool shouldRoll = await bot.decideToRoll(
          currentScores, dice, diceKept, rollCount);

      if (!shouldRoll) {
        break;
      }
    }

    await Future.delayed(
        const Duration(milliseconds: 500)); // Delay to simulate thinking time

    // Decide which category to score
    String category = await bot.decideCategoryToScore(
        currentScores, dice);
    if (category == 'SkipEntry') {
      await Future.delayed(
          const Duration(milliseconds: 500)); // Delay to simulate thinking time
      skipEntry();
    } else {
      int categoryIndex =
          scorecards[currentPlayerIndex].categories.indexOf(category);
      int score = scorecards[currentPlayerIndex]
          .calculateScoreForCategory(dice, categoryIndex);

      actionLog.add(
          'Bot ${bot.name} decided to score in category $category with score $score');

      setState(() {
        scorecards[currentPlayerIndex]
            .updateScore(categoryIndex, currentRound - 1, score);
        botTurn = false;
      });
      await Future.delayed(const Duration(
          milliseconds: 1000)); // Delay to simulate thinking time
      resetDice();
      if (allPlayersCompletedRound()) {
        showRoundSummary();
      } else {
        nextTurn();
      }
    }

    // Scroll to the bottom of the action log
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    });
  }

  BotDifficulty _parseBotDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return BotDifficulty.easy;
      case 'medium':
        return BotDifficulty.medium;
      case 'hard':
        return BotDifficulty.hard;
      case 'ai':
        return BotDifficulty.ai;
      case 'openai':
        return BotDifficulty.openai;
      default:
        return BotDifficulty.hard;
    }
  }

  void saveCurrentGame() async {
    final saveGame = SaveGame(
      name: 'Game_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      currentRound: currentRound,
      currentPlayerIndex: currentPlayerIndex,
      players: scorecards.map((s) => PlayerState(
        name: s.playerName,
        isBot: widget.players[scorecards.indexOf(s)]['isBot'],
        botDifficulty: widget.players[scorecards.indexOf(s)]['botDifficulty'],
        scores: List.from(s.scores), // Create a deep copy of scores
        bonus: s.bonus,
      )).toList(),
      actionLog: List.from(actionLog),
    );
    
    await SaveGameManager.saveGame(saveGame);
  }

  @override
  Widget build(BuildContext context) {
    bool isBotTurn = widget.players[currentPlayerIndex]['isBot'];
    bool allDiceKept = diceKept.every((kept) => kept);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kniffel Game'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              saveCurrentGame();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Game saved!')),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar for displaying the scoreboard of all players
          Container(
            width: 200,
            color: Colors.grey[200],
            child: Column(
              children: [
                const Text(
                  'Scoreboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: scorecards.length,
                    itemBuilder: (context, index) {
                      final roundBonus = scorecards[index].calculateBonus(currentRound - 1);
                      final roundScore = scorecards[index].calculateRoundScore(currentRound - 1);
                      return ListTile(
                        title: Text(scorecards[index].playerName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Round: $roundScore${roundBonus > 0 ? ' (Bonus: $roundBonus)' : ''}'),
                            Text('Total Score: ${scorecards[index].totalScore()}'),
                          ],
                        ),
                        onTap: () => showPlayerScorecard(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DiceDisplay(
                  key: diceDisplayKey,
                  diceValues: dice,
                  diceKept: diceKept,
                  onDiceTapped: onDiceTapped,
                  enabled: !botTurn,
                ),
                const SizedBox(height: 20),
                Text(
                  isBotTurn
                      ? 'Bot: ${scorecards[currentPlayerIndex].playerName}'
                      : 'Player: ${scorecards[currentPlayerIndex].playerName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: rolling || rollCount == 0 || botTurn
                      ? null
                      : showScoreTable,
                  child: const Text('Add to Score'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: rolling || rollCount >= 3 || botTurn || allDiceKept
                      ? null
                      : () async {
                          setState(() {
                            rolling = true;
                            rollCount++;
                            rolledOnce = true;
                          });

                          diceDisplayKey.currentState?.rollDice(keep: diceKept);

                          await Future.delayed(
                              const Duration(milliseconds: 1500));

                          setState(() {
                            rolling = false;
                            dice = List.from(
                                diceDisplayKey.currentState?.getDiceValues() ??
                                    dice);
                          });
                        },
                  child: Text(
                    allDiceKept ? 'Release dice to roll' : 'Roll',
                  ),
                ),
              ],
            ),
          ),
          // Sidebar for displaying the player action log
          Container(
            width: 200,
            color: Colors.grey[200],
            child: Column(
              children: [
                const Text(
                  'Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: actionLog.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(actionLog[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
