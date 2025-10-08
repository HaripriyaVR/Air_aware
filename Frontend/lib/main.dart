/*import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import './home.dart';
import 'theme.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // 🔐 Replace these values with your actual Firebase web app config
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyC7EWL7pfVBLPaKZ6rsX9DGH1zGC5ev3Qg",
        authDomain: "airaware-8d0f7.firebaseapp.com",
        projectId: "airaware-8d0f7",
        storageBucket: "airaware-8d0f7.firebasestorage.app",
        messagingSenderId: "169934755886",
        appId: "1:169934755886:web:978a4235bdaab1c24367bf",
        measurementId: "G-3VH5JVGP2K"
      ),
    );
  } else {
    // ✅ For Android/iOS, this uses google-services.json or GoogleService-Info.plist
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: AppTheme.lightTheme,
      home: const AQIDashboardPage(phone: '9999999999'), // or use const LoginScreen() from otpsent.dart
    );
  }
}*/

import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme.dart';
import 'home.dart'; // For AQIDashboardPage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // 🔐 Replace these values with your actual Firebase web app config
   await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyC7EWL7pfVBLPaKZ6rsX9DGH1zGC5ev3Qg",
        authDomain: "airaware-8d0f7.firebaseapp.com",
        projectId: "airaware-8d0f7",
        storageBucket: "airaware-8d0f7.firebasestorage.app",
        messagingSenderId: "169934755886",
        appId: "1:169934755886:web:978a4235bdaab1c24367bf",
        measurementId: "G-3VH5JVGP2K"
      ),
    ); 
  } else {
    // ✅ For Android/iOS
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Aware',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(), // 👈 Start with the splash screen
    );
  }
}

// --- 🌈 Splash Screen Widget ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;
  double _scale = 0.8;

  @override
  void initState() {
    super.initState();
    // Start animation
    Future.delayed(const Duration(milliseconds: 50), () {
      setState(() {
        _opacity = 1.0;
        _scale = 1.0;
      });
    });

    // Navigate after 3 seconds
    _navigateToDashboard();
  }

  Future<void> _navigateToDashboard() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, __, ___) => const AQIDashboardPage(phone: '9999999999'),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: Center(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOutQuad,
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(seconds: 1),
            curve: Curves.easeInOutQuad,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_queue, color: Colors.teal, size: 80),
                const SizedBox(height: 20),
                const Text(
                  'Air Aware',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.teal,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black12,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Breathe Easier.',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
