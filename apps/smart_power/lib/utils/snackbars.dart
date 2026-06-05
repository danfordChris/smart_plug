import 'package:flutter/material.dart';

/// Lightweight, consistent user feedback for actions.
class AppSnack {
  AppSnack._();

  /// Honest placeholder for roadmap features that aren't wired to a backend
  /// yet — so a tap always acknowledges instead of silently doing nothing.
  static void comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature is coming soon'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Generic info toast.
  static void info(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
