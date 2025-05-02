import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:logger/logger.dart';

class FallDetectionService {
  final Logger _logger = Logger();
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isListening = false;

  // Thresholds and parameters (these need careful tuning and testing)
  final double _freefallThreshold = 1.5; // m/s^2 (close to 0g, but allowing for noise)
  final double _impactThreshold = 25.0; // m/s^2 (high g-force)
  final Duration _freefallDurationThreshold = const Duration(milliseconds: 100);
  final Duration _impactWindow = const Duration(seconds: 2); // Look for impact within 2s of freefall end

  DateTime? _freefallStartTime;
  DateTime? _freefallEndTime;
  bool _potentialFallDetected = false;

  // Callback to notify when a fall is detected
  final VoidCallback onFallDetected;

  FallDetectionService({required this.onFallDetected});

  bool get isListening => _isListening;

  void startListening() {
    if (_isListening) return;

    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval, // Adjust as needed (gameInterval, uiInterval)
    ).listen(
      (AccelerometerEvent event) {
        _processAccelerometerData(event);
      },
      onError: (error) {
        _logger.e("Error listening to accelerometer: $error");
        stopListening();
      },
      cancelOnError: true,
    );
    _isListening = true;
    _logger.i("Started listening for fall detection.");
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isListening = false;
    _resetFallState();
    _logger.i("Stopped listening for fall detection.");
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    // Calculate the magnitude of the acceleration vector
    // magnitude = sqrt(x^2 + y^2 + z^2)
    final double magnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

    // Simple Threshold-Based Fall Detection Algorithm (Example)
    // This is a basic example and needs significant refinement and testing.
    // Real-world fall detection is complex and often involves more sophisticated algorithms,
    // potentially machine learning models, and fusion with gyroscope data.

    final now = DateTime.now();

    // 1. Detect Potential Freefall Start
    if (magnitude < _freefallThreshold) {
      if (_freefallStartTime == null) {
        _freefallStartTime = now;
        if (kDebugMode) {
          // _logger.d("Potential freefall start detected at $now (Magnitude: ${magnitude.toStringAsFixed(2)})");
        }
      }
    } else {
      // 2. Detect Potential Freefall End
      if (_freefallStartTime != null) {
        _freefallEndTime = now;
        final freefallDuration = _freefallEndTime!.difference(_freefallStartTime!);

        if (freefallDuration >= _freefallDurationThreshold) {
          _potentialFallDetected = true;
          if (kDebugMode) {
            _logger.d("Potential fall detected (freefall duration: ${freefallDuration.inMilliseconds}ms). Looking for impact...");
          }
        } else {
          // Reset if freefall was too short
          // _logger.d("Resetting: Freefall too short (${freefallDuration.inMilliseconds}ms)");
          _resetFallState();
        }
        _freefallStartTime = null; // Reset start time after processing
      }
    }

    // 3. Detect Impact after Potential Fall
    if (_potentialFallDetected && _freefallEndTime != null) {
      if (magnitude > _impactThreshold) {
        final timeSinceFreefallEnd = now.difference(_freefallEndTime!);
        if (timeSinceFreefallEnd <= _impactWindow) {
          _logger.i("FALL DETECTED! Impact magnitude: ${magnitude.toStringAsFixed(2)} at $now (Time since freefall end: ${timeSinceFreefallEnd.inMilliseconds}ms)");
          // --- TRIGGER FALL ACTION --- 
          onFallDetected();
          // ---------------------------
          _resetFallState(); // Reset after detecting a fall
        } else {
          // Impact occurred too long after freefall, reset
          if (kDebugMode) {
             _logger.d("Resetting: Impact occurred too late (${timeSinceFreefallEnd.inMilliseconds}ms after freefall end)");
          }
          _resetFallState();
        }
      } else {
        // Check if impact window has passed without high impact
        final timeSinceFreefallEnd = now.difference(_freefallEndTime!);
        if (timeSinceFreefallEnd > _impactWindow) {
           if (kDebugMode) {
             _logger.d("Resetting: No significant impact detected within ${_impactWindow.inSeconds}s of potential fall.");
           }
           _resetFallState();
        }
      }
    }
  }

  void _resetFallState() {
    _freefallStartTime = null;
    _freefallEndTime = null;
    _potentialFallDetected = false;
  }

  void dispose() {
    stopListening();
  }
}

