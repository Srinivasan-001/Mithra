import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:logger/logger.dart'; // Import Logger for better error logging
import 'package:flutter/foundation.dart'; // for kDebugMode

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>(); // Add form key for validation

  // Controllers for all fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContact1NameController = TextEditingController();
  final _emergencyContact1PhoneController = TextEditingController();
  final _emergencyContact2NameController = TextEditingController();
  final _emergencyContact2PhoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedGender;
  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

  final Logger _logger = Logger(); // Initialize logger
  bool _isLoading = false; // Add loading state

  Future<void> signUp() async {
    // Validate required fields (Email and Password)
    if (!_formKey.currentState!.validate()) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Please fix the errors in the form'),
             duration: Duration(seconds: 3),
           ),
         );
       }
      return;
    }

    // Optional: Add validation for other fields if needed (e.g., phone format)

    setState(() {
      _isLoading = true; // Start loading
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final gender = _selectedGender;
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final ec1Name = _emergencyContact1NameController.text.trim();
    final ec1Phone = _emergencyContact1PhoneController.text.trim();
    final ec2Name = _emergencyContact2NameController.text.trim();
    final ec2Phone = _emergencyContact2PhoneController.text.trim();

    try {
      // Create a new user in Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save all user data to Firestore
      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': name,
          'gender': gender,
          'email': email,
          'phone': phone,
          'address': address,
          'emergencyContacts': [
            {'name': ec1Name, 'phone': ec1Phone},
            {'name': ec2Name, 'phone': ec2Phone},
          ],
          'createdAt': Timestamp.now(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User registered successfully!'),
              duration: Duration(seconds: 3),
            ),
          );
          // Navigate to HomeScreen after successful registration
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
         throw Exception('User creation succeeded but user object is null.');
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered. Please log in or use a different email.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password is too weak. Please choose a stronger password.';
      } else if (e.code == 'invalid-email') {
         errorMessage = 'The email address is not valid.';
      } else {
        errorMessage = 'Sign-up failed: ${e.message}';
        if (kDebugMode) {
           _logger.e('FirebaseAuthException during sign up', error: e, stackTrace: StackTrace.current);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
       if (kDebugMode) {
         _logger.e('Error during sign up or Firestore save', error: e, stackTrace: stackTrace);
       }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
       if (mounted) {
         setState(() {
           _isLoading = false; // Stop loading regardless of outcome
         });
       }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContact1NameController.dispose();
    _emergencyContact1PhoneController.dispose();
    _emergencyContact2NameController.dispose();
    _emergencyContact2PhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form( // Wrap content in a Form widget
          key: _formKey,
          child: SingleChildScrollView( // Allow scrolling
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Your Account',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.name,
                  enabled: !_isLoading,
                  // No validator needed as it's not required
                ),
                const SizedBox(height: 16),

                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.wc),
                    border: OutlineInputBorder(),
                  ),
                  items: _genders.map((String gender) {
                    return DropdownMenuItem<String>(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: _isLoading ? null : (String? newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  },
                  // No validator needed
                ),
                const SizedBox(height: 16),

                // Email Field (Required)
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Number Field
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  enabled: !_isLoading,
                  // Optional: Add validator for phone format
                ),
                const SizedBox(height: 16),

                // Address Field
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.home),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.streetAddress,
                  maxLines: 3, // Allow multiple lines for address
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 24),

                // Emergency Contact 1
                const Text('Emergency Contact 1', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emergencyContact1NameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.name,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emergencyContact1PhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  enabled: !_isLoading,
                  // Optional: Add validator for phone format
                ),
                const SizedBox(height: 24),

                // Emergency Contact 2
                const Text('Emergency Contact 2', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emergencyContact2NameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.name,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emergencyContact2PhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  enabled: !_isLoading,
                  // Optional: Add validator for phone format
                ),
                const SizedBox(height: 24),

                // Password Field (Required)
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                    // Add suffix icon for password visibility toggle if needed
                  ),
                  obscureText: true,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Sign Up Button
                _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      onPressed: signUp,
                      child: const Text('Sign Up'),
                    ),
                const SizedBox(height: 16),

                // Login Navigation
                TextButton(
                  onPressed: _isLoading ? null : () {
                    Navigator.pop(context);
                  },
                  child: const Text('Already have an account? Log In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

