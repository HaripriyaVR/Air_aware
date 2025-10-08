/*

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register.dart'; // your registration page

class ManageAccountPage extends StatefulWidget {
  final String phone; // phone of logged-in user

  const ManageAccountPage({super.key, required this.phone});

  @override
  State<ManageAccountPage> createState() => _ManageAccountPageState();
}

class _ManageAccountPageState extends State<ManageAccountPage> {
  String userName = '';
  String userPhone = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('register')
        .where('phone', isEqualTo: widget.phone)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      setState(() {
        userName = data['name'] ?? '';
        userPhone = data['phone'] ?? '';
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _navigateToUpdate() async {
    // Optional: show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Account'),
        content: const Text(
            'You will be redirected to the registration page to update your details.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      // Save current phone to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone', userPhone);

      // Navigate to RegisterPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SignupScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Account'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Card for account info
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.teal, size: 40),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            userName,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30, thickness: 1),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.teal, size: 40),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            userPhone,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Update button
            ElevatedButton.icon(
              onPressed: _navigateToUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.edit),
              label: const Text(
                'Update Account',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}*/
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register.dart';
import 'background_design.dart';

class ManageAccountPage extends StatefulWidget {
  final String phone;

  const ManageAccountPage({super.key, required this.phone});

  @override
  State<ManageAccountPage> createState() => _ManageAccountPageState();
}

class _ManageAccountPageState extends State<ManageAccountPage> {
  String userName = '';
  String userPhone = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('register')
        .where('phone', isEqualTo: widget.phone)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      setState(() {
        userName = data['name'] ?? '';
        userPhone = data['phone'] ?? '';
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  Future<void> _navigateToUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', userPhone);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: const Text(
          'Manage Account',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Beautiful background
          const BackgroundDesign(),

          // Foreground content
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 120, left: 20, right: 20),
            child: Column(
              children: [
                // Glassy Profile Card
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: Colors.white.withOpacity(0.85),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.teal.withOpacity(0.2),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFFE0F2F1),
                        child: Icon(Icons.person, size: 60, color: Colors.teal),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        userName.isNotEmpty ? userName : "No Name Available",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00796B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userPhone,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Divider(
                        color: Colors.teal.withOpacity(0.3),
                        thickness: 1,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Your account information is securely stored. "
                        "If any details have changed, please update your profile.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                // Modern Update Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16),
                      elevation: 10,
                      shadowColor: Colors.teal.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.edit, color: Colors.white, size: 22),
                    label: const Text(
                      'Update Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
