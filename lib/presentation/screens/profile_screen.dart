import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  DocumentSnapshot? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      // Optionally navigate back to login if user is somehow null
      // Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    try {
      final docSnapshot = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (mounted) {
        setState(() {
          _userData = docSnapshot;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data: $e')),
        );
      }
    }
  }

  Widget _buildDetailItem(String label, String? value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value ?? 'Not provided',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactItem(Map<String, dynamic>? contactData, int index) {
    final name = contactData?['name'] as String?;
    final phone = contactData?['phone'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Contact ${index + 1}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
            const Divider(),
            _buildDetailItem('Name', name, Icons.person_outline),
            _buildDetailItem('Phone', phone, Icons.phone_outlined),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? data;
    List<dynamic>? emergencyContactsData;
    if (_userData != null && _userData!.exists) {
      data = _userData!.data() as Map<String, dynamic>;
      emergencyContactsData = data['emergencyContacts'] as List<dynamic>?;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null || data == null
              ? const Center(child: Text('Could not load user data.'))
              : RefreshIndicator(
                  onRefresh: _loadUserData, // Allow pull-to-refresh
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).primaryColorLight,
                          child: Text(
                            data['name']?.isNotEmpty == true ? data['name']![0].toUpperCase() : (data['email']?[0].toUpperCase() ?? 'U'),
                            style: TextStyle(fontSize: 40, color: Theme.of(context).primaryColorDark),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          data['name'] ?? 'User Name',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Center(
                        child: Text(
                          data['email'] ?? 'No email',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      _buildDetailItem('Gender', data['gender'], Icons.wc),
                      _buildDetailItem('Phone Number', data['phone'], Icons.phone),
                      _buildDetailItem('Address', data['address'], Icons.home_outlined),
                      const SizedBox(height: 16),
                      const Text(
                        'Emergency Contacts',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (emergencyContactsData != null && emergencyContactsData.isNotEmpty)
                        ...List.generate(
                          emergencyContactsData.length,
                          (index) => _buildEmergencyContactItem(emergencyContactsData![index] as Map<String, dynamic>?, index),
                        )
                      else
                        const Text('No emergency contacts provided.'),
                      const SizedBox(height: 24),
                      // Optional: Add Edit Profile Button
                      // ElevatedButton.icon(
                      //   icon: const Icon(Icons.edit),
                      //   label: const Text('Edit Profile'),
                      //   onPressed: () {
                      //     // Navigate to an edit profile screen
                      //   },
                      // ),
                    ],
                  ),
                ),
    );
  }
}

