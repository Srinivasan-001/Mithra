import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode

// Removed Firebase, Geolocator, Twilio imports as SMS logic is moved to HomeScreen

class EmergencyButton extends StatefulWidget {
  // Add a callback for when the manual trigger completes its countdown
  final VoidCallback onManualTrigger;

  const EmergencyButton({super.key, required this.onManualTrigger});

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton> {
  final Logger _logger = Logger();
  Timer? _countdownTimer;
  int _remainingSeconds = 10;
  bool _isCountingDown = false;
  // Removed _isSendingAlert state as the parent (HomeScreen) handles it

  // Removed Twilio initialization

  @override
  void dispose() {
    _cancelCountdown();
    super.dispose();
  }

  Future<void> _startEmergencyCountdown() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true && kDebugMode) {
      _logger.w("Device does not support vibration.");
    }

    setState(() {
      _isCountingDown = true;
      _remainingSeconds = 10;
    });

    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [500, 500], repeat: 0);
    }

    _showCountdownDialog();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _finalizeEmergency();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    Vibration.cancel();
    setState(() {
      _isCountingDown = false;
    });
    // Use rootNavigator: true to pop the dialog overlay
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (kDebugMode) {
      _logger.i("Manual emergency countdown cancelled by user.");
    }
  }

  void _finalizeEmergency() {
    _countdownTimer?.cancel();
    Vibration.cancel();
    setState(() {
      _isCountingDown = false;
      // No need for _isSendingAlert here
    });

    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    _logger.i("Manual countdown finished. Triggering parent action...");

    // --- CALL THE PARENT CALLBACK --- 
    widget.onManualTrigger();
    // --- SMS Logic is now handled by the parent (HomeScreen) ---
  }

  void _showCountdownDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Use a local timer subscription inside the dialog state 
            // OR rely on the main widget's setState triggering rebuilds.
            // For simplicity, relying on main widget's setState.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_isCountingDown && mounted) {
                 // Check if the dialog is still active before calling setDialogState
                 // This check might not be strictly necessary if pop ensures it's gone,
                 // but adds robustness.
                 if (ModalRoute.of(context)?.isCurrent ?? false) {
                    setDialogState(() {});
                 }
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
              title: const Text(
                'Emergency Alert Pending',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sending alert in...',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    // Use the state variable from the main widget
                    '$_remainingSeconds',
                    style: const TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Device is vibrating. Press Cancel to stop.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: const Text('Cancel Alert', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _cancelCountdown,
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
        elevation: 8,
        shadowColor: Colors.red.withAlpha(128),
      ),
      // Disable button only during its own countdown
      onPressed: _isCountingDown ? null : _startEmergencyCountdown,
      child: SizedBox(
        width: 80,
        height: 80,
        child: Center(
          // Show loading indicator only during its own countdown
          child: _isCountingDown
              ? const CircularProgressIndicator(color: Colors.white)
              : const Icon(
                  Icons.warning_rounded,
                  size: 48,
                ),
        ),
      ),
    );
  }
}

