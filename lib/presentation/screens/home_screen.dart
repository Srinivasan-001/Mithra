import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:logger/logger.dart'; // Added for logging
import 'package:twilio_flutter/twilio_flutter.dart'; // Added for SMS
import 'dart:math'; // Added for min/max

import '../../core/constants/routes.dart';
import '../../presentation/blocs/auth_bloc.dart';
import '../../presentation/widgets/emergency_button.dart';
import '../../core/config/twilio_config.dart';
import '../../core/services/fall_detection_service.dart'; // Import Fall Detection Service

const String googleApiKey = "AIzaSyCq2s28kdJlvauO88jHCwqjW2vwrEAmsA8";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Logger _logger = Logger(); // Logger for debugging
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _locationPermissionGranted = false;

  // Routing
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  final PolylinePoints _polylinePoints = PolylinePoints();
  LatLng? _originPosition;
  LatLng? _destinationPosition;
  bool _useCurrentLocationAsOrigin = true; // Toggle for using current location or custom origin

  // Fall Detection
  late FallDetectionService _fallDetectionService;
  bool _isFallDetectionActive =
      true; // Control activation via UI later if needed
  bool _isSendingFallAlert = false; // State for automatic alert sending

  // Twilio
  late TwilioFlutter twilioFlutter;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();

    // Initialize Twilio
    twilioFlutter = TwilioFlutter(
      accountSid: twilioAccountSid,
      authToken: twilioAuthToken,
      twilioNumber: twilioPhoneNumber,
    );

    // Initialize and start Fall Detection Service
    _fallDetectionService = FallDetectionService(
      onFallDetected: _handleFallDetected,
    );
    if (_isFallDetectionActive) {
      _fallDetectionService.startListening();
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _fallDetectionService.dispose(); // Dispose fall detection service
    super.dispose();
  }

  // --- Location & Map Methods (Existing + Minor Updates) ---

  Future<void> _requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    if (status.isGranted) {
      setState(() {
        _locationPermissionGranted = true;
      });
      _getCurrentLocationAndTrack();
    } else {
      String message =
          status.isPermanentlyDenied
              ? 'Location permission permanently denied. Please enable it in app settings.'
              : 'Location permission denied.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _getCurrentLocationAndTrack() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });
      _moveCameraToCurrentPosition();
      _startLocationTracking();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get current location: $e')),
        );
      }
    }
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            _updateMarkers();
          });
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location tracking error: $error')),
          );
        }
      },
    );
  }

  Future<void> _moveCameraToCurrentPosition({bool animate = false}) async {
    if (_currentPosition != null) {
      final GoogleMapController controller = await _mapController.future;
      final cameraUpdate = CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentPosition!, zoom: 16.0),
      );
      if (animate) {
        controller.animateCamera(cameraUpdate);
      } else {
        controller.moveCamera(cameraUpdate);
      }
    }
  }

  // --- Routing Methods (Updated for Origin Support) ---

  LatLng? _parseCoordinates(String input) {
    try {
      final parts = input.split(",");
      if (parts.length == 2) {
        return LatLng(
          double.parse(parts[0].trim()),
          double.parse(parts[1].trim()),
        );
      }
    } catch (_) {}
    return null;
  }

  void _useCurrentLocation() {
    setState(() {
      _useCurrentLocationAsOrigin = true;
      _originController.clear();
      _updateMarkers();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Using current location as starting point')),
    );
  }

  Future<void> _getRoute() async {
    // Check if we have destination
    if (_destinationController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a destination location.'),
          ),
        );
      }
      return;
    }

    // Determine origin point
    LatLng? originCoords;
    if (_useCurrentLocationAsOrigin) {
      // Use current location as origin
      originCoords = _currentPosition;
      if (originCoords == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current location not available. Please enter a starting point manually.'),
            ),
          );
        }
        return;
      }
    } else {
      // Use entered origin
      if (_originController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a starting point.'),
            ),
          );
        }
        return;
      }
      originCoords = _parseCoordinates(_originController.text);
      if (originCoords == null) {
        // For simplicity, we're assuming coordinates entry. In a real app, you'd use geocoding.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid starting point format. Please use latitude,longitude'),
            ),
          );
        }
        return;
      }
    }

    // Parse destination coordinates
    final destinationCoords = _parseCoordinates(_destinationController.text);
    if (destinationCoords == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid destination format. Please use latitude,longitude'),
          ),
        );
      }
      return;
    }

    setState(() {
      _originPosition = originCoords;
      _destinationPosition = destinationCoords;
      _updateMarkers();
    });

    try {
      PointLatLng origin = PointLatLng(
        originCoords.latitude,
        originCoords.longitude,
      );
      PointLatLng destination = PointLatLng(
        destinationCoords.latitude,
        destinationCoords.longitude,
      );

      final request = PolylineRequest(
        origin: origin,
        destination: destination,
        mode: TravelMode.driving,
      );

      PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: googleApiKey,
        request: request,
      );

      if (result.points.isNotEmpty) {
        _polylineCoordinates.clear();
        for (final point in result.points) {
          _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId("route"),
              color: Colors.blue,
              points: _polylineCoordinates,
              width: 5,
            ),
          );
        });
        _adjustCameraToFitRoute();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Directions not found: ${result.errorMessage ?? 'Unknown error'}",
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error getting directions: $e")));
      }
    }
  }

  void _updateMarkers() {
    _markers.clear();
    
    // Add current location marker (always)
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId("currentLocation"),
          position: _currentPosition!,
          infoWindow: const InfoWindow(title: "My Current Location"),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    
    // Add origin marker (if custom origin is set)
    if (!_useCurrentLocationAsOrigin && _originPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId("originLocation"),
          position: _originPosition!,
          infoWindow: const InfoWindow(title: "Starting Point"),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }
    
    // Add destination marker
    if (_destinationPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId("destinationLocation"),
          position: _destinationPosition!,
          infoWindow: const InfoWindow(title: "Destination"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  Future<void> _adjustCameraToFitRoute() async {
    LatLng? startPoint = _useCurrentLocationAsOrigin ? _currentPosition : _originPosition;
    
    if (startPoint == null || _destinationPosition == null || _polylineCoordinates.isEmpty) {
      return;
    }
    
    final GoogleMapController controller = await _mapController.future;
    LatLngBounds bounds;
    
    // Calculate bounds to fit both points
    double southWestLat = min(
      startPoint.latitude,
      _destinationPosition!.latitude,
    );
    double southWestLng = min(
      startPoint.longitude,
      _destinationPosition!.longitude,
    );
    double northEastLat = max(
      startPoint.latitude,
      _destinationPosition!.latitude,
    );
    double northEastLng = max(
      startPoint.longitude,
      _destinationPosition!.longitude,
    );
    
    // Add padding to bounds
    southWestLat -= 0.01;
    southWestLng -= 0.01;
    northEastLat += 0.01;
    northEastLng += 0.01;
    
    bounds = LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );
    
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  // --- Fall Detection Callback & Alert Logic (Unchanged) ---

  void _handleFallDetected() {
    // Prevent triggering multiple alerts simultaneously
    if (_isSendingFallAlert) return;

    _logger.i(
      "Fall detected by service! Initiating automatic emergency alert.",
    );
    setState(() {
      _isSendingFallAlert = true;
    });

    // Show immediate feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 16),
            Text('Fall Detected! Sending Alert...'),
          ],
        ),
        duration: Duration(minutes: 1), // Keep visible
        backgroundColor: Colors.red,
      ),
    );

    // Trigger the SMS sending logic (similar to EmergencyButton)
    _sendEmergencySMS("Fall detected for");
  }

  Future<void> _sendEmergencySMS(String alertPrefix) async {
    // Ensure location is available
    LatLng? locationToSend = _currentPosition;
    if (locationToSend == null) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        locationToSend = LatLng(position.latitude, position.longitude);
        _logger.i("Fetched fresh location for alert: $locationToSend");
      } catch (e) {
        _logger.e("Could not get location for fall alert: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to get location for alert: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (mounted) {
          setState(() {
            _isSendingFallAlert = false;
          });
        }
        return;
      }
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final locationLink =
          "https://www.google.com/maps?q=${locationToSend.latitude},${locationToSend.longitude}";

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (!userDoc.exists) throw Exception("User data not found.");

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] as String? ?? 'User';
      final emergencyContactsData =
          userData['emergencyContacts'] as List<dynamic>?;

      if (emergencyContactsData == null || emergencyContactsData.isEmpty) {
        throw Exception("No emergency contacts found.");
      }

      final messageBody =
          "Emergency Alert! $alertPrefix $userName needs help. Location: $locationLink";

      int successCount = 0;
      List<String> failedContacts = [];

      for (var contactData in emergencyContactsData) {
        if (contactData is Map<String, dynamic>) {
          final contactPhone = contactData['phone'] as String?;
          final contactName = contactData['name'] as String? ?? 'Contact';

          if (contactPhone != null && contactPhone.trim().isNotEmpty) {
            try {
              String formattedPhone = contactPhone.trim();
              if (!formattedPhone.startsWith('+')) {
                _logger.w(
                  "Phone for $contactName ($formattedPhone) might not be E.164. SMS might fail.",
                );
                // Basic attempt to fix for US/Canada - revise for broader use
                // if (formattedPhone.length == 10) formattedPhone = '+1$formattedPhone';
              }
              _logger.i("Sending SMS to $contactName ($formattedPhone)");
              await twilioFlutter.sendSMS(
                toNumber: formattedPhone,
                messageBody: messageBody,
              );
              successCount++;
            } catch (smsError) {
              _logger.e(
                "Failed SMS to $contactName ($contactPhone): $smsError",
              );
              failedContacts.add(contactName);
            }
          } else {
            _logger.w("Skipping $contactName: missing phone.");
            failedContacts.add("$contactName (no number)");
          }
        }
      }

      // Final Feedback
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      if (successCount > 0 && failedContacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency Alert Sent Successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (successCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Alert sent to $successCount contacts. Failed for: ${failedContacts.join(', ')}',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 8),
            ),
          );
        }
      } else {
        throw Exception(
          "Failed to send SMS to any contacts. Failures: ${failedContacts.join(', ')}",
        );
      }
    } catch (e) {
      _logger.e("Error sending emergency SMS: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send alert: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingFallAlert = false; // Reset state regardless of outcome
        });
      }
    }
  }

  // --- Build Method (Updated with Origin Input) ---

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Safety App"),
        // Add toggle for fall detection later if needed
        // actions: [ Switch(value: _isFallDetectionActive, onChanged: (value) {...}) ],
      ),
      drawer: Drawer(
        /* ... existing drawer code ... */
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: FutureBuilder<DocumentSnapshot>(
                future:
                    user != null
                        ? FirebaseFirestore.instance
                            .collection("users")
                            .doc(user.uid)
                            .get()
                        : null,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData &&
                      snapshot.data!.exists) {
                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    return Text(userData["name"] ?? "User Name");
                  } else {
                    return Text(user != null ? "Loading name..." : "User Name");
                  }
                },
              ),
              accountEmail: Text(user?.email ?? "user.email@example.com"),
              currentAccountPicture: CircleAvatar(
                backgroundColor:
                    Theme.of(context).platform == TargetPlatform.iOS
                        ? Colors.blue
                        : Colors.white,
                child: Text(
                  user?.email?.substring(0, 1).toUpperCase() ?? "U",
                  style: const TextStyle(fontSize: 40.0),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text("Map View"),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts_outlined),
              title: const Text("Emergency Contacts"),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Navigate to Emergency Contacts (TODO)"),
                  ),
                );
              },
            ),
            // Add Fall Detection Toggle Here?
            ListTile(
              leading: Icon(
                _isFallDetectionActive ? Icons.sensors : Icons.sensors_off,
              ),
              title: Text(
                "Fall Detection (${_isFallDetectionActive ? 'Active' : 'Inactive'})",
              ),
              trailing: Switch(
                value: _isFallDetectionActive,
                onChanged: (value) {
                  setState(() {
                    _isFallDetectionActive = value;
                    if (_isFallDetectionActive) {
                      _fallDetectionService.startListening();
                    } else {
                      _fallDetectionService.stopListening();
                    }
                  });
                  Navigator.pop(context); // Close drawer after toggle
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthBloc>().add(SignOutRequested());
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Route Planning Inputs
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // Origin Input Row
                  Row(
                    children: [
                      Checkbox(
                        value: _useCurrentLocationAsOrigin,
                        onChanged: (value) {
                          setState(() {
                            _useCurrentLocationAsOrigin = value ?? true;
                          });
                        },
                      ),
                      const Text("Use current location"),
                      const SizedBox(width: 8),
                      _useCurrentLocationAsOrigin 
                          ? Expanded(
                              child: const Text(
                                "Using your current location as starting point",
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            )
                          : Expanded(
                              child: TextField(
                                controller: _originController,
                                decoration: const InputDecoration(
                                  hintText: "Starting point (lat,lng)",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                ),
                                enabled: !_useCurrentLocationAsOrigin,
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Destination Input Row
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _destinationController,
                          decoration: const InputDecoration(
                            hintText: "Destination (lat,lng)",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.directions),
                        label: const Text("Route"),
                        onPressed: _getRoute,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Map View
            Expanded(
              flex: 4,
              child:
                  _locationPermissionGranted
                      ? GoogleMap(
                        mapType: MapType.normal,
                        initialCameraPosition: _initialCameraPosition,
                        onMapCreated: (GoogleMapController controller) {
                          if (!_mapController.isCompleted) {
                            _mapController.complete(controller);
                          }
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        markers: _markers,
                        polylines: _polylines,
                      )
                      : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Location permission is required."),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _requestLocationPermission,
                              child: const Text("Grant Permission"),
                            ),
                          ],
                        ),
                      ),
            ),
            // Emergency Button Area
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pass the _sendEmergencySMS function to the button
                  EmergencyButton(
                    onManualTrigger:
                        () => _sendEmergencySMS("Manual alert for"),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Tap button for manual alert. Fall detection is ${_isFallDetectionActive ? 'ACTIVE' : 'INACTIVE'}.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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