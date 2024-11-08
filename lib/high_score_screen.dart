import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HighScoreScreen extends StatefulWidget {
  const HighScoreScreen({super.key});

  @override
  HighScoreScreenState createState() => HighScoreScreenState();
}

class HighScoreScreenState extends State<HighScoreScreen> {
  List<String> highScores = [];

  @override
  void initState() {
    super.initState();
    loadHighScores();
  }

  void loadHighScores() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      highScores = prefs.getStringList('highScores') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('High Scores'),
      ),
      body: ListView.builder(
        itemCount: highScores.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(highScores[index]),
          );
        },
      ),
    );
  }
}
