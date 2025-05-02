import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

// Events
abstract class MonitoringEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class PeopleDetected extends MonitoringEvent {
  final int menCount;
  final List<double> detectionConfidences;

  PeopleDetected({
    required this.menCount,
    required this.detectionConfidences,
  });

  @override
  List<Object?> get props => [menCount, detectionConfidences];
}

class MotionDetected extends MonitoringEvent {
  final AccelerometerEvent accelerometer;
  final GyroscopeEvent gyroscope;

  MotionDetected({
    required this.accelerometer,
    required this.gyroscope,
  });

  @override
  List<Object?> get props => [accelerometer, gyroscope];
}

class StartMonitoring extends MonitoringEvent {}

class StopMonitoring extends MonitoringEvent {}

// States
abstract class MonitoringState extends Equatable {
  @override
  List<Object?> get props => [];
}

class MonitoringInitial extends MonitoringState {}

class MonitoringActive extends MonitoringState {
  final int detectedMenCount;
  final bool isSurrounded;
  final bool isInDanger;
  final String safetyStatus;
  final DateTime lastUpdate;

  MonitoringActive({
    required this.detectedMenCount,
    required this.isSurrounded,
    required this.isInDanger,
    required this.safetyStatus,
    required this.lastUpdate,
  });

  @override
  List<Object?> get props => [
        detectedMenCount,
        isSurrounded,
        isInDanger,
        safetyStatus,
        lastUpdate,
      ];
}

class MonitoringError extends MonitoringState {
  final String message;

  MonitoringError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class MonitoringBloc extends Bloc<MonitoringEvent, MonitoringState> {
  static const int dangerThreshold = 3; // Number of men that triggers danger state
  static const double fallThreshold = 20.0; // G-force threshold for fall detection

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  MonitoringBloc() : super(MonitoringInitial()) {
    on<StartMonitoring>(_onStartMonitoring);
    on<StopMonitoring>(_onStopMonitoring);
    on<PeopleDetected>(_onPeopleDetected);
    on<MotionDetected>(_onMotionDetected);
  }

  Future<void> _onStartMonitoring(
    StartMonitoring event,
    Emitter<MonitoringState> emit,
  ) async {
    try {
      _startSensorMonitoring();
      emit(MonitoringActive(
        detectedMenCount: 0,
        isSurrounded: false,
        isInDanger: false,
        safetyStatus: 'Safe',
        lastUpdate: DateTime.now(),
      ));
    } catch (e) {
      emit(MonitoringError('Failed to start monitoring: $e'));
    }
  }

  Future<void> _onStopMonitoring(
    StopMonitoring event,
    Emitter<MonitoringState> emit,
  ) async {
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    emit(MonitoringInitial());
  }

  Future<void> _onPeopleDetected(
    PeopleDetected event,
    Emitter<MonitoringState> emit,
  ) async {
    if (state is MonitoringActive) {
      final bool isInDanger = event.menCount >= dangerThreshold;
      final bool isSurrounded = _checkIfSurrounded(event.detectionConfidences);

      emit(MonitoringActive(
        detectedMenCount: event.menCount,
        isSurrounded: isSurrounded,
        isInDanger: isInDanger,
        safetyStatus: _determineSafetyStatus(isInDanger, isSurrounded),
        lastUpdate: DateTime.now(),
      ));
    }
  }

  Future<void> _onMotionDetected(
    MotionDetected event,
    Emitter<MonitoringState> emit,
  ) async {
    if (state is MonitoringActive) {
      final double acceleration = _calculateTotalAcceleration(event.accelerometer);
      final bool isFallDetected = acceleration > fallThreshold;

      if (isFallDetected) {
        emit(MonitoringActive(
          detectedMenCount: (state as MonitoringActive).detectedMenCount,
          isSurrounded: (state as MonitoringActive).isSurrounded,
          isInDanger: true,
          safetyStatus: 'Fall Detected!',
          lastUpdate: DateTime.now(),
        ));
      }
    }
  }

  void _startSensorMonitoring() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final gyroEvent = _lastGyroEvent;
      if (gyroEvent != null) {
        add(MotionDetected(
          accelerometer: event,
          gyroscope: gyroEvent,
        ));
      }
    });

    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      _lastGyroEvent = event;
    });
  }

  GyroscopeEvent? _lastGyroEvent;

  double _calculateTotalAcceleration(AccelerometerEvent event) {
    return (event.x * event.x + event.y * event.y + event.z * event.z).abs();
  }

  bool _checkIfSurrounded(List<double> detectionConfidences) {
    // Basic logic: more than 3 people with high confidence (> 0.7)
    int significantDetections = detectionConfidences
        .where((confidence) => confidence > 0.7)
        .length;
    return significantDetections >= 3;
  }

  String _determineSafetyStatus(bool isInDanger, bool isSurrounded) {
    if (isInDanger && isSurrounded) return 'High Risk!';
    if (isInDanger) return 'Warning!';
    if (isSurrounded) return 'Caution';
    return 'Safe';
  }

  @override
  Future<void> close() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    return super.close();
  }
}
