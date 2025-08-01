import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';

class FlushbarHelper {
  static void show(
      BuildContext context, {
        required String message,
        IconData? icon,
        Color backgroundColor = Colors.black87,
        Duration duration = const Duration(seconds: 3),
      }) {
    Flushbar(
      messageText: Text(message,style: const TextStyle(color: Colors.white, fontSize: 16)),
      icon: icon != null ? Icon(icon, color: Colors.white) : null,
      duration: duration,
      backgroundColor: backgroundColor,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(8),
      flushbarPosition: FlushbarPosition.BOTTOM,
    ).show(context);
  }
}
