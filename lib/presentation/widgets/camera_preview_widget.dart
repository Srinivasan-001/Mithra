import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class CameraPreviewWidget extends StatefulWidget {
  const CameraPreviewWidget({super.key});

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  Timer? _reconnectTimer;
  bool _isConnected = false;
  String _errorMessage = '';
  Interpreter? _interpreter;

  @override
  void initState() {
    super.initState();
    _connectToCamera();
    _initializeTFLite();
  }

  Future<void> _initializeTFLite() async {
    try {
      // Load TFLite model for gender classification
      _interpreter = await Interpreter.fromAsset('assets/models/gender_classifier.tflite');
      debugPrint('TFLite model loaded successfully');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load AI model: $e';
        });
      }
    }
  }

  Future<void> _connectToCamera() async {
    try {
      // Replace with your ESP32's HTTP URL
      final url = 'http://192.168.156.198/';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Handle MJPEG stream or base64 encoded frame
        final message = response.body;
        final decodedFrame = base64Decode(message);

        // Process the frame with TFLite model
        _processFrameWithTFLite(decodedFrame);

        if (mounted) {
          setState(() {
            _isConnected = true;
            _errorMessage = '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _errorMessage = 'Failed to connect: ${response.statusCode}';
          });
        }
        _scheduleReconnect();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _errorMessage = 'Failed to connect: $e';
        });
      }
      _scheduleReconnect();
    }
  }

  void _processFrameWithTFLite(Uint8List frame) {
    try {
      // TODO: Preprocess the frame (e.g., resize, normalize) before passing it to the model
      // Example: Convert the frame to a format compatible with the TFLite model
      // final input = preprocessFrame(frame);

      // Run inference
      // final output = List.filled(outputSize, 0).reshape(outputShape);
      // _interpreter?.run(input, output);

      // TODO: Handle the output from the model
      debugPrint('Frame processed with TFLite model');
    } catch (e) {
      debugPrint('Error processing frame with TFLite: $e');
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _connectToCamera();
      }
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          if (_isConnected)
            const Center(
              child: Text(
                'Camera Preview\n(TODO: Implement MJPEG rendering)',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage.isEmpty
                        ? 'Connecting to camera...'
                        : _errorMessage,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isConnected ? 'Connected' : 'Disconnected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}