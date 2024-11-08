import 'package:flutter/material.dart';
import 'dart:math';

class DiceDisplay extends StatefulWidget {
  final List<int> diceValues;
  final List<bool> diceKept;
  final Function(int) onDiceTapped;
  final bool enabled;

  const DiceDisplay({
    super.key,
    required this.diceValues,
    required this.diceKept,
    required this.onDiceTapped,
    this.enabled = true,
  });

  @override
  DiceDisplayState createState() => DiceDisplayState();
}

class DiceDisplayState extends State<DiceDisplay>
    with TickerProviderStateMixin {
  late List<int> _diceValues;
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _diceValues = widget.diceValues;
    _controllers = List.generate(5, (index) => AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    ));
  }

  @override
  void didUpdateWidget(covariant DiceDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _diceValues = widget.diceValues;
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void resetDice() {
    setState(() {
      _diceValues = [0, 0, 0, 0, 0];
    });
  }

  void rollDice({List<bool>? keep}) async {
    setState(() {
      for (int i = 0; i < _diceValues.length; i++) {
        if (keep == null || !keep[i]) {
          _diceValues[i] = 0;
        }
      }
    });

    int spins = 6; // Number of full spins
    int updatesPerSpin = 2; // Number of updates per spin
    int totalUpdates = spins * updatesPerSpin;

    for (int update = 0; update < totalUpdates; update++) {
      await Future.delayed(const Duration(milliseconds: 100));

      setState(() {
        for (int i = 0; i < _diceValues.length; i++) {
          if (keep == null || !keep[i]) {
            _diceValues[i] = Random().nextInt(6) + 1;
          }
        }
      });
    }
  }

  List<int> getDiceValues() {
    return _diceValues;
  }

  @override
  Widget build(BuildContext context) {
    final keptDiceCount = widget.diceKept.where((kept) => kept).length;
    final nonKeptDiceCount = widget.diceKept.where((kept) => !kept).length;
    
    // Calculate container widths based on dice counts
    const diceWidth = 70.0; // Base width for each dice including margins
    const minBoxWidth = 200.0; // Increased from 100.0 to 200.0
    
    // Calculate widths with minimums
    final keepBoxWidth = max(minBoxWidth, keptDiceCount * diceWidth + 20.0); // Increased from 20.0 to 40.0
    final rollBoxWidth = max(minBoxWidth, nonKeptDiceCount * diceWidth + 20.0); // Increased from 20.0 to 40.0
    
    // Use the larger width for overall container to maintain centering
    final totalWidth = max(380.0, max(keepBoxWidth, rollBoxWidth) + 40.0); // Fixed minimum width

    return Center(
      child: SizedBox(
        width: totalWidth,
        height: 300,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Keep box with kept dice
            Positioned(
              top: 20,
              child: Container(
                width: keepBoxWidth,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Keep Box',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Kept dice row
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_diceValues.length, (index) {
                              if (!widget.diceKept[index]) return const SizedBox.shrink();
                              return _buildDice(index, true);
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom row with dice and placeholders
            Positioned(
              bottom: 20,
              child: Container(
                width: rollBoxWidth,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_diceValues.length, (index) {
                      return _buildDice(index, false);
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDice(int index, bool inKeepBox) {
    bool isKept = widget.diceKept[index];
    int value = _diceValues[index];
    const diceUnicodeCharacters = ['\u2680', '\u2681', '\u2682', '\u2683', '\u2684', '\u2685'];

    // Only show dice in keep box if kept, and only show non-kept dice in bottom row
    if (inKeepBox != isKept) return const SizedBox.shrink();

    return GestureDetector(
      onTap: widget.enabled ? () => widget.onDiceTapped(index) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isKept ? Colors.green : Colors.black,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isKept ? Colors.white : Colors.grey.withOpacity(0.3),
        ),
        padding: const EdgeInsets.all(8),
        child: value > 0
            ? Text(
                diceUnicodeCharacters[value - 1],
                style: const TextStyle(fontSize: 50),
              )
            : const SizedBox(
                width: 50,
                height: 50,
              ),
      ),
    );
  }
}
