import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // Import Material package for Scaffold
import 'home_screen.dart'; // Import HomeScreen
import 'login_screen.dart'; // Import LoginScreen

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Handle loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Handle error state
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'An error occurred. Please try again later.',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }

          // Handle authenticated state
          if (snapshot.hasData) {
            return const HomeScreen(); // Navigate to HomeScreen if user is logged in
          }

          // Handle unauthenticated state
          return const LoginScreen(); // Navigate to LoginScreen if user is not logged in
        },
      ),
    );
  }
}