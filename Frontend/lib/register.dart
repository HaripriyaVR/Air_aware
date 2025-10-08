/*
import 'package:aqmapp/otpsent.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'background_design.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool loading = true;
  String? docId; // Firestore document id for update

  @override
  void initState() {
    super.initState();
    _loadPhoneFromPrefs();
  }

  Future<void> _loadPhoneFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPhone = prefs.getString('phone');
    if (storedPhone != null && storedPhone.isNotEmpty) {
      _loadUserData(storedPhone);
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _loadUserData(String phone) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('register')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      setState(() {
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone']?.replaceFirst('+91', '') ?? '';
        docId = snapshot.docs.first.id;
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String name = _nameController.text.trim();
    final String phone = '+91${_phoneController.text.trim()}';

    try {
      if (docId != null) {
        // Update existing user
        await FirebaseFirestore.instance
            .collection('register')
            .doc(docId)
            .update({'name': name, 'phone': phone});

        // Save updated phone in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone', phone);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Updated successfully!')),
        );
      } else {
        // Check if phone already exists
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

        // Register new user
        await FirebaseFirestore.instance.collection('register').add({
          'name': name,
          'phone': phone,
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone', phone);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Registered successfully!')),
        );
      }

      // Navigate to login/OTP page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

 @override
Widget build(BuildContext context) {
  if (loading) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  final isUpdateMode = docId != null;

  return Scaffold(
    appBar: AppBar(
      title: Text(isUpdateMode ? "Update Account" : "Register"),
      backgroundColor: Colors.teal,
    ),
    body: SafeArea(
      child: Stack(
        children: [
          const BackgroundDesign(),
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(), // dismiss keyboard
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Enter Name',
                            labelStyle: const TextStyle(color: Colors.teal),
                            hintText: 'Full Name',
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                  color: Colors.teal, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty ||
                                value.trim().length != 10) {
                              return 'Enter a valid 10-digit phone number';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            counterText: "",
                            prefixText: '+91 ',
                            labelText: 'Enter Phone Number',
                            labelStyle: const TextStyle(color: Colors.teal),
                            hintText: '10-digit mobile number',
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                  color: Colors.teal, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              isUpdateMode ? "Update" : "Register",
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white),
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
        ],
      ),
    ),
  );
}
}*/
import 'package:aqmapp/otpsent.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'background_design.dart';



class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool loading = true;
  String? docId; // Firestore document id for update

  @override
  void initState() {
    super.initState();
    _loadPhoneFromPrefs();
  }

  Future<void> _loadPhoneFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPhone = prefs.getString('phone');
    if (storedPhone != null && storedPhone.isNotEmpty) {
      _loadUserData(storedPhone);
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _loadUserData(String phone) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('register')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      setState(() {
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone']?.replaceFirst('+91', '') ?? '';
        docId = snapshot.docs.first.id;
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String name = _nameController.text.trim();
    final String phone = '+91${_phoneController.text.trim()}';

    try {
      if (docId != null) {
        // Update existing user
        await FirebaseFirestore.instance
            .collection('register')
            .doc(docId)
            .update({'name': name, 'phone': phone});

        // Save updated phone in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone', phone);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Updated successfully!')),
        );
      } else {
        // Check if phone already exists
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

        // Register new user
        await FirebaseFirestore.instance.collection('register').add({
          'name': name,
          'phone': phone,
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone', phone);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Registered successfully!')),
        );
      }

      // Navigate to login/OTP page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Helper Widget for modern TextFields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    int? maxLength,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      textInputAction: textInputAction,
      validator: validator,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        counterText: "",
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: Icon(icon, color: Colors.teal.shade600),
        labelStyle: TextStyle(color: Colors.teal.shade600),
        hintStyle: TextStyle(color: Colors.grey.shade400),
        fillColor: Colors.teal.shade50.withOpacity(0.5),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
        // Use borderSide: BorderSide.none with filled: true for a clean look
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.teal.shade700, width: 2), // Highlight focus
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    final isUpdateMode = docId != null;

    return Scaffold(
      // 1. Minimal AppBar
      appBar: AppBar(
        title: Text(
          isUpdateMode ? "Update Profile" : "Create Account", 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent, // Transparent background
        elevation: 0, // No shadow
        iconTheme: const IconThemeData(color: Colors.black87), // Dark icons
      ),
      extendBodyBehindAppBar: true, // Allows content/background to go behind the AppBar
      body: SafeArea(
        top: false, // Let the Stack manage the entire space
        child: Stack(
          children: [
            const BackgroundDesign(), // Assuming this provides the background visual
            Center(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(), // dismiss keyboard
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 80.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400), // Max width for tablet view
                    margin: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    padding: const EdgeInsets.all(28.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24), // High radius for modern feel
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.15),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title inside the card
                          Text(
                            isUpdateMode ? "Welcome Back!" : "Join the App",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.teal.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isUpdateMode ? "Review and update your details." : "Register quickly with your name and phone.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Name Field
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            hint: '',
                            icon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Phone Field
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hint: '10-digit mobile number',
                            icon: Icons.phone_android_outlined,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            prefixText: '+91 ',
                            textInputAction: TextInputAction.done,
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty ||
                                  value.trim().length != 10) {
                                return 'Enter a valid 10-digit phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 40),

                          // Submit Button (Stylized)
                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              backgroundColor: Colors.teal.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16), // Rounded button
                              ),
                              elevation: 8,
                              shadowColor: Colors.teal.shade300,
                            ),
                            child: Text(
                              isUpdateMode ? "Update Profile" : "Register & Continue",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
