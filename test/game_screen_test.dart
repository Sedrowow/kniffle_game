import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kniffle_game/dice_display.dart';
import 'package:kniffle_game/game_screen.dart';

void main() {
  testWidgets('GameScreen initialization test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          players: [
            {'name': 'Player1', 'isBot': false, 'botDifficulty': 'easy'},
          ],
        ),
      ),
    );

    expect(find.byType(DiceDisplay), findsOneWidget);
    expect(find.text('Player1'), findsOneWidget);
  });
}
