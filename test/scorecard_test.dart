import 'package:flutter_test/flutter_test.dart';
import 'package:kniffle_game/scorecard.dart';

void main() {
  group('Scorecard', () {
    late Scorecard scorecard;

    setUp(() {
      scorecard = Scorecard(playerName: 'Test Player');
    });

    test('initialization', () {
      expect(scorecard.playerName, equals('Test Player'));
      expect(scorecard.scores.length, equals(1));
      expect(scorecard.bonus, equals(0));
    });

    test('calculate score for numbers', () {
      final dice = [1, 1, 1, 2, 3];
      expect(scorecard.calculateScoreForCategory(dice, 0), equals(3)); // ones
      expect(scorecard.calculateScoreForCategory(dice, 1), equals(2)); // twos
      expect(scorecard.calculateScoreForCategory(dice, 2), equals(3)); // threes
    });

    test('calculate special combinations', () {
      final dice = [1, 1, 1, 1, 1];
      expect(scorecard.calculateScoreForCategory(dice, 11), equals(50)); // kniffel
      expect(scorecard.calculateScoreForCategory(dice, 6), equals(5)); // three of a kind
    });

    test('total score calculation', () {
      scorecard.scores[0]['ones'] = 3;
      scorecard.scores[0]['twos'] = 4;
      expect(scorecard.totalScore(), equals(7));
    });
  });
}
