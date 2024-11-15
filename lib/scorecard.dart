import 'package:flutter/material.dart';

class Scorecard {
  final String playerName;
  List<Map<String, int?>> scores = [];
  int bonus = 0;

  Scorecard({required this.playerName}) {
    extendScores();
  }

  void extendScores() {
    scores.add({
      'ones': null,
      'twos': null,
      'threes': null,
      'fours': null,
      'fives': null,
      'sixes': null,
      'threeOfAKind': null,
      'fourOfAKind': null,
      'fullHouse': null,
      'smallStraight': null,
      'largeStraight': null,
      'kniffel': null,
      'chance': null,
    });
  }

  int totalScore() {
    int total = 0;
    for (var roundScores in scores) {
      for (var score in roundScores.values) {
        if (score != null) {
          total += score;
        }
      }
    }
    return total + bonus;
  }

  void crossOutBestField(int round) {
    List<String> fields = [
      'kniffel',
      'largeStraight',
      'smallStraight',
      'fullHouse',
      'fourOfAKind',
      'threeOfAKind',
      'sixes',
      'fives',
      'fours',
      'threes',
      'twos',
      'ones'
    ];

    for (String field in fields) {
      if (scores[round - 1][field] == null) {
        scores[round - 1][field] = 0; // Cross out the field
        break;
      }
    }
  }

  // Define the categories
  List<String> get categories => [
        'ones',
        'twos',
        'threes',
        'fours',
        'fives',
        'sixes',
        'threeOfAKind',
        'fourOfAKind',
        'fullHouse',
        'smallStraight',
        'largeStraight',
        'kniffel',
        'chance'
      ];

  // Calculate score for a given category
  int calculateScoreForCategory(List<int> dice, int categoryIndex) {
    String category = categories[categoryIndex];
    switch (category) {
      case 'ones':
        return dice.contains(1) ? dice.where((die) => die == 1).length * 1 : 0;
      case 'twos':
        return dice.contains(2) ? dice.where((die) => die == 2).length * 2 : 0;
      case 'threes':
        return dice.contains(3) ? dice.where((die) => die == 3).length * 3 : 0;
      case 'fours':
        return dice.contains(4) ? dice.where((die) => die == 4).length * 4 : 0;
      case 'fives':
        return dice.contains(5) ? dice.where((die) => die == 5).length * 5 : 0;
      case 'sixes':
        return dice.contains(6) ? dice.where((die) => die == 6).length * 6 : 0;
      case 'threeOfAKind':
        return dice.any((die) => dice.where((d) => d == die).length >= 3) ? dice.reduce((a, b) => a + b) : 0;
      case 'fourOfAKind':
        return dice.any((die) => dice.where((d) => d == die).length >= 4) ? dice.reduce((a, b) => a + b) : 0;
      case 'fullHouse':
        Map<int, int> counts = {};
        for (var die in dice) {
          counts[die] = (counts[die] ?? 0) + 1;
        }
        bool hasThreeOfAKind = counts.values.contains(3);
        bool hasPair = counts.values.contains(2);
        return hasThreeOfAKind && hasPair ? 25 : 0;
      case 'smallStraight':
        var uniqueDice = dice.toSet().toList()..sort();
        for (int i = 0; i < uniqueDice.length - 3; i++) {
          if (uniqueDice[i + 1] == uniqueDice[i] + 1 &&
              uniqueDice[i + 2] == uniqueDice[i] + 2 &&
              uniqueDice[i + 3] == uniqueDice[i] + 3) {
            return 30;
          }
        }
        return 0;
      case 'largeStraight':
        var sortedDice = List<int>.from(dice)..sort();
        for (int i = 0; i < sortedDice.length - 4; i++) {
          if (sortedDice[i + 1] == sortedDice[i] + 1 &&
              sortedDice[i + 2] == sortedDice[i] + 2 &&
              sortedDice[i + 3] == sortedDice[i] + 3 &&
              sortedDice[i + 4] == sortedDice[i] + 4) {
            return 40;
          }
        }
        return 0;
      case 'kniffel':
        return dice.toSet().length == 1 ? 50 : 0;
      case 'chance':
        return dice.reduce((a, b) => a + b);
      default:
        return 0;
    }
  }

  // Update score for a given category and round
  void updateScore(int categoryIndex, int round, int score) {
    scores[round][categories[categoryIndex]] = score;
  }

  // Skip entry for a given round
  void skipEntry(int round) {
    crossOutBestField(round + 1);
  }

  // Check if the category is valid for the given dice
  bool isValidForCategory(List<int> dice, int categoryIndex) {
    String category = categories[categoryIndex];
    switch (category) {
      case 'ones':
        return dice.contains(1);
      case 'twos':
        return dice.contains(2);
      case 'threes':
        return dice.contains(3);
      case 'fours':
        return dice.contains(4);
      case 'fives':
        return dice.contains(5);
      case 'sixes':
        return dice.contains(6);
      case 'threeOfAKind':
        return dice.any((die) => dice.where((d) => d == die).length >= 3);
      case 'fourOfAKind':
        return dice.any((die) => dice.where((d) => d == die).length >= 4);
      case 'fullHouse':
        Map<int, int> counts = {};
        for (var die in dice) {
          counts[die] = (counts[die] ?? 0) + 1;
        }
        bool hasThreeOfAKind = counts.values.contains(3);
        bool hasPair = counts.values.contains(2);
        return hasThreeOfAKind && hasPair;
      case 'smallStraight':
        var uniqueDice = dice.toSet().toList()..sort();
        for (int i = 0; i < uniqueDice.length - 3; i++) {
          if (uniqueDice[i + 1] == uniqueDice[i] + 1 &&
              uniqueDice[i + 2] == uniqueDice[i] + 2 &&
              uniqueDice[i + 3] == uniqueDice[i] + 3) {
            return true;
          }
        }
        return false;
      case 'largeStraight':
        var sortedDice = List<int>.from(dice)..sort();
        for (int i = 0; i < sortedDice.length - 4; i++) {
          if (sortedDice[i + 1] == sortedDice[i] + 1 &&
              sortedDice[i + 2] == sortedDice[i] + 2 &&
              sortedDice[i + 3] == sortedDice[i] + 3 &&
              sortedDice[i + 4] == sortedDice[i] + 4) {
            return true;
          }
        }
        return false;
      case 'kniffel':
        return dice.toSet().length == 1;
      case 'chance':
        return true;
      default:
        return false;
    }
  }

  int calculateUpperScore(int round) {
    int sum = 0;
    final upperCategories = ['ones', 'twos', 'threes', 'fours', 'fives', 'sixes'];
    for (var category in upperCategories) {
      sum += scores[round][category] ?? 0;
    }
    return sum;
  }

  int calculateLowerScore(int round) {
    int sum = 0;
    final lowerCategories = [
      'threeOfAKind',
      'fourOfAKind',
      'fullHouse',
      'smallStraight',
      'largeStraight',
      'kniffel',
      'chance'
    ];
    for (var category in lowerCategories) {
      sum += scores[round][category] ?? 0;
    }
    return sum;
  }

  bool isUpperSectionComplete(int round) {
    final upperCategories = ['ones', 'twos', 'threes', 'fours', 'fives', 'sixes'];
    return upperCategories.every((category) => scores[round][category] != null);
  }

  int calculateBonus(int round) {
    return calculateUpperScore(round) >= 63 ? 35 : 0;
  }

  int calculateRoundScore(int round) {
    return calculateUpperScore(round) + calculateLowerScore(round) + calculateBonus(round);
  }
}

class ScorecardWidget extends StatefulWidget {
  final Scorecard scorecard;
  final int currentRound;
  final List<int>? currentDice;
  final bool isDisplayOnly;

  const ScorecardWidget({
    super.key,
    required this.scorecard,
    required this.currentRound,
    this.currentDice,
    this.isDisplayOnly = false,
  });

  @override
  _ScorecardWidgetState createState() => _ScorecardWidgetState();
}

class _ScorecardWidgetState extends State<ScorecardWidget> {
  int? selectedCategoryIndex;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.scorecard.playerName}\'s Scorecard'),
      content: widget.isDisplayOnly ? _buildFullScorecard() : _buildCurrentRoundScorecard(),
      actions: widget.isDisplayOnly
          ? [
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Close'))
            ]
          : [
              ElevatedButton(
                onPressed: selectedCategoryIndex == null
                    ? null
                    : () {
                        int score = widget.scorecard.calculateScoreForCategory(
                            widget.currentDice!, selectedCategoryIndex!);
                        widget.scorecard.updateScore(
                            selectedCategoryIndex!, widget.currentRound - 1, score);
                        Navigator.pop(context, true);
                      },
                child: const Text('Confirm'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.scorecard.skipEntry(widget.currentRound - 1);
                  Navigator.pop(context, true);
                },
                child: const Text('Skip Entry'),
              ),
            ],
    );
  }

  Widget _buildFullScorecard() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.75,
      height: MediaQuery.of(context).size.height * 0.8,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            children: [
              // Header row
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ...List.generate(12, (index) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Round ${index + 1}', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: index + 1 == widget.currentRound ? Colors.red : Colors.black
                      )
                    ),
                  )),
                ],
              ),
              // Upper section
              ...List.generate(6, (index) => _buildUpperSectionRow(index)),
              // Upper section total
              _buildTotalRow('Upper Score'),
              // Bonus row
              _buildBonusRow(),
              // Lower section
              ...List.generate(7, (index) => _buildLowerSectionRow(index)),
              // Lower section total
              _buildTotalRow('Lower Score'),
              // Final total
              _buildTotalRow('Total Score', isFinal: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentRoundScorecard() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.25,
      height: MediaQuery.of(context).size.height * 0.8,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Table(
              border: TableBorder.all(),
              children: [
                const TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Score', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ...List.generate(
                  widget.scorecard.categories.length,
                  (index) => _buildTableRow(index),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Available Categories:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...widget.scorecard.categories
                .where((category) => widget.scorecard
                    .scores[widget.currentRound - 1][category] == null)
                .map((category) => Text(category)),
          ],
        ),
      ),
    );
  }

  TableRow _buildUpperSectionRow(int index) {
    final categories = ['ones', 'twos', 'threes', 'fours', 'fives', 'sixes'];
    return _buildScoreRow(categories[index]);
  }

  TableRow _buildLowerSectionRow(int index) {
    final categories = [
      'threeOfAKind',
      'fourOfAKind',
      'fullHouse',
      'smallStraight',
      'largeStraight',
      'kniffel',
      'chance'
    ];
    return _buildScoreRow(categories[index]);
  }

  TableRow _buildScoreRow(String category) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...List.generate(12, (round) {
          if (round >= widget.scorecard.scores.length) {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('-'),
            );
          }
          
          final score = widget.scorecard.scores[round][category];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: score == 0
                ? CustomPaint(size: const Size(20, 20), painter: CrossPainter())
                : Text(score?.toString() ?? '-'),
          );
        }),
      ],
    );
  }

  TableRow _buildBonusRow() {
    return TableRow(
      children: [
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('Bonus', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...List.generate(12, (round) {
          if (round >= widget.scorecard.scores.length) {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('-'),
            );
          }
          
          final bonus = widget.scorecard.isUpperSectionComplete(round)
              ? widget.scorecard.calculateBonus(round)
              : null;
              
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: bonus == null
                ? const Text('-')
                : bonus == 0
                    ? CustomPaint(size: const Size(20, 20), painter: CrossPainter())
                    : Text(bonus.toString()),
          );
        }),
      ],
    );
  }

  TableRow _buildTotalRow(String label, {bool isFinal = false}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label, 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isFinal ? Colors.red : Colors.black
            )
          ),
        ),
        ...List.generate(12, (round) {
          if (round >= widget.scorecard.scores.length) {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('-'),
            );
          }
          
          int score;
          if (label == 'Upper Score') {
            score = widget.scorecard.calculateUpperScore(round);
          } else if (label == 'Lower Score') {
            score = widget.scorecard.calculateLowerScore(round);
          } else {
            score = widget.scorecard.calculateRoundScore(round);
          }
          
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              score.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isFinal ? Colors.red : Colors.black
              ),
            ),
          );
        }),
      ],
    );
  }

  TableRow _buildTableRow(int categoryIndex) {
    String category = widget.scorecard.categories[categoryIndex];
    bool isSelectable = widget.scorecard.scores[widget.currentRound - 1][category] == null &&
        widget.scorecard.isValidForCategory(widget.currentDice!, categoryIndex);

    Color backgroundColor = isSelectable
        ? (selectedCategoryIndex == categoryIndex
            ? Colors.green.withOpacity(0.3)
            : Colors.white)
        : Colors.grey.withOpacity(0.2);

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(category),
        ),
        GestureDetector(
          onTap: isSelectable
              ? () {
                  setState(() {
                    selectedCategoryIndex = categoryIndex;
                  });
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(8.0),
            color: backgroundColor,
            child: Text(
              isSelectable
                  ? (selectedCategoryIndex == categoryIndex
                      ? widget.scorecard
                          .calculateScoreForCategory(
                              widget.currentDice!, categoryIndex)
                          .toString()
                      : '-')
                  : (widget.scorecard.scores[widget.currentRound - 1][category]
                          ?.toString() ??
                      '-'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}