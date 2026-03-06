import 'dart:async';
import 'package:flutter/material.dart';

class SessionService {
  Timer? _timer;
  
  // This callback is triggered when the 2 minutes are up
  final VoidCallback onTimeout;

  SessionService({required this.onTimeout});

  /// Starts or restarts the inactivity countdown.
  void startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 2), () {
      debugPrint("SESSION EXPIRED: Auto-locking system...");
      onTimeout();
    });
  }

  /// Reset the timer. This should be called on every user interaction.
  void resetTimer() {
    // Only reset if a timer is already active (prevents logic loops)
    startTimer();
  }

  /// Stop the timer entirely (useful during logout).
  void stopTimer() {
    _timer?.cancel();
  }
}