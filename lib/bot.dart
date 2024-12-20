// bot.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'scorecard.dart';

enum BotDifficulty { easy, medium, hard, ai, openai }

class Bot {
  // Ensure environment variables are loaded before creating an instance of Bot
  late final String? apiKey = dotenv.env['OPENAI_API_KEY'];
  final String name;
  final BotDifficulty difficulty;
  final Random _random = Random();
  final String? agentId; // For AI agents

  Bot({required this.name, required this.difficulty, this.agentId});

  // Decide which dice to keep based on difficulty

  Future<List<bool>> decideDiceToKeep(
      Map<String, int?> scores, List<int> dice, List<bool> diceKept) async {
    switch (difficulty) {
      case BotDifficulty.easy:

        // Easy: Randomly decide which dice to keep (previously medium logic)

        return List.generate(dice.length, (_) => _random.nextBool());

      case BotDifficulty.medium:

        // Medium: Previous hard logic (aim for best value)

        return _decideBestDiceToKeep(dice);

      case BotDifficulty.hard:

        // Hard: New strategic logic

        return _decideStrategicDiceToKeep(scores, dice);

      case BotDifficulty.ai:

        // AI: Use OLLAMA service to decide

        AIDecision decision = await _aiDecideToRoll(scores, dice, diceKept, 0);
        if (decision.rollAgain && decision.keptDice != null) {
          return decision.keptDice!;
        }
        
        return await _aiDecideDiceToKeep(scores, dice, diceKept);

      case BotDifficulty.openai:
        AIDecision decision = await _openaiDecideToRoll(scores, dice, diceKept, 0);
        if (decision.rollAgain && decision.keptDice != null) {
          return decision.keptDice!;
        }
        return await _openaiDecideDiceToKeep(scores, dice, diceKept);

      default:
        return List.generate(dice.length, (_) => false);
    }
  }

  // Decide if the bot should keep rolling or use the current dice
  Future<bool> decideToRoll(Map<String, int?> scores, List<int> dice,
      List<bool> diceToKeep, int rollCount) async {
    switch (difficulty) {
      case BotDifficulty.easy:
        // Easy: Randomly decide to roll or not
        return _random.nextBool();
      case BotDifficulty.medium:
        // Medium: Roll if the current score is not the highest possible
        return !_isHighestPossibleScore(scores, dice);
      case BotDifficulty.hard:
        // Hard: Roll if the current score is not the optimal score
        return !_isOptimalScore(scores, dice);
      case BotDifficulty.ai:
      case BotDifficulty.openai:
        // If all dice are false, it means the AI wants to score
        List<bool> decidedDice = await decideDiceToKeep(scores, dice, diceToKeep);
        if (decidedDice.every((kept) => !kept)) {
          return false; // Don't roll, proceed to scoring
        }
        return true; // Continue rolling with kept dice
      default:
        return true;
    }
  }

  // Decide the best category to score based on difficulty
  Future<String> decideCategoryToScore(
      Map<String, int?> scores, List<int> dice) async {
    List<String> availableCategories =
        scores.keys.where((key) => scores[key] == null).toList();
    if (availableCategories.isEmpty) {
      return scores
          .keys.first; // Fallback to the first category if none are available
    }

    switch (difficulty) {
      case BotDifficulty.easy:
        // Easy: Randomly choose a category
        availableCategories.shuffle();
        return availableCategories.first;
      case BotDifficulty.medium:
        return _decideBestCategoryToScore(scores, dice, availableCategories);
      case BotDifficulty.hard:
        // Medium and Hard: Choose the category with the highest potential score
        return _decideBestCategoryToScore(scores, dice, availableCategories);
      case BotDifficulty.ai:
        // AI: Use OLLAMA service to decide
        return await _aiDecideCategoryToScore(scores, dice);
      case BotDifficulty.openai:
        return await _openaiDecideCategoryToScore(scores, dice);
      default:
        return availableCategories.first;
    }
  }

  // AI methods to communicate with the OLLAMA service
  Future<List<bool>> _aiDecideDiceToKeep(
      Map<String, int?> scores, List<int> dice, List<bool> diceKept) async {
    String instructions = '''
You are a Yatzy AI bot deciding which dice to keep.

**Important Notes:**
- After specifying which dice to keep, they will be automatically rolled.
- Use ONLY numbers 1 to 5 to specify positions.
- DO NOT use words like 'dice', 'D', or 'area'.
- Separate multiple positions with commas only.
- To keep previously kept dice, include them in your new KeepDice command.
- After your decision, the non-kept dice will be automatically rolled.

Current values:
${_getDicePositionsString(dice)}
Currently kept positions: ${_getKeptDicePositions(diceKept)}

Available commands:
- KeepDice # (where # is position 1-5; for multiple positions use: KeepDice 1,2,3)
- EnterScore <Category>
- SkipEntry

VALID command examples:
- KeepDice 1,3,4
- KeepDice 2,5
- KeepDice 1

INVALID examples (DO NOT USE):
- KeepDice D1,D2
- KeepDice dice1,dice2
- KeepDice area 1
- Keep 1,2,3

Decide which positions to keep by using the KeepDice command exactly as shown in the valid examples.
''';

    print('\n=== OLLAMA Dice Keep Decision ===');
    print('Prompt:\n$instructions');

    // Rest of the method remains the same, just add print statements
    List<bool> newDiceKept = List.filled(diceKept.length, false);
    String response;
    int attempts = 0;

    do {
      response = await _sendToOLLAMA(instructions);
      print('AI Response (Attempt ${attempts + 1}):\n$response');

      if (response.toLowerCase().contains('enterscore')) {
        // If the AI wants to score, return empty array to signal this intent
        String category = _parseCategoryResponse(response, scores.keys.toList());
        if (category.isNotEmpty) {
          // Confirm the score entry
          instructions += '''
You chose to enter score for category "$category".
To confirm, please re-enter the command: EnterScore $category
''';
          response = await _sendToOLLAMA(instructions);
          print('AI Confirmation Response:\n$response');
          String confirmation = _parseCategoryResponse(response, scores.keys.toList());
          if (confirmation == category) {
            // Return empty array to signal scoring intent
            return List.filled(dice.length, false);
          }
        }
      }

      List<int> diceToKeep = _parseKeepDiceResponse(response, newDiceKept);

      if (diceToKeep.isEmpty) {
        // Invalid or no dice selected
        instructions += '''

The dice positions you selected are invalid. Please choose valid dice positions to keep.

Remember to use the commands exactly as provided.
''';
      } else {
        // Update diceKept based on the AI's choice
        for (int index in diceToKeep) {
          if (index >= 0 && index < newDiceKept.length && !newDiceKept[index]) {
            newDiceKept[index] = true;
          } else {
            // Invalid index or already kept
            instructions += '''

The dice position ${index + 1} is invalid. Please choose valid dice positions to keep.

Remember to use the commands exactly as provided.
''';
            break;
          }
        }
        // If all dice positions are valid, break the loop
        break;
      }

      attempts++;
    } while (attempts < 3);

    return newDiceKept;
  }

  Future<AIDecision> _aiDecideToRoll(Map<String, int?> scores, List<int> dice,
      List<bool> diceKept, int rollCount) async {
    List<String> availableCategories =
        scores.keys.where((key) => scores[key] == null).toList();
    List<String> validCategories = _getValidCategories(scores, dice);

    String instructions = '''
You are a Yatzy AI bot deciding your next action.

**Important Notes:**
- To roll again, use KeepDice to specify which dice to keep (including previously kept dice).
- After specifying dice to keep, remaining dice will automatically roll.
- If you want to score, use EnterScore with a category.
- Maximum 3 rolls per turn.

Current dice (position: value):
${_getDicePositionsString(dice)}
Currently kept positions: ${_getKeptDicePositions(diceKept)}
Roll count: $rollCount

**Available Categories:**
${availableCategories.join(', ')}

**Valid Categories:**
${validCategories.join(', ')}

Available commands:
- KeepDice #,#,# (to keep dice and roll again)
- EnterScore <Category>
- SkipEntry

Decide whether to keep dice and roll again, or proceed to scoring.
''';

    print('\n=== OLLAMA Roll Decision ===');
    print('Prompt:\n$instructions');

    String response;
    int attempts = 0;

    do {
      response = await _sendToOLLAMA(instructions);
      print('AI Response (Attempt ${attempts + 1}):\n$response');

      if (response.toLowerCase().contains('keepdice')) {
        List<int> diceToKeep = _parseKeepDiceResponse(response, diceKept);
        if (diceToKeep.isNotEmpty) {
          // Update the diceKept array based on the response
          for (int i = 0; i < diceKept.length; i++) {
            diceKept[i] = false;
          }
          for (int index in diceToKeep) {
            if (index >= 0 && index < diceKept.length) {
              diceKept[index] = true;
            }
          }
          // Remove rollCount increment as it's handled by game logic
          return AIDecision(rollAgain: true, keptDice: diceKept);
        }
      } else {
        var decision = _parseRollDecision(response);
        if (decision != null) {
          if (decision.categoryToScore != null || decision.skipEntry) {
            return decision;
          }
        }
      }

      attempts++;
    } while (attempts < 3);

    // After maximum attempts, default to skipping entry
    return AIDecision(rollAgain: false, skipEntry: true);
  }

  Future<String> _aiDecideCategoryToScore(
      Map<String, int?> scores, List<int> dice) async {
    List<String> availableCategories =
        scores.keys.where((key) => scores[key] == null).toList();
    List<String> validCategories = _getValidCategories(scores, dice);

    String instructions = '''
You are a Yatzy AI bot deciding which category to score.

**Important Notes:**
- Interactions must only use the commands exactly as provided.
- You can only choose from one of the available categories listed below.
- Categories where your current dice fulfill the requirements are marked as valid.

Your current dice are: ${dice.join(', ')}.

**Available Categories:**
${availableCategories.join(', ')}

**Valid Categories:**
${validCategories.join(', ')}

Available commands:
- EnterScore <Category>
- SkipEntry

Decide which single category to score or whether to skip and get no score by using the commands.
''';

    print('\n=== OLLAMA Category Score Decision ===');
    print('Prompt:\n$instructions');

    String response;
    String category;
    int attempts = 0;

    do {
      response = await _sendToOLLAMA(instructions);
      print('AI response: $response');

      category = _parseCategoryResponse(response, availableCategories);

      int score = _calculatePotentialScore(category, dice);

      if (!availableCategories.contains(category)) {
        // Invalid category
        instructions += '''

The category you selected ("$category") is not available. Please choose one valid category from the list.

Available Categories:
${availableCategories.join(', ')}

Remember to use the commands exactly as provided.
''';
      } else if (score == 0) {
        print('Score would be zero for category: $category');
        // Score is zero or invalid
        instructions += '''

You have chosen to enter a category where the score would be zero or your dice do not fulfill the requirements.

Please choose another single category from the valid categories.

Valid Categories:
${validCategories.join(', ')}

Remember to use the commands exactly as provided.
''';
      } else {
        // Inform AI of the score and ask for confirmation
        instructions += '''

You will enter the category "$category" with a score of $score.

To confirm, re-enter the command: EnterScore $category

If you want to choose a different category, please select from the valid categories.

Valid Categories:
${validCategories.join(', ')}
''';
        // Get confirmation
        response = await _sendToOLLAMA(instructions);
        print('AI response: $response');

        String confirmation =
            _parseCategoryResponse(response, availableCategories);

        if (confirmation == category) {
          return category; // Confirmed
        } else {
          // AI chose a different category, loop again
          category = confirmation;
          continue;
        }
      }

      attempts++;
    } while (attempts < 3);

    // Default to 'SkipEntry' after maximum attempts
    return 'SkipEntry';
  }

  // AI methods to communicate with the OpenAI service
  Future<List<bool>> _openaiDecideDiceToKeep(
      Map<String, int?> scores, List<int> dice, List<bool> diceKept) async {
    String instructions = '''
You are a Yatzy AI bot deciding which dice to keep.

**Important Notes:**
- After specifying which dice to keep, they will be automatically rolled.
- Use ONLY numbers 1 to 5 to specify positions.
- DO NOT use words like 'dice', 'D', or 'area'.
- Separate multiple positions with commas only.
- To keep previously kept dice, include them in your new KeepDice command.
- After your decision, the non-kept dice will be automatically rolled.

Current values:
${_getDicePositionsString(dice)}
Currently kept positions: ${_getKeptDicePositions(diceKept)}

Available commands:
- KeepDice # (where # is position 1-5; for multiple positions use: KeepDice 1,2,3)
- EnterScore <Category>
- SkipEntry

VALID command examples:
- KeepDice 1,3,4
- KeepDice 2,5
- KeepDice 1

INVALID examples (DO NOT USE):
- KeepDice D1,D2
- KeepDice dice1,dice2
- KeepDice area 1
- Keep 1,2,3

Decide which positions to keep by using the KeepDice command exactly as shown in the valid examples.
''';

    print('\n=== OpenAI Dice Keep Decision ===');
    print('Prompt:\n$instructions');

    // Rest of implementation with added print statements
    List<bool> newDiceKept = List.filled(diceKept.length, false);
    String response;
    int attempts = 0;

    do {
      response = await _sendToOpenAI(instructions);
      print('OpenAI response: $response');

      if (response.toLowerCase().contains('enterscore')) {
        // If the AI wants to score, return empty array to signal this intent
        String category = _parseCategoryResponse(response, scores.keys.toList());
        if (category.isNotEmpty) {
          // Confirm the score entry
          instructions += '''
You chose to enter score for category "$category".
To confirm, please re-enter the command: EnterScore $category
''';
          response = await _sendToOpenAI(instructions);
          print('OpenAI Confirmation Response:\n$response');
          String confirmation = _parseCategoryResponse(response, scores.keys.toList());
          if (confirmation == category) {
            // Return empty array to signal scoring intent
            return List.filled(dice.length, false);
          }
        }
      }

      List<int> diceToKeep = _parseKeepDiceResponse(response, newDiceKept);

      if (diceToKeep.isEmpty) {
        // Invalid or no dice selected
        instructions += '''

The dice positions you selected are invalid. Please choose valid dice positions to keep.

Remember to use the commands exactly as provided.
''';
      } else {
        // Update diceKept based on the AI's choice
        for (int index in diceToKeep) {
          if (index >= 0 && index < newDiceKept.length && !newDiceKept[index]) {
            newDiceKept[index] = true;
          } else {
            // Invalid index or already kept
            instructions += '''

The dice position ${index + 1} is invalid or already kept. Please choose valid dice positions to keep.

Remember to use the commands exactly as provided.
''';
            break;
          }
        }
        // If all dice positions are valid, break the loop
        break;
      }

      attempts++;
    } while (attempts < 3);

    return newDiceKept;
  }

  Future<AIDecision> _openaiDecideToRoll(Map<String, int?> scores,
      List<int> dice, List<bool> diceKept, int rollCount) async {
    List<String> availableCategories =
        scores.keys.where((key) => scores[key] == null).toList();
    List<String> validCategories = _getValidCategories(scores, dice);

    String instructions = '''
You are a Yatzy AI bot deciding your next action.

**Important Notes:**
- To roll again, use KeepDice to specify which dice to keep (including previously kept dice).
- After specifying dice to keep, remaining dice will automatically roll.
- If you want to score, use EnterScore with a category.
- Maximum 3 rolls per turn.

Current dice (position: value):
${_getDicePositionsString(dice)}
Currently kept positions: ${_getKeptDicePositions(diceKept)}
Roll count: $rollCount

**Available Categories:**
${availableCategories.join(', ')}

**Valid Categories:**
${validCategories.join(', ')}

Available commands:
- KeepDice #,#,# (to keep dice and roll again)
- EnterScore <Category>
- SkipEntry

Decide whether to keep dice and roll again, or proceed to scoring.
''';

    print('\n=== OpenAI Roll Decision ===');
    print('Prompt:\n$instructions');

    String response;
    int attempts = 0;

    do {
      response = await _sendToOpenAI(instructions);
      print('OpenAI Response (Attempt ${attempts + 1}):\n$response');

      if (response.toLowerCase().contains('keepdice')) {
        List<int> diceToKeep = _parseKeepDiceResponse(response, diceKept);
        if (diceToKeep.isNotEmpty) {
          // Update the diceKept array based on the response
          for (int i = 0; i < diceKept.length; i++) {
            diceKept[i] = false;
          }
          for (int index in diceToKeep) {
            if (index >= 0 && index < diceKept.length) {
              diceKept[index] = true;
            }
          }
          // Remove rollCount increment as it's handled by game logic
          return AIDecision(rollAgain: true, keptDice: diceKept);
        }
      } else {
        var decision = _parseRollDecision(response);
        if (decision != null) {
          if (decision.categoryToScore != null || decision.skipEntry) {
            return decision;
          }
        }
      }

      attempts++;
    } while (attempts < 3);

    // After maximum attempts, default to skipping entry
    return AIDecision(rollAgain: false, skipEntry: true);
  }

  Future<String> _openaiDecideCategoryToScore(
      Map<String, int?> scores, List<int> dice) async {
    List<String> availableCategories =
        scores.keys.where((key) => scores[key] == null).toList();
    List<String> validCategories = _getValidCategories(scores, dice);

    String instructions = '''
You are a Yatzy AI bot deciding which category to score.

**Important Notes:**
- Interactions must only use the commands exactly as provided.
- You can only choose from one of the available categories listed below.
- Categories where your current dice fulfill the requirements are marked as valid.

Your current dice are: ${dice.join(', ')}.

**Available Categories:**
${availableCategories.join(', ')}

**Valid Categories:**
${validCategories.join(', ')}

Available commands:
- EnterScore <Category>
- SkipEntry

Decide which one category to score or whether to skip by using the commands.
''';

    print('\n=== OpenAI Category Score Decision ===');
    print('Prompt:\n$instructions');

    String response;
    String category;
    int attempts = 0;

    do {
      response = await _sendToOpenAI(instructions);
      print('OpenAI response: $response');

      category = _parseCategoryResponse(response, availableCategories);

      int score = _calculatePotentialScore(category, dice);

      if (!availableCategories.contains(category)) {
        // Invalid category
        instructions += '''

The category you selected ("$category") is not available. Please choose a valid category from the list.

Available Categories:
${availableCategories.join(', ')}

Remember to use the commands exactly as provided.
''';
      } else if (score == 0) {
        print('Score would be zero for category: $category');
        // Score is zero or invalid
        instructions += '''

You have chosen to enter a category where the score would be zero or your dice do not fulfill the requirements.

Please choose another one category from the valid categories.

Valid Categories:
${validCategories.join(', ')}

Remember to use the commands exactly as provided.
''';
      } else {
        // Inform AI of the score and ask for confirmation
        instructions += '''

You will enter the category "$category" with a score of $score.

To confirm, re-enter the command: EnterScore $category

If you want to choose a different category, please select from the valid categories.

Valid Categories:
${validCategories.join(', ')}
''';
        // Get confirmation
        response = await _sendToOpenAI(instructions);
        print('OpenAI response: $response');

        String confirmation =
            _parseCategoryResponse(response, availableCategories);

        if (confirmation == category) {
          return category; // Confirmed
        } else {
          // AI chose a different category, loop again
          category = confirmation;
          continue;
        }
      }

      attempts++;
    } while (attempts < 3);

    // Default to 'SkipEntry' after maximum attempts
    return 'SkipEntry';
  }

  Future<String> _sendToOpenAI(String prompt) async {
    const String apiUrl = 'https://api.openai.com/v1/chat/completions';

    print('\n=== OpenAI API Request ===');
    print('Sending prompt to OpenAI API...');

    if (apiKey == null) {
      print('OpenAI API key is not set.');
      return '';
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo', // or 'gpt-4' if you have access
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 150,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String content = data['choices'][0]['message']['content'];
        print('OpenAI Response:\n$content');
        return content;
      } else {
        print('Failed to get response from OpenAI: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      print('Error communicating with OpenAI: $e');
      return '';
    }
  }

  List<String> _getValidCategories(Map<String, int?> scores, List<int> dice) {
    List<String> availableCategories =
        scores.keys.where((key) => scores[key] == null).toList();

    Scorecard tempScorecard = Scorecard(playerName: 'Temp');
    List<String> validCategories = [];

    for (String category in availableCategories) {
      int categoryIndex = tempScorecard.categories.indexOf(category);
      if (categoryIndex != -1) {
        bool isValid = tempScorecard.isValidForCategory(dice, categoryIndex);
        if (isValid) {
          validCategories.add(category);
        }
      }
    }

    return validCategories;
  }

  Future<String> _sendToOLLAMA(String prompt) async {
    // OLLAMA service endpoint
    String url = 'http://127.0.0.1:11434/api/generate';

    print('\n=== OLLAMA API Request ===');
    print('Sending prompt to OLLAMA API...');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model':
              'llama3.2', // Replace with your actual model name if different
          'prompt': prompt,
          'stream': false, // Set stream to false to get a single response
          'max_tokens': 150,
          'temperature': 0.2,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String content = data['response'] ?? '';
        print('OLLAMA Response:\n$content');
        return content;
      } else {
        print('Failed to get response from OLLAMA: ${response.statusCode}');
        throw Exception('Failed to get response from OLLAMA service.');
      }
    } catch (e) {
      print('Error communicating with OLLAMA service: $e');
      // Fallback to hard difficulty if AI service is not available
      return '';
    }
  }

List<int> _parseKeepDiceResponse(String response, List<bool> diceKept) {
  RegExp regex = RegExp(r'KeepDice\s+((?:\d+\s*,\s*)*\d+)');
  Match? match = regex.firstMatch(response);

  if (match != null) {
    List<int> indices = match
        .group(1)!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => int.parse(e) - 1)
        .toList();

    // Reset diceKept to no dice being kept
    for (int i = 0; i < diceKept.length; i++) {
      diceKept[i] = false;
    }

    // Update diceKept based on indices
    for (int index in indices) {
      if (index >= 0 && index < diceKept.length) {
        diceKept[index] = true;
      }
    }

    return indices;
  } else {
    // Handle invalid response
    return [];
  }
}
  AIDecision? _parseRollDecision(String response) {
    response = response.trim().toLowerCase();

    if (response.contains('skipentry')) {
      return AIDecision(rollAgain: false, skipEntry: true);
    } else {
      RegExp regex = RegExp(r'enterscore\s+(\w+)');
      Match? match = regex.firstMatch(response);
      if (match != null) {
        String category = match.group(1)!.trim();

        return AIDecision(rollAgain: false, categoryToScore: category);
      }
    }
    return null; // Invalid decision
  }

  String _parseCategoryResponse(
      String response, List<String> availableCategories) {
    RegExp regex = RegExp(r'EnterScore\s+(\w+)');
    Match? match = regex.firstMatch(response);

    if (match != null) {
      String category = match.group(1)!.trim();

      // Normalize the category string
      category = category.toLowerCase();

      // Find the best match from available categories
      for (String availableCategory in availableCategories) {
        if (availableCategory.toLowerCase() == category) {
          return availableCategory;
        }
      }
    }

    // If parsing fails or category not available, return empty string
    return '';
  }

  String _getKeptDicePositions(List<bool> diceKept) {
    List<int> positions = [];
    for (int i = 0; i < diceKept.length; i++) {
      if (diceKept[i]) positions.add(i + 1);
    }
    return positions.isNotEmpty ? positions.join(', ') : 'None';
  }

  String _getDicePositionsString(List<int> dice) {
    return dice.asMap()
        .entries
        .map((e) => 'Position ${e.key + 1}: ${e.value}')
        .join(', ');
  }

  Bot.namedConstructor(this.agentId,
      {required this.name, required this.difficulty});
}

class AIDecision {
  final bool rollAgain;
  final String? categoryToScore; // Non-null if AI chooses to enter a score
  final bool skipEntry;
  final List<bool>? keptDice;  // Add this field

  AIDecision({
    required this.rollAgain,
    this.categoryToScore,
    this.skipEntry = false,
    this.keptDice,  // Add this parameter
  });
}

// Check if the current score is the highest possible
bool _isHighestPossibleScore(Map<String, int?> scores, List<int> dice) {
  List<String> availableCategories =
      scores.keys.where((key) => scores[key] == null).toList();
  if (availableCategories.isEmpty) {
    return false; // No available categories to score
  }
  String bestCategory =
      _decideBestCategoryToScore(scores, dice, availableCategories);
  int bestScore = _calculatePotentialScore(bestCategory, dice);
  return bestScore ==
      50; // Example: 50 is the highest possible score for Yatzy
}

// Check if the current score is the optimal score
bool _isOptimalScore(Map<String, int?> scores, List<int> dice) {
  List<String> availableCategories =
      scores.keys.where((key) => scores[key] == null).toList();
  if (availableCategories.isEmpty) {
    return false; // No available categories to score
  }
  String bestCategory =
      _decideBestCategoryToScore(scores, dice, availableCategories);
  int bestScore = _calculatePotentialScore(bestCategory, dice);
  return bestScore >= 35; // Example: 35 is considered an optimal score
}

// Decide the best category to score for medium and hard difficulty
String _decideBestCategoryToScore(Map<String, int?> scores, List<int> dice,
    List<String> availableCategories) {
  if (availableCategories.isEmpty) {
    return scores
        .keys.first; // Fallback to the first category if none are available
  }

  // Example logic: Choose the category with the highest potential score
  Map<String, int> potentialScores = {};

  for (String category in availableCategories) {
    potentialScores[category] = _calculatePotentialScore(category, dice);
  }

  String bestCategory = availableCategories.first;
  int highestScore = potentialScores[bestCategory] ?? 0;

  for (String category in availableCategories) {
    if ((potentialScores[category] ?? 0) > highestScore) {
      bestCategory = category;
      highestScore = potentialScores[category] ?? 0;
    }
  }

  return bestCategory;
}

// Calculate potential score for a given category
int _calculatePotentialScore(String category, List<int> dice) {
  switch (category) {
    case 'chance':
      return dice.reduce((a, b) => a + b);
    case 'ones':
      return dice.where((die) => die == 1).length * 1;
    case 'twos':
      return dice.where((die) => die == 2).length * 2;
    case 'threes':
      return dice.where((die) => die == 3).length * 3;
    case 'fours':
      return dice.where((die) => die == 4).length * 4;
    case 'fives':
      return dice.where((die) => die == 5).length * 5;
    case 'sixes':
      return dice.where((die) => die == 6).length * 6;
    case 'threeOfAKind':
      return dice.any((die) => dice.where((d) => d == die).length >= 3)
          ? dice.reduce((a, b) => a + b)
          : 0;
    case 'fourOfAKind':
      return dice.any((die) => dice.where((d) => d == die).length >= 4)
          ? dice.reduce((a, b) => a + b)
          : 0;
    case 'fullHouse':
      Map<int, int> counts = {};
      for (var die in dice) {
        counts[die] = (counts[die] ?? 0) + 1;
      }
      bool hasThreeOfAKind = counts.values.contains(3);
      bool hasPair = counts.values.contains(2);
      return hasThreeOfAKind && hasPair ? 25 : 0;
    case 'smallStraight':
      return dice.toSet().length >= 4 ? 30 : 0;
    case 'largeStraight':
      return dice.toSet().length == 5 ? 40 : 0;
    case 'kniffel':
      return dice.toSet().length == 1 ? 50 : 0;
    default:
      return 0;
  }
}

// Decide the best category to score for hard difficulty
String _decideBestCategoryToScoreStrategic(Map<String, int?> scores, List<int> dice, List<String> availableCategories) {
  // Example logic: Choose the category with the highest potential score
  Map<String, int> potentialScores = {};

  for (String category in availableCategories) {
    potentialScores[category] = _calculatePotentialScore(category, dice);
  }

  String bestCategory = availableCategories.first;
  int highestScore = potentialScores[bestCategory] ?? 0;

  for (String category in availableCategories) {
    if ((potentialScores[category] ?? 0) > highestScore) {
      bestCategory = category;
      highestScore = potentialScores[category] ?? 0;
    }
  }

  return bestCategory;
}

// Decide the best dice to keep for hard difficulty
List<bool> _decideBestDiceToKeep(List<int> dice) {
  // Example logic: Keep the dice with the highest frequency
  Map<int, int> frequency = {};
  for (var die in dice) {
    frequency[die] = (frequency[die] ?? 0) + 1;
  }
  int maxFrequency = frequency.values.reduce(max);
  int targetValue =
      frequency.keys.firstWhere((key) => frequency[key] == maxFrequency);

  return dice.map((die) => die == targetValue).toList();
}

  // Add this new method for strategic dice keeping
  List<bool> _decideStrategicDiceToKeep(Map<String, int?> scores, List<int> dice) {
  List<bool> bestKeep = List.filled(dice.length, false);
  Map<int, int> frequency = {};
  for (var die in dice) {
    frequency[die] = (frequency[die] ?? 0) + 1;
  }

  var sortedUniqueDice = dice.toSet().toList()..sort();

  // First, evaluate high-value patterns
  if (frequency.values.any((count) => count >= 4)) {
    // Keep four of a kind
    int valueToKeep = frequency.entries
        .firstWhere((entry) => entry.value >= 4)
        .key;
    return dice.map((die) => die == valueToKeep).toList();
  } 
  
  if (_isYahtzeeInProgress(frequency)) {
    // Keep three or more of a kind if Kniffel is still available
    int valueToKeep = frequency.entries
        .firstWhere((entry) => entry.value >= 3)
        .key;
    return dice.map((die) => die == valueToKeep).toList();
  }
  
  if (_isFullHouseInProgress(frequency)) {
    // Keep dice that contribute to full house
    return _keepFullHouseDice(dice, frequency);
  }

  if (_isLargeStraightPossible(sortedUniqueDice)) {
    // Keep dice that could form a large straight
    return _keepStraightDice(dice, true);
  }
  
  if (_isSmallStraightPossible(sortedUniqueDice)) {
    // Keep dice that could form a small straight
    return _keepStraightDice(dice, false);
  }

  // If nothing special, focus on upper section scoring
  int bestValue = _findBestUpperSectionValue(scores, frequency);
  if (bestValue > 0) {
    // Keep only the dice with the best value for upper section
    for (int i = 0; i < dice.length; i++) {
      if (dice[i] == bestValue) {
        bestKeep[i] = true;
      }
    }
    return bestKeep;
  }

  // If no clear strategy, keep highest frequency dice
  if (frequency.isNotEmpty) {
    var maxFreq = frequency.values.reduce((a, b) => a > b ? a : b);
    if (maxFreq >= 2) {
      int valueToKeep = frequency.entries
          .firstWhere((entry) => entry.value == maxFreq)
          .key;
      return dice.map((die) => die == valueToKeep).toList();
    }
  }

  // If all else fails, keep highest value dice
  int highestValue = dice.reduce((a, b) => a > b ? a : b);
  for (int i = 0; i < dice.length; i++) {
    if (dice[i] == highestValue) {
      bestKeep[i] = true;
    }
  }
  return bestKeep;
}

bool _isYahtzeeInProgress(Map<int, int> frequency) {
  return frequency.values.any((count) => count >= 3);
}

bool _isFullHouseInProgress(Map<int, int> frequency) {
  return (frequency.values.any((count) => count >= 3) && 
          frequency.values.any((count) => count == 2)) ||
         (frequency.values.where((count) => count >= 2).length >= 2);
}

List<bool> _keepFullHouseDice(List<int> dice, Map<int, int> frequency) {
  List<bool> keep = List.filled(dice.length, false);
  
  // Find three of a kind first
  var threeOfAKindValue = frequency.entries
      .firstWhere((entry) => entry.value >= 3, 
                 orElse: () => MapEntry(0, 0))
      .key;
      
  // Find pair
  var pairValue = frequency.entries
      .firstWhere((entry) => entry.value == 2 && entry.key != threeOfAKindValue,
                 orElse: () => MapEntry(0, 0))
      .key;

  // If we don't have a three of a kind yet, keep the highest frequency pair
  if (threeOfAKindValue == 0) {
    var pairs = frequency.entries.where((entry) => entry.value >= 2).toList();
    if (pairs.isNotEmpty) {
      pairs.sort((a, b) => a.key.compareTo(b.key));
      threeOfAKindValue = pairs.last.key;
    }
  }

  // Mark dice to keep
  for (int i = 0; i < dice.length; i++) {
    if (dice[i] == threeOfAKindValue || dice[i] == pairValue) {
      keep[i] = true;
    }
  }
  return keep;
}

int _findBestUpperSectionValue(Map<String, int?> scores, Map<int, int> frequency) {
  // Calculate potential value for each number considering frequency and score
  Map<int, int> potentialValues = {};
  
  for (var entry in frequency.entries) {
    int value = entry.key;
    int count = entry.value;
    String category = _getUpperSectionCategory(value);
    
    // Only consider if category is not filled
    if (scores[category] == null) {
      potentialValues[value] = value * count;
    }
  }
  
  if (potentialValues.isEmpty) return 0;
  
  // Return the value that gives highest score
  return potentialValues.entries
      .reduce((a, b) => a.value > b.value ? a : b)
      .key;
}

String _getUpperSectionCategory(int value) {
  switch (value) {
    case 1: return 'ones';
    case 2: return 'twos';
    case 3: return 'threes';
    case 4: return 'fours';
    case 5: return 'fives';
    case 6: return 'sixes';
    default: return '';
  }
}

bool _isLargeStraightPossible(List<int> sortedUniqueDice) {
  if (sortedUniqueDice.length < 4) return false;
  
  // Check if we have 4 consecutive numbers
  int consecutiveCount = 1;
  for (int i = 0; i < sortedUniqueDice.length - 1; i++) {
    if (sortedUniqueDice[i + 1] == sortedUniqueDice[i] + 1) {
      consecutiveCount++;
    } else {
      consecutiveCount = 1;
    }
    if (consecutiveCount >= 4) return true;
  }
  return false;
}

bool _isSmallStraightPossible(List<int> sortedUniqueDice) {
  if (sortedUniqueDice.length < 3) return false;
  
  // Check if we have 3 consecutive numbers
  int consecutiveCount = 1;
  for (int i = 0; i < sortedUniqueDice.length - 1; i++) {
    if (sortedUniqueDice[i + 1] == sortedUniqueDice[i] + 1) {
      consecutiveCount++;
    } else {
      consecutiveCount = 1;
    }
    if (consecutiveCount >= 3) return true;
  }
  return false;
}

List<bool> _keepStraightDice(List<int> dice, bool isLargeStraight) {
  List<bool> keep = List.filled(dice.length, false);
  List<int> sequence = isLargeStraight ? [1, 2, 3, 4, 5, 6] : [1, 2, 3, 4, 5];
  
  for (int i = 0; i < dice.length; i++) {
    if (sequence.contains(dice[i])) {
      // Check if this value contributes to a sequence
      bool isPartOfSequence = false;
      for (int j = 0; j < sequence.length - (isLargeStraight ? 4 : 3); j++) {
        List<int> subSequence = sequence.sublist(j, j + (isLargeStraight ? 5 : 4));
        if (subSequence.contains(dice[i])) {
          // Count how many dice we have from this subsequence
          int count = dice.where((d) => subSequence.contains(d)).length;
          if (count >= (isLargeStraight ? 4 : 3)) {
            isPartOfSequence = true;
            break;
          }
        }
      }
      if (isPartOfSequence) {
        keep[i] = true;
      }
    }
  }
  return keep;
}


  int _getCategoryValue(String category) {
    switch (category) {
      case 'ones': return 1;
      case 'twos': return 2;
      case 'threes': return 3;
      case 'fours': return 4;
      case 'fives': return 5;
      case 'sixes': return 6;
      default: return 0;
    }
  }

  List<bool> _fallbackStrategyKeepDice(List<int> dice, Map<int, int> frequency) {
    // Keep highest frequency dice as fallback
    if (frequency.isNotEmpty) {
      var maxFreq = frequency.values.reduce((a, b) => a > b ? a : b);
      if (maxFreq >= 2) {
        int valueToKeep = frequency.entries
            .where((entry) => entry.value == maxFreq)
            .reduce((a, b) => a.key > b.key ? a : b)
            .key;
        return dice.map((die) => die == valueToKeep).toList();
      }
    }

    // If no pairs or better, keep highest value dice
    int highestValue = dice.reduce((a, b) => a > b ? a : b);
    return dice.map((die) => die == highestValue).toList();
  }
