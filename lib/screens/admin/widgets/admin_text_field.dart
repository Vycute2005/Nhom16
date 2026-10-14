import 'package:flutter/material.dart';

class AdminTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool enabled;
  final int maxLines;
  final TextInputType? keyboardType;

  const AdminTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}