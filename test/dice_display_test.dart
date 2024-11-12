import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kniffle_game/dice_display.dart';

void main() {
  testWidgets('DiceDisplay shows correct number of dice', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiceDisplay(
            diceValues: [1, 2, 3, 4, 5],
            diceKept: [false, false, false, false, false],
            onDiceTapped: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(GestureDetector), findsNWidgets(5));
  });
}
