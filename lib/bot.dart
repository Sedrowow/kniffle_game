// bot.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'scorecard.dart';

enum BotDifficulty { easy, medium, hard, ai, openai }

class Bot {
  final String? apiKey = dotenv.env['OPENAI_API_KEY'];
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

        // Easy: Randomly decide which dice to keep

        return List.generate(dice.length, (_) => _random.nextBool());

      case BotDifficulty.medium:

        // Medium: Randomly decide which dice to keep

        return List.generate(dice.length, (_) => _random.nextBool());

      case BotDifficulty.hard:

        // Hard: Aim for the best value (e.g., Kniffel)

        return _decideBestDiceToKeep(dice);

      case BotDifficulty.ai:

        // AI: Use OLLAMA service to decide

        return await _aiDecideDiceToKeep(scores, dice, diceKept);

      case BotDifficulty.openai:
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
        // AI: Use AI service to decide
        AIDecision decision = await _aiDecideToRoll(scores, dice, diceToKeep, rollCount);
        return decision.rollAgain;
      case BotDifficulty.openai:
        AIDecision decision = await _openaiDecideToRoll(scores, dice, diceToKeep, rollCount);
        return decision.rollAgain;
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
You are a Kniffel AI bot deciding which dice to keep.

**Important Notes:**
- Interactions must only use the commands exactly as provided.
- You can keep any dice by specifying their positions (1 to 5).
- You can only keep dice that are not already kept.

Your current dice are: ${dice.join(', ')}.
Kept dice positions: ${_getKeptDicePositions(diceKept)}.

Available commands:
- KeepDice # (where # is the dice position 1 to 5; you can keep multiple dice by using KeepDice #,#,#)
- RollDice
- SkipEntry

Decide which dice to keep by using the commands.
''';

    // Reset all kept dice
    List<bool> newDiceKept = List.filled(diceKept.length, false);
    String response;
    int attempts = 0;

    do {
      response = await _sendToOLLAMA(instructions);
      print('AI response: $response');

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
You are a Kniffel AI bot deciding whether to roll again.

**Important Notes:**
- Interactions must only use the commands exactly as provided.
- You can only roll again if you have rolls remaining (maximum 3 rolls per turn).
- If you decide not to roll, you must proceed to scoring.

Your current dice are: ${dice.join(', ')}.
Kept dice positions: ${_getKeptDicePositions(diceKept)}.
Roll count: $rollCount

**Available Categories:**
${availableCategories.join(', ')}

**Valid Categories:**
${validCategories.join(', ')}

Available commands:
- RollDice
- EnterScore <Category>
- SkipEntry

Decide whether to roll again or proceed to scoring by using the commands.
''';

    String response;
    int attempts = 0;

    do {
      response = await _sendToOLLAMA(instructions);
      print('AI response: $response');

      var decision = _parseRollDecision(response);

      if (decision == null) {
        // Invalid decision
        instructions += '''

Your response was invalid. Please use one of the available commands.

Available commands:
- RollDice
- EnterScore <Category>
- SkipEntry

Remember to use the commands exactly as provided.
''';
      } else if (decision.rollAgain && rollCount >= 3) {
        // Cannot roll more than 3 times
        instructions += '''

You have already rolled the maximum number of times (3). You must proceed to scoring.

Available commands:
- EnterScore <Category>
- SkipEntry

Remember to use the commands exactly as provided.
''';
      } else if (decision.categoryToScore != null) {
        // AI chose to enter a score, validate the category
        String category = decision.categoryToScore!;
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
          // Score is zero or invalid
          instructions += '''

You have chosen to enter a category where the score would be zero or your dice do not fulfill the requirements.

Please choose another category from the valid categories.

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

          var confirmationDecision = _parseRollDecision(response);

          if (confirmationDecision?.categoryToScore == category) {
            // Confirmed
            return AIDecision(rollAgain: false, categoryToScore: category);
          } else {
            // AI chose a different action, loop again
            continue;
          }
        }
      } else if (decision.skipEntry) {
        return AIDecision(rollAgain: false, skipEntry: true);
      } else if (decision.rollAgain) {
        return AIDecision(rollAgain: true);
      }

      attempts++;
    } while (attempts < 3);

    // Default to not rolling again
    return AIDecision(rollAgain: false);
  }

  Future<String> _aiDecideCategoryToScore(
      Map<String, int?> scores, List<int> dice) async {
    List<String> availableCategories =
        scores.keys.where((key) => scores[key] == null).toList();
    List<String> validCategories = _getValidCategories(scores, dice);

    String instructions = '''
You are a Kniffel AI bot deciding which category to score.

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
You are a Kniffel AI bot deciding which dice to keep.

**Important Notes:**
- Interactions must only use the commands exactly as provided.
- You can keep any dice by specifying their positions (1 to 5).
- For each keeping decision, you must reenter all kept dice positions.

Your current dice are: ${dice.join(',')}.

Available commands:
- KeepDice # (where # is the dice position 1 to 5; you can keep multiple dice by using KeepDice #,#,# (never use whitespaces for multiple dices and consider to reenter already kept dices if further keeping is required))
- RollDice
- EnterScore <Category>
- SkipEntry

Decide which dice to keep by using the commands.
''';

    // Reset all kept dice
    List<bool> newDiceKept = List.filled(diceKept.length, false);
    String response;
    int attempts = 0;

    do {
      response = await _sendToOpenAI(instructions);
      print('OpenAI response: $response');

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
You are a Kniffel AI bot deciding whether to roll again.

**Important Notes:**
- Interactions must only use the commands exactly as provided.
- You can only roll again if you have rolls remaining (maximum 3 rolls per turn).
- If you decide not to roll, you must proceed to scoring.

Your current dice are: ${dice.join(', ')}.
Kept dice positions: ${_getKeptDicePositions(diceKept)}.
Roll count: $rollCount

**Available Categories:**
${availableCategories.join(', ')}

**Valid Categories:**
${validCategories.join(', ')}

Available commands:
- RollDice
- EnterScore <Category>
- SkipEntry

Decide whether to roll again or proceed to scoring by using the commands.
''';

    String response;
    int attempts = 0;

    do {
      response = await _sendToOpenAI(instructions);
      print('OpenAI response: $response');

      var decision = _parseRollDecision(response);

      if (decision == null) {
        // Invalid decision
        instructions += '''

Your response was invalid. Please use one of the available commands.

Available commands:
- RollDice
- EnterScore <Category>
- SkipEntry

Remember to use the commands exactly as provided.
''';
      } else if (decision.rollAgain && rollCount >= 3) {
        // Cannot roll more than 3 times
        instructions += '''

You have already rolled the maximum number of times (3). You must proceed to scoring.

Available commands:
- EnterScore <Category>
- SkipEntry

Remember to use the commands exactly as provided.
''';
      } else if (decision.categoryToScore != null) {
        // AI chose to enter a score, validate the category
        String category = decision.categoryToScore!;
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
          // Score is zero or invalid
          instructions += '''

You have chosen to enter a category where the score would be zero or your dice do not fulfill the requirements.

Please choose another category from the valid categories.

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

          var confirmationDecision = _parseRollDecision(response);

          if (confirmationDecision?.categoryToScore == category) {
            // Confirmed
            return AIDecision(rollAgain: false, categoryToScore: category);
          } else {
            // AI chose a different action, loop again
            continue;
          }
        }
      } else if (decision.skipEntry) {
        return AIDecision(rollAgain: false, skipEntry: true);
      } else if (decision.rollAgain) {
        return AIDecision(rollAgain: true);
      }

      attempts++;
    } while (attempts < 3);

    // Default to not rolling again
    return AIDecision(rollAgain: false);
  }

  Future<String> _openaiDecideCategoryToScore(
      Map<String, int?> scores, List<int> dice) async {
    List<String> availableCategories =
        scores.keys.where((key) => scores[key] == null).toList();
    List<String> validCategories = _getValidCategories(scores, dice);

    String instructions = '''
You are a Kniffel AI bot deciding which category to score.

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

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model':
              'llama3.2', // Replace with your actual model name if different
          'prompt': prompt,
          'stream': false, // Set stream to false to get a single response
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return data['response'] ?? '';
      } else {
        throw Exception('Failed to get response from OLLAMA service.');
      }
    } catch (e) {
      print('Error communicating with OLLAMA service: $e');
      // Fallback to hard difficulty if AI service is not available
      return '';
    }
  }

  // Helper methods to parse AI responses
  List<int> _parseKeepDiceResponse(String response, List<bool> diceKept) {
    RegExp regex = RegExp(r'KeepDice\s+([\d,]+)');
    Match? match = regex.firstMatch(response);

    if (match != null) {
      List<int> indices = match
          .group(1)!
          .split(',')
          .map((e) => e.trim()) // Remove any additional whitespaces
          .where((e) => e.isNotEmpty) // Ensure no empty strings
          .map((e) => int.parse(e) - 1)
          .toList();

      // Reset diceKept to no dice being kept
      diceKept = List<bool>.filled(diceKept.length, false);

      // Filter out invalid indices and update diceKept
      indices = indices
          .where((index) => index >= 0 && index < diceKept.length)
          .toList();
      for (int index in indices) {
        diceKept[index] = true;
      }

      return indices;
    }

    // If parsing fails, return empty list
    return [];
  }

  AIDecision? _parseRollDecision(String response) {
    response = response.trim().toLowerCase();

    if (response.contains('rolldice')) {
      return AIDecision(rollAgain: true);
    } else if (response.contains('skipentry')) {
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

  Bot.namedConstructor(this.agentId,
      {required this.name, required this.difficulty});
}

class AIDecision {
  final bool rollAgain;
  final String? categoryToScore; // Non-null if AI chooses to enter a score
  final bool skipEntry;

  AIDecision({
    required this.rollAgain,
    this.categoryToScore,
    this.skipEntry = false,
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
      50; // Example: 50 is the highest possible score for Kniffel
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
