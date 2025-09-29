/*import 'package:aqmapp/otpsent.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> registerUser() async {
    // ✅ Use ?.validate() to avoid null crash
    if (_formKey.currentState?.validate() ?? false) {
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
            const SnackBar(
                content: Text('❗ This number is already registered.')),
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

        // 👉 Navigate to login/OTP page
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
                    // ✅ Wrap fields in Form
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name field
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
                              labelStyle:
                                  const TextStyle(color: Colors.green),
                              hintText: 'Full Name',
                              hintStyle:
                                  const TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide:
                                    const BorderSide(color: Colors.green),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide:
                                    const BorderSide(color: Colors.green),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                    color: Colors.green, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Phone number field
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
                              labelStyle:
                                  const TextStyle(color: Colors.green),
                              hintText: '10-digit mobile number',
                              hintStyle:
                                  const TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide:
                                    const BorderSide(color: Colors.green),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide:
                                    const BorderSide(color: Colors.green),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                    color: Colors.green, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                // Register button at the bottom
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
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          const BackgroundDesign(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                              labelStyle: const TextStyle(color: Colors.green),
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
                                    color: Colors.green, width: 2),
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
                              labelStyle: const TextStyle(color: Colors.green),
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
                                    color: Colors.green, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      isUpdateMode ? "Update" : "Register",
                      style: const TextStyle(fontSize: 16, color: Colors.white),
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
