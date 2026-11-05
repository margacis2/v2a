import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackService extends ChangeNotifier {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  static const String _keyVisualEffects = 'v2a_pref_visual_effects';
  static const String _keyHaptics = 'v2a_pref_haptics';

  bool _visualEffectsEnabled = true;
  bool _hapticsEnabled = true;
  bool _isInitialized = false;

  bool get visualEffectsEnabled => _visualEffectsEnabled;
  bool get hapticsEnabled => _hapticsEnabled;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _visualEffectsEnabled = prefs.getBool(_keyVisualEffects) ?? true;
      _hapticsEnabled = prefs.getBool(_keyHaptics) ?? true;
      _isInitialized = true;
      notifyListeners();
    } catch (_) {
      _visualEffectsEnabled = true;
      _hapticsEnabled = true;
    }
  }

  Future<void> setVisualEffectsEnabled(bool value) async {
    _visualEffectsEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyVisualEffects, value);
    } catch (_) {}
  }

  Future<void> setHapticsEnabled(bool value) async {
    _hapticsEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHaptics, value);
    } catch (_) {}
  }

  /// Feedback when a file conversion or trimming completes successfully
  void notifyFileCreated(BuildContext context, {required String fileName, String? path}) {
    if (_hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }

    if (_visualEffectsEnabled && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF1B5E20),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Audio Created Successfully',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    Text(
                      fileName,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Feedback when one or more files / records are deleted
  void notifyFileDeleted(BuildContext context, {required int count, String? description}) {
    if (_hapticsEnabled) {
      HapticFeedback.lightImpact();
    }

    if (_visualEffectsEnabled && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF37474F),
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  description ?? (count == 1 ? '1 item removed' : '$count items removed'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// General button tap haptic
  void triggerTapHaptic() {
    if (_hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }
}

