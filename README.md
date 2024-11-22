# kniffel_game

## READ THIS

the ai difficulty needs ollama installed on the local device with the model "llama3.2" pulled

after installing ollama just run in CMD "ollama pull llama3.2" while ollama is running to be able to use ai difficulty

the openai difficulty requires a openai api key, which is not included in this export. for a working openai difficulty, you need to get an api key from openai and replace the key in the .env in the asstets folder.

## Features

- plays kniffel with 0 players up to almost infinite players
- 5 different difficulties from easy to hard and an ai and openai difficulty
- let the bots play against each other by having no player (0 players means that all players are bots)


## state

In Flutter, **state** refers to the data or information that can change over the lifetime of an application. It determines how a widget behaves and appears. For example, a button's enabled or disabled status, a counter's current value, or whether a checkbox is checked are all parts of the state.

### Types of State in Flutter

1.  **Ephemeral State**:
    
    *   This is local and short-lived state that doesn’t need to be shared across widgets.
    *   Managed directly within a widget using `StatefulWidget`.
    *   Example: The current value of a text input.
2.  **App State**:
    
    *   This is global or shared state that needs to be accessed or modified by multiple widgets.
    *   Managed using state management solutions like **Provider**, **Riverpod**, **Bloc**, or others.

* * *

### State in Relation to **Provider**

Provider is a state management library in Flutter that helps manage and share state efficiently across your app.

1.  **Purpose of Provider**:
    
    *   It allows you to create, update, and access state (data) anywhere in your widget tree without having to pass it explicitly through constructor parameters (prop drilling).
2.  **How it Relates to State**:
    
    *   The **state** is stored in a class or object (often called a **ChangeNotifier**) that is exposed to widgets through the `Provider` library.
    *   Widgets can listen to changes in this state and rebuild themselves when the state updates.
3.  **Key Concepts**:
    
    *   **ChangeNotifier**: A class that holds the state and notifies listeners (widgets) when the state changes.
    *   **Consumer**: A widget that listens to the provided state and rebuilds when notified.
    *   **Provider**: A widget that "provides" an instance of the state to its descendants.

* * *

### Example: State with Provider

Here’s an example where a counter value is managed with `Provider`.

#### 1\. **State Class**:

```dart
import 'package:flutter/foundation.dart';

class CounterState extends ChangeNotifier {
  int _count = 0;

  int get count => _count;

  void increment() {
    _count++;
    notifyListeners(); // Notifies widgets to rebuild
  }
}
```

#### 2\. **Provide the State**:

Wrap your app or part of it with a `ChangeNotifierProvider`.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => CounterState(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CounterScreen(),
    );
  }
}
```

#### 3\. **Consume the State**:

Access and display the state in the UI.

```dart
class CounterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final counterState = Provider.of<CounterState>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Counter with Provider')),
      body: Center(
        child: Text('Count: ${counterState.count}', style: TextStyle(fontSize: 24)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: counterState.increment,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

* * *

### Summary

*   **State** is dynamic data that determines UI behavior and appearance.
*   In relation to `Provider`, **state** is managed in a `ChangeNotifier` or similar class.
*   `Provider` simplifies sharing and updating this state across the app while maintaining clean, readable code.
