import 'package:flutter/material.dart';

class ReactionRow extends StatelessWidget {
  final List<String> reactions;

  const ReactionRow({super.key, required this.reactions});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: reactions.map((r) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(r, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
    );
  }
}