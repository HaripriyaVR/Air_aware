import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import './home.dart';


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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AQIDashboardPage(phone: '9999999999'), // or use const LoginScreen() from otpsent.dart
    );
  }
}
