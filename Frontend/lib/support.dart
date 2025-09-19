import 'package:aqmapp/livegas.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // ✅ for login state
import 'home.dart';
import 'map.dart';
import 'profile.dart';
import 'forecast.dart';
import 'config.dart';
import 'bottom_nav.dart';
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
  int _selectedIndex = 0;
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

  // 🔹 Menu Options BottomSheet
  /*void _showMenuOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('AQI Forecast'),
              onTap: () async {
                Navigator.pop(bottomSheetContext);
                try {
                  Map<String, dynamic> forecastData = {
                    "forecast": [],
                    "updated_at": DateTime.now().toString()
                  };
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForecastDataPage(),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to load forecast: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Support'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupportPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }*/

  // 🔹 Build UI
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
                        color: Colors.blue,
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
                        prefixIcon: const Icon(Icons.report_problem_outlined, color: Colors.blue),
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
                          backgroundColor: Colors.green,
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

      // Bottom Nav
      /*bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        isLoggedIn: isLoggedIn,
        phone: widget.phone,
        showMenu: _showMenuOptions,
        onIndexChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),*/
    );
  }
}
