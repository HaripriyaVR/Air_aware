import 'package:aqmapp/home.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'otpverify.dart';
import 'register.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final String backendUrl = 'http://192.168.43.104:5000'; // Backend URL

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> checkAndSendOtp() async {
  String number = _phoneController.text.trim();

  if (!RegExp(r'^\d{10}$').hasMatch(number)) {
    showSnackbar("❌ Enter a valid 10-digit phone number");
    return;
  }

  String fullPhone = '+91$number';

  try {
    // Check Firestore if phone is registered
    final query = await FirebaseFirestore.instance
        .collection('register')
        .where('phone', isEqualTo: fullPhone)
        .get();

    if (query.docs.isEmpty) {
      showSnackbar("❌ This number is not registered.");
      return;
    }

    // Send OTP to backend
    final response = await http.post(
      Uri.parse('$backendUrl/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': fullPhone}),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      print("📌 Backend response: $result");

      if (result['success'] == true) {
        showSnackbar("✅ ${result['message']}");

        // Navigate to OTP Verification
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(phoneNumber: fullPhone),
          ),
        );
      } else {
        showSnackbar("❌ Failed: ${result['message']}");
      }
    } else {
      showSnackbar("❌ Server error: ${response.statusCode}");
    }
  } catch (e) {
    showSnackbar("❌ Error: $e");
  }
}



  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF0F8FF),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.home, color: Colors.black),
        onPressed: () {
          Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const AQIDashboardPage()),
  );
        },
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Welcome',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Air Quality Monitoring &\nAwareness System',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 30),

            // Phone Number Field
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                counterText: "",
                prefixText: '+91 ',
                labelText: 'Enter Phone Number',
                labelStyle: const TextStyle(color: Colors.green),
                hintText: '10-digit mobile number',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Signup Link
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                );
              },
              child: const Text(
                "Don't have an account? Please signup",
                style: TextStyle(
                  color: Colors.black54,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

            const Spacer(),

            // Proceed Button
            SizedBox(
              width: 250,
              child: ElevatedButton(
                onPressed: checkAndSendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "Proceed",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}
}