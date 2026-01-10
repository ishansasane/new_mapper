import 'package:flutter/material.dart';

class CircularButton extends StatelessWidget {
  final bool isMonitoring;
  final VoidCallback onPressed;

  const CircularButton({
    super.key,
    required this.isMonitoring,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: isMonitoring ? Colors.red : Colors.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isMonitoring
                  ? Colors.red.withOpacity(0.4)
                  : Colors.green.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMonitoring ? Icons.stop : Icons.play_arrow,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              isMonitoring ? 'STOP' : 'START',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
