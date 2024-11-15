import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kniffle_game/bot.dart';
import 'package:kniffle_game/game_screen.dart';
import 'package:kniffle_game/main.dart';
import 'package:kniffle_game/savegame.dart';
import 'package:mockito/mockito.dart';
import 'ai_service_test.mocks.dart';
import 'savegame_test.mocks.dart';

void main() {
  late MockAIService mockAIService;
  late MockSaveGameManager mockSaveGameManager;

  setUpAll(() async {
    await dotenv.load(fileName: 'assets/.env');
  });

  setUp(() {
    resetMockitoState();
    mockAIService = MockAIService();
    mockSaveGameManager = MockSaveGameManager();
// Properly stub the async methods to simulate the behavior of the AI service and SaveGameManager without making actual network or database calls
when(mockAIService.checkAIAvailability())
    .thenAnswer((_) async => true);
when(mockAIService.checkOpenAIAvailability())
    .thenAnswer((_) async => true);

// Mock the listSaves method to return a non-empty list
// This is to simulate the presence of saved games for testing purposes
when(mockSaveGameManager.listSaves())
    .thenAnswer((_) async => [
      SaveGame(
        name: 'Test Save',
        timestamp: DateTime.now(),
        currentRound: 1,
        currentPlayerIndex: 0,
        players: [],
        actionLog: [],
      )
    ]);
  });
  testWidgets('MyApp widget test', (WidgetTester tester) async {
    // Build the widget with the mocked AIService
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerSetupScreen(
          aiService: mockAIService,
        ),
      ),
    );

    // Wait for async operations
    await tester.pumpAndSettle();

    // Verify the widget built successfully
    expect(find.byType(MaterialApp), findsOneWidget);

    // Verify that the mock methods were called
    verify(mockAIService.checkAIAvailability()).called(1);
    verify(mockAIService.checkOpenAIAvailability()).called(1);
  });

  testWidgets('PlayerSetupScreen initializes without loaded game',
      (WidgetTester tester) async {
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

  testWidgets('PlayerSetupScreen adds and removes players correctly',
    (WidgetTester tester) async {
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

  testWidgets('PlayerSetupScreen enables and verifies bot settings',
      (WidgetTester tester) async {
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

  testWidgets('PlayerSetupScreen navigates to GameScreen when play button is tapped',
      (WidgetTester tester) async {
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

  testWidgets('PlayerSetupScreen displays load game dialog on button tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerSetupScreen(
          aiService: mockAIService,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap the load game button
    await tester.tap(find.byIcon(Icons.folder_open));
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Load Game'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}