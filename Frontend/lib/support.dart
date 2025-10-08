
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ for login state
import 'background_design.dart'; // ✅ new background design

class SupportPage extends StatefulWidget {
  final String? phone; // ✅ to keep navigation consistent
  const SupportPage({super.key, this.phone});

  @override
  _SupportPageState createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _caseController = TextEditingController();

  bool _isLoading = false;
  int _selectedIndex = 3; // ✅ default to Profile
  bool isLoggedIn = false; // ✅ default false
  String? phoneNumber;

  @override
  void initState() {
    super.initState();
    _loadLoginState().then((_) {
    setState(() {
      _selectedIndex = isLoggedIn ? 4 : 3; // ✅ set Menu as selected
    });
  });
  }

  Future<void> _loadLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
      phoneNumber = prefs.getString("phone"); // ✅ if you stored phone at login
    });
  }

  
  // 🔹 Submit Support Case
  Future<void> _submitSupportCase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('support').add({
        'email': _emailController.text.trim(),
        'case': _caseController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _emailController.clear();
      _caseController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Your support request has been submitted."),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to submit: $e")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context){
    final menuIndex = isLoggedIn ? 4 : 3;
    return Scaffold(
      backgroundColor: Colors.grey[50],

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const BackgroundDesign(),
              const SizedBox(height: 200),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "We’re here to help 💬",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tell us your issue and we’ll get back to you soon.",
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.teal),
                        hintText: "Enter your email",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Email is required";
                        }
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                        if (!emailRegex.hasMatch(value)) {
                          return "Enter a valid email address";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Case Field
                    TextFormField(
                      controller: _caseController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.report_problem_outlined, color: Colors.teal),
                        hintText: "Describe your issue...",
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your issue";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        onPressed: _isLoading ? null : _submitSupportCase,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "Submit Request",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,fontStyle: FontStyle.normal,color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      
    );
  }
}
