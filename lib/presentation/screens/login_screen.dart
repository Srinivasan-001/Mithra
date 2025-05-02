import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart'; // Import Logger
import 'package:flutter/foundation.dart'; // for kDebugMode
import '../../core/constants/routes.dart'; // Ensure this import exists for navigation
import 'sign_up_screen.dart'; // Import the Sign-Up Screen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final Logger _logger = Logger(); // Initialize logger
  bool _isLoading = false; // Add loading state

  Future<void> signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email and password cannot be empty'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Basic email validation
    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email)) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid email address'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Navigate to HomeScreen on successful login
      if (mounted) {
        // Clear navigation stack and go to home
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        // Combine common login errors for simplicity
        errorMessage = 'Invalid email or password. Please try again.';
      } else if (e.code == 'invalid-email') {
         errorMessage = 'The email address format is invalid.';
      } else if (e.code == 'user-disabled') {
         errorMessage = 'This user account has been disabled.';
      } else {
        errorMessage = 'Login failed. Please try again later.'; // Generic error for others
        if (kDebugMode) {
           _logger.e('FirebaseAuthException during sign in', error: e, stackTrace: StackTrace.current);
        }
      }

      // Show error message in a SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4), // Slightly longer duration for errors
            backgroundColor: Colors.redAccent, // Indicate error state
          ),
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
         _logger.e('Error during sign in', error: e, stackTrace: stackTrace);
      }
      // Handle any other errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.redAccent,
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            color: Colors.white,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Center( // Center content
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Keep the existing header/logo section
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE3F2FD),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: const Icon(
                          Icons.security,
                          size: 80,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Shield Guardian',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome back! Sign in to continue.', // Updated subtitle
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 48),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading, // Disable field when loading
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                          // Add suffix icon for password visibility toggle if needed
                        ),
                        obscureText: true,
                        enabled: !_isLoading, // Disable field when loading
                      ),
                      const SizedBox(height: 48),
                      _isLoading
                        ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                        : ElevatedButton.icon(
                            onPressed: signIn, // Directly call signIn
                            icon: const Icon(Icons.login),
                            label: const Text('Sign in'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isLoading ? null : () {
                          // Navigate to SignUpScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: const Text('Don\'t have an account? Sign Up'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
