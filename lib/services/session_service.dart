import 'dart:async';
import 'package:flutter/material.dart';

class SessionService {
  Timer? _timer;
  final Duration timeout = const Duration(minutes: 2);

  void startTimer(VoidCallback onTimeout) {
    _timer?.cancel();
    _timer = Timer(timeout, onTimeout);
  }

  void resetTimer(VoidCallback onTimeout) {
    startTimer(onTimeout);
  }

  void stopTimer() => _timer?.cancel();
}