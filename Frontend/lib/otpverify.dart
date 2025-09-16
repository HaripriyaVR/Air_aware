import 'profile.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'questions.dart';
import 'config.dart'; 

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String otpCode = "";

  // ✅ Use AppConfig instead of hardcoding IP
  final String _baseUrl = AppConfig.baseUrl;
  static const String _endpoint = '/api/verify-otp';

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
        Uri.parse("$_baseUrl$_endpoint"), // ✅ Dynamic URL
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phoneNumber.trim(),
          'otp': otpCode,
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
        showSnackbar(
            "❌ Verification failed: ${result['message'] ?? 'Invalid code'}");
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
      // -------------------body start here--------------------
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Stack(
            children: [
              // ---------------backgriund design----------------
               // White background
              Container(color: Colors.white),

              // Blue circle (top-left)
              Positioned(
                top: -80,
                left: -30,
                child: Container(
                  width: 377,
                  height: 358,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.blue.withOpacity(0.4), Colors.white.withOpacity(0)],
                      radius: 0.6,
                    ),
                  ),
                ),
              ),

              // Green circle (top-right)
              Positioned(
                top: -20,
                right: -10,
                child: Container(
                  width: 377,
                  height: 358,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.green.withOpacity(0.4), Colors.green.withOpacity(0)],
                      radius: 0.5,
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 260),
                    const Text(
                      "We are fetching your OTP on your number",
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.phoneNumber,
                            style: const TextStyle(fontFamily:'poppins', fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            "Change →",
                            style: TextStyle(color: Colors.black),
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
                        shape: PinCodeFieldShape.box,
                        fieldHeight: 50,
                        fieldWidth: 50,
                        borderRadius: BorderRadius.circular(20),
                        activeColor: Colors.green,
                        selectedColor: Colors.green,
                        inactiveColor: Colors.lightGreen,
                      ),
                      onChanged: (value) {
                        setState(() => otpCode = value);
                      },
                      onCompleted: (value) {
                        setState(() => otpCode = value);
                        if (!_isLoading) {
                          verifyOtp();
                        }
                      },
                    ),

                    const Spacer(),
                    // ------submit button----------------
                    SizedBox(
                      width: double.infinity,
                      height: 50,
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
                            : const Text("Submit",
                                style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      
      ),
      // -------------------body finish here--------------------
    );
  }
}
