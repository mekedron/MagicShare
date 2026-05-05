import 'package:flutter/material.dart';

/// Small filled-or-outlined dot used wherever a device's online/offline
/// status is rendered (settings device-group section, send-tab tile).
class PresenceDot extends StatelessWidget {
  final bool isOnline;
  const PresenceDot({required this.isOnline, super.key});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? Colors.green.shade500 : Theme.of(context).disabledColor;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}
