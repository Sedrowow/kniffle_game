import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kniffle_game/high_score_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HighScore screen shows empty list initially', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HighScoreScreen(),
      ),
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}
