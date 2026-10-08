import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const HomeRunApp());

class HomeRunApp extends StatelessWidget {
  const HomeRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Home Run',
      tagline: 'Time your swing and smash it out of the park',
      emoji: '⚾',
      slug: 'homerun',
      howToPlay:
          '• 10 pitches. Swipe UP to swing as the ball crosses the plate.\n• Perfect timing = towering home run. Early or late = foul or whiff.\n• Back-to-back homers build a streak multiplier!\n• Fastballs, curves and changeups keep you guessing.',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => HomeRunScreen(players: players, callbacks: cb),
    );
  }
}
