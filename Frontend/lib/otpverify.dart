import 'profile.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'questions.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String otpCode = "";
  final String backendUrl = 'http://192.168.43.104:5000';
  bool _isLoading = false;

  Future<void> verifyOtp() async {
    if (otpCode.length < 6) {
      showSnackbar("❌ Please enter the full 6-digit OTP.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("🔹 Sending OTP verification request...");
      debugPrint("Phone: ${widget.phoneNumber.trim()} | Code: $otpCode");

      final response = await http.post(
        Uri.parse('$backendUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
  'phone': widget.phoneNumber.trim(),
  'otp': otpCode,   // ✅ fixed key
}),
      );

      debugPrint("🔹 Response status: ${response.statusCode}");
      debugPrint("🔹 Response body: ${response.body}");

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        showSnackbar("✅ ${result['message']}");

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('phone', widget.phoneNumber.trim());

        if (result.containsKey('token')) {
          await prefs.setString('token', result['token']);
        }

        // 🔹 Firestore check for questionnaire
        final qSnap = await FirebaseFirestore.instance
            .collection('questionnaire')
            .where('phone', isEqualTo: widget.phoneNumber.trim())
            .limit(1)
            .get();

        debugPrint("Firestore docs found: ${qSnap.docs.length}");

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => qSnap.docs.isNotEmpty
                ? ProfilePage(phone: widget.phoneNumber.trim())
                : QuestionnairePage(phone: widget.phoneNumber.trim()),
          ),
          (route) => false,
        );
      } else {
        showSnackbar("❌ Verification failed: ${result['message'] ?? 'Invalid code'}");
      }
    } catch (e) {
      showSnackbar("❌ Network or server error: $e");
      debugPrint("Exception: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void showSnackbar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text(
                "We are fetching your OTP on your number",
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.phoneNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "Change →",
                      style: TextStyle(color: Colors.green),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 40),

              PinCodeTextField(
                appContext: context,
                length: 6,
                keyboardType: TextInputType.number,
                autoFocus: true,
                animationType: AnimationType.scale,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.circle,
                  fieldHeight: 50,
                  fieldWidth: 50,
                  activeColor: Colors.green,
                  selectedColor: Colors.green,
                  inactiveColor: Colors.grey,
                ),
                onChanged: (value) {
                  setState(() => otpCode = value);
                },
              ),

              const Spacer(),

              SizedBox(
                width: 250,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Submit", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
