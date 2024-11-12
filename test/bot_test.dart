import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kniffle_game/bot.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;

class MockClient extends Mock implements http.Client {}

void main() {
  group('Bot', () {
    late Bot bot;

    setUp(() {
      bot = Bot(name: 'TestBot', difficulty: BotDifficulty.easy);
    });

    test('initialization', () {
      expect(bot.name, equals('TestBot'));
      expect(bot.difficulty, equals(BotDifficulty.easy));
    });

    test('decide dice to keep - easy mode', () async {
      await dotenv.load(); // Ensure environment variables are loaded
    
      final dice = [1, 2, 3, 4, 5];
      final diceKept = [false, false, false, false, false];
      final scores = {'ones': null, 'twos': null};
    
      final bot = Bot(name: 'TestBot', difficulty: BotDifficulty.easy); // Create Bot instance after loading env
    
      final decision = await bot.decideDiceToKeep(scores, dice, diceKept);
      expect(decision.length, equals(5));
    });

    test('decide to roll - easy mode', () async {
      final dice = [1, 2, 3, 4, 5];
      final diceKept = [false, false, false, false, false];
      final scores = {'ones': null, 'twos': null};

      final decision = await bot.decideToRoll(scores, dice, diceKept, 1);
      expect(decision, isA<bool>());
    });
  });
}
