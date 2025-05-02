import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/routes.dart'; // Assuming routes are defined here
import '../../presentation/blocs/auth_bloc.dart'; // Assuming AuthBloc handles sign out
import '../../presentation/widgets/emergency_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _locationPermissionGranted = false;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962), // Default to Googleplex
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

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
    } else if (status.isPermanentlyDenied) {
      // Inform user they need to enable permissions in settings
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission permanently denied. Please enable it in app settings.')),
        );
      }
      // Optionally open app settings
      // openAppSettings();
    } else {
       if(mounted){
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Location permission denied.')),
         );
       }
    }
  }

  Future<void> _getCurrentLocationAndTrack() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _moveCameraToCurrentPosition();
      _startLocationTracking();
    } catch (e) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get current location: $e')),
        );
      }
    }
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update location if moved by 10 meters
    );
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
          });
          // Optionally move camera smoothly
          // _moveCameraToCurrentPosition(animate: true);
        }
      },
      onError: (error) {
         if(mounted){
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Location tracking error: $error')),
           );
         }
      }
    );
  }

  Future<void> _moveCameraToCurrentPosition({bool animate = false}) async {
    if (_currentPosition != null) {
      final GoogleMapController controller = await _mapController.future;
      final cameraUpdate = CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentPosition!,
          zoom: 16.0, // Zoom in closer when location is known
        ),
      );
      if (animate) {
        controller.animateCamera(cameraUpdate);
      } else {
        controller.moveCamera(cameraUpdate);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Safety App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings button pressed')),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: FutureBuilder<DocumentSnapshot>(
                future: user != null ? FirebaseFirestore.instance.collection('users').doc(user.uid).get() : null,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.exists) {
                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    return Text(userData['name'] ?? 'User Name');
                  } else if (user != null) {
                    return const Text('Loading name...');
                  } else {
                    return const Text('User Name');
                  }
                },
              ),
              accountEmail: Text(user?.email ?? 'user.email@example.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).platform == TargetPlatform.iOS ? Colors.blue : Colors.white,
                child: Text(
                  user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(fontSize: 40.0),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Map View'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
             ListTile(
              leading: const Icon(Icons.contacts_outlined),
              title: const Text('Emergency Contacts'),
              onTap: () {
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Navigate to Emergency Contacts (TODO)')),
                 );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
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
            Expanded(
              flex: 4,
              child: _locationPermissionGranted
                  ? GoogleMap(
                      mapType: MapType.normal,
                      initialCameraPosition: _initialCameraPosition,
                      onMapCreated: (GoogleMapController controller) {
                        if (!_mapController.isCompleted) {
                           _mapController.complete(controller);
                        }
                      },
                      myLocationEnabled: true, // Shows the blue dot for current location
                      myLocationButtonEnabled: true, // Button to center map on current location
                      markers: {
                        if (_currentPosition != null)
                          Marker(
                            markerId: const MarkerId('currentLocation'),
                            position: _currentPosition!,
                            infoWindow: const InfoWindow(title: 'My Location'),
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                          ),
                      },
                      // Optional: Add zoom controls, compass, etc.
                      // zoomControlsEnabled: true,
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Location permission is required to show the map.'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _requestLocationPermission,
                            child: const Text('Grant Permission'),
                          )
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const EmergencyButton(),
                   const SizedBox(height: 16),
                   Text(
                     'Tap the button above in case of emergency.',
                     textAlign: TextAlign.center,
                     style: Theme.of(context).textTheme.bodySmall,
                   )
                 ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

