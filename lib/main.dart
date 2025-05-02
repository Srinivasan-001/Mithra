import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mithra/core/constants/theme.dart';
import 'package:mithra/data/repositories/auth_repository.dart';
import 'package:mithra/presentation/blocs/auth_bloc.dart';
import 'package:mithra/presentation/screens/login_screen.dart';
import 'package:mithra/presentation/screens/home_screen.dart';
import 'package:mithra/presentation/screens/sign_up_screen.dart'; // Import Sign-Up Screen

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Starting app initialization');
  
  await Firebase.initializeApp();
  
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter error: ${details.toString()}');
    FlutterError.presentError(details);
  };
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('Building MyApp');
    return RepositoryProvider(
      create: (context) => AuthRepository(),
      child: BlocProvider(
        create: (context) => AuthBloc(
          authRepository: context.read<AuthRepository>(),
        )..add(AuthCheckRequested()),
        child: MaterialApp(
          title: 'Shield Guardian',
          debugShowCheckedModeBanner: false, // Disable the debug banner
          theme: AppTheme.lightTheme,
          initialRoute: '/', // Set the initial route
          routes: {
            '/': (context) => BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    debugPrint('Auth state: $state');
                    if (state is AuthLoading) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    } else if (state is Authenticated) {
                      return const HomeScreen();
                    } else if (state is Unauthenticated) {
                      return const LoginScreen();
                    }
                    return const Scaffold(
                      body: Center(child: Text('Unexpected state')),
                    );
                  },
                ),
            '/home': (context) => const HomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignUpScreen(), // Added Sign-Up Screen route
          },
          onUnknownRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => const Scaffold(
                body: Center(
                  child: Text('Page not found'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}