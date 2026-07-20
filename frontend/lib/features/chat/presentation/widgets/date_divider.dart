import 'package:flutter/material.dart';

class DateDivider extends StatelessWidget {
  final String text;

  const DateDivider({super.key, required this.text});

@override
Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFF1E2A38), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            text,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFF1E2A38), thickness: 1)),
      ],
    ),
  );
}
}