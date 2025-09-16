import 'package:aqmapp/otpsent.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'background_design.dart'; // Import the new background design widget

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Add this stub to avoid errors
  void checkAndSendOtp() {
    // Implement OTP logic or leave empty for now
  }

  Future<void> registerUser() async {
    if (_formKey.currentState!.validate()) {
      final String name = _nameController.text.trim();
      final String phone = '+91${_phoneController.text.trim()}';

      try {
        // 🔍 Check if number is already registered
        final existingUser = await FirebaseFirestore.instance
            .collection('register')
            .where('phone', isEqualTo: phone)
            .get();

        if (existingUser.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❗ This number is already registered.')),
          );
          return;
        }

        // ✅ Register new user
        await FirebaseFirestore.instance.collection('register').add({
          'name': name,
          'phone': phone,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Registered successfully!')),
        );

        // 👉 Navigate to questionnaire page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Stack(
        children: [
          const BackgroundDesign(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name field (styled)
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Enter Name',
                            labelStyle: const TextStyle(color: Colors.green),
                            hintText: 'Full Name',
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
                        const SizedBox(height: 16),
                        // Phone number field (styled)
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => checkAndSendOtp(),
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
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Register button aligned at the bottom
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Register",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

