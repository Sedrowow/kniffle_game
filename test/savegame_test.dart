import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:kniffle_game/savegame.dart';

@GenerateMocks([SaveGameManager])
void main() {
  group('SaveGame', () {
    test('serialization', () {
      final saveGame = SaveGame(
        name: 'TestGame',
        timestamp: DateTime.now(),
        currentRound: 1,
        currentPlayerIndex: 0,
        players: [
          PlayerState(
            name: 'Player1',
            isBot: false,
            scores: [{}],
            bonus: 0,
          ),
        ],
        actionLog: ['Game started'],
      );

      final json = saveGame.toJson();
      final reconstructed = SaveGame.fromJson(json);

      expect(reconstructed.name, equals(saveGame.name));
      expect(reconstructed.currentRound, equals(saveGame.currentRound));
      expect(reconstructed.players.length, equals(saveGame.players.length));
    });
  });
}
