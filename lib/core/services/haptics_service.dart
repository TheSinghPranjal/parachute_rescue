import 'package:flutter/services.dart';

/// Subtle vibration for major events, if enabled and supported.
class HapticsService {
  bool enabled = true;

  void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
