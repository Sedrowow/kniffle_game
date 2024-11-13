import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kniffle_game/bot.dart';
import 'package:kniffle_game/game_screen.dart';
import 'package:kniffle_game/main.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mockito/mockito.dart';
import 'package:kniffle_game/ai_service.dart';

class MockAIService extends Mock implements AIService {}

void main() {
  setUpAll(() async {
    // Load environment variables
    await dotenv.load(fileName: 'assets/.env');
  });

  testWidgets('MyApp widget test', (WidgetTester tester) async {
    // Create a mock AIService
    final mockAIService = MockAIService();

    // Mock the AI availability checks
    when(mockAIService.checkAIAvailability()).thenAnswer((_) async => true);
    when(mockAIService.checkOpenAIAvailability()).thenAnswer((_) async => true);

    // Build the widget with the mocked AIService
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerSetupScreen(
          aiService: mockAIService,
        ),
      ),
    );

    // Wait for all animations and async operations
    await tester.pumpAndSettle();

    // Perform your tests
    expect(find.byType(MaterialApp), findsOneWidget);
    // Add more assertions as needed
  });

  testWidgets('PlayerSetupScreen initializes correctly without loaded game', (WidgetTester tester) async {
    // Create a mock AIService
    final mockAIService = MockAIService();

    // Mock the AI availability checks
    when(mockAIService.checkAIAvailability()).thenAnswer((_) async => true);
    when(mockAIService.checkOpenAIAvailability()).thenAnswer((_) async => true);

    // Ensure no other `when` calls are in progress
    resetMockitoState();

    // Build the widget with the mocked AIService
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerSetupScreen(
          aiService: mockAIService,
        ),
      ),
    );

    // Wait for all animations and async operations
    await tester.pumpAndSettle();

    // Verify initial state
    expect(find.text('Player 1 Name'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.byType(DropdownButton<BotDifficulty>), findsNothing);
  });

  testWidgets('PlayerSetupScreen adds and removes players', (WidgetTester tester) async {
    // Create a mock AIService
    final mockAIService = MockAIService();

    // Mock the AI availability checks
    when(mockAIService.checkAIAvailability()).thenAnswer((_) async => true);
    when(mockAIService.checkOpenAIAvailability()).thenAnswer((_) async => true);

    // Build the widget with the mocked AIService
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerSetupScreen(
          aiService: mockAIService,
        ),
      ),
    );

    // Wait for all animations and async operations
    await tester.pumpAndSettle();

    // Add a player
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();

    // Verify two players are present
    expect(find.text('Player 1 Name'), findsOneWidget);
    expect(find.text('Player 2 Name'), findsOneWidget);

    // Remove a player
    await tester.tap(find.text('-'));
    await tester.pumpAndSettle();

    // Verify only one player is present
    expect(find.text('Player 1 Name'), findsOneWidget);
    expect(find.text('Player 2 Name'), findsNothing);
  });

  testWidgets('PlayerSetupScreen handles bot settings', (WidgetTester tester) async {
    // Create a mock AIService
    final mockAIService = MockAIService();

    // Mock the AI availability checks
    when(mockAIService.checkAIAvailability()).thenAnswer((_) async => true);
    when(mockAIService.checkOpenAIAvailability()).thenAnswer((_) async => true);

    // Build the widget with the mocked AIService
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerSetupScreen(
          aiService: mockAIService,
        ),
      ),
    );

    // Wait for all animations and async operations
    await tester.pumpAndSettle();

    // Enable bot for the first player
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Verify bot difficulty dropdown is present
    expect(find.byType(DropdownButton<BotDifficulty>), findsOneWidget);
  });

  testWidgets('PlayerSetupScreen navigates to GameScreen on play', (WidgetTester tester) async {
    // Create a mock AIService
    final mockAIService = MockAIService();

    // Mock the AI availability checks
    when(mockAIService.checkAIAvailability()).thenAnswer((_) async => true);
    when(mockAIService.checkOpenAIAvailability()).thenAnswer((_) async => true);

    // Build the widget with the mocked AIService
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerSetupScreen(
          aiService: mockAIService,
        ),
      ),
    );

    // Wait for all animations and async operations
    await tester.pumpAndSettle();

    // Tap the play button
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify navigation to GameScreen
    expect(find.byType(GameScreen), findsOneWidget);
  });
}