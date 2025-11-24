import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class CelebrationWidget extends StatefulWidget {
  const CelebrationWidget({
    super.key,
    this.onComplete,
  });

  final VoidCallback? onComplete;

  @override
  State<CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<CelebrationWidget> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 3));
    _controller.play();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _controller,
          blastDirection: pi / 2, // Downward
          maxBlastForce: 5,
          minBlastForce: 2,
          emissionFrequency: 0.05,
          numberOfParticles: 50,
          gravity: 0.1,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple,
            Colors.yellow,
          ],
        ),
      ),
    );
  }
}



