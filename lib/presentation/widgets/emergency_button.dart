import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:twilio_flutter/twilio_flutter.dart';

import '../../core/config/twilio_config.dart'; // Import Twilio config

class EmergencyButton extends StatefulWidget {
  const EmergencyButton({super.key});

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton> {
  final Logger _logger = Logger();
  Timer? _countdownTimer;
  int _remainingSeconds = 10;
  bool _isCountingDown = false;
  bool _isSendingAlert = false; // To show loading state during SMS sending

  // Initialize TwilioFlutter
  late TwilioFlutter twilioFlutter;

  @override
  void initState() {
    super.initState();
    // Initialize TwilioFlutter with credentials from config
    twilioFlutter = TwilioFlutter(
      accountSid: twilioAccountSid,
      authToken: twilioAuthToken,
      twilioNumber: twilioPhoneNumber,
    );
  }

  @override
  void dispose() {
    _cancelCountdown(); // Ensure timer and vibration are cancelled
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

    if (mounted) {
      _showCountdownDialog();
    }

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
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (kDebugMode) {
      _logger.i("Emergency countdown cancelled by user.");
    }
  }

  Future<void> _finalizeEmergency() async {
    _countdownTimer?.cancel();
    Vibration.cancel();
    setState(() {
      _isCountingDown = false;
      _isSendingAlert = true; // Indicate sending process started
    });

    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(width: 16),
              Text('Sending Emergency Alert...'),
            ],
          ),
          duration: Duration(minutes: 1), // Keep visible until dismissed or replaced
          backgroundColor: Colors.orange,
        ),
      );
    }

    try {
      // 1. Get Current User
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in.");
      }

      // 2. Get Current Location
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final latitude = position.latitude;
      final longitude = position.longitude;
      final locationLink = "https://www.google.com/maps?q=$latitude,$longitude";

      // 3. Fetch User Data (including Emergency Contacts) from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        throw Exception("User data not found in Firestore.");
      }
      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] as String? ?? 'User';
      final emergencyContactsData = userData['emergencyContacts'] as List<dynamic>?;

      if (emergencyContactsData == null || emergencyContactsData.isEmpty) {
        throw Exception("No emergency contacts found for the user.");
      }

      // 4. Construct SMS Message
      final messageBody = "Emergency Alert! $userName needs help. Current location: $locationLink";

      // 5. Send SMS to Emergency Contacts
      int successCount = 0;
      List<String> failedContacts = [];

      for (var contactData in emergencyContactsData) {
        if (contactData is Map<String, dynamic>) {
          final contactPhone = contactData['phone'] as String?;
          final contactName = contactData['name'] as String? ?? 'Contact';

          if (contactPhone != null && contactPhone.trim().isNotEmpty) {
            try {
              await twilioFlutter.sendSMS(
                toNumber: contactPhone.trim(),
                messageBody: messageBody,
              );
              successCount++;
            } catch (smsError) {
              failedContacts.add(contactName);
            }
          } else {
            failedContacts.add("$contactName (missing number)");
          }
        }
      }

      // 6. Show Final Feedback
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (successCount > 0 && failedContacts.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency Alert Sent Successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        } else if (successCount > 0 && failedContacts.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Alert sent to $successCount contacts. Failed for: ${failedContacts.join(', ')}'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 8),
            ),
          );
        } else {
          throw Exception("Failed to send SMS to any emergency contacts.");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send emergency alert: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingAlert = false;
        });
      }
    }
  }

  void _showCountdownDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
      onPressed: (_isCountingDown || _isSendingAlert) ? null : _startEmergencyCountdown,
      child: SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: (_isCountingDown || _isSendingAlert)
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