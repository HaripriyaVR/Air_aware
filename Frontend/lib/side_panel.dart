// lib/widgets/side_panel.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import your pages
import 'admin/login.dart';
import 'profile.dart';
import 'support.dart';
import 'otpsent.dart';
import 'contactus.dart';
import 'manage.dart';

class SidePanel extends StatefulWidget {
  final bool isLoggedIn;
  final String? phoneNumber;
  final Future<void> Function()? onLogout;

  const SidePanel({
    Key? key,
    required this.isLoggedIn,
    this.phoneNumber,
    this.onLogout,
  }) : super(key: key);

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  Future<String?> _getUserNameByPhone(String phone) async {
    if (phone.isEmpty) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('register')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      if (data.containsKey('name') && data['name'] != null) {
        return data['name'] as String;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header
          UserAccountsDrawerHeader(
            accountName: FutureBuilder<String?>(
              future: _getUserNameByPhone(widget.phoneNumber ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('Loading...');
                } else if (snapshot.hasError) {
                  return const Text('Error loading name');
                } else if (snapshot.hasData && snapshot.data != null) {
                  return Text(
                    'Welcome ${snapshot.data!}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  );
                } else {
                  return const Text(
                    'Guest User',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  );
                }
              },
            ),
            accountEmail: const Text(''),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.teal),
            ),
            decoration: const BoxDecoration(color: Colors.teal),
          ),

          // Admin Login
          ListTile(
            leading: const Icon(Icons.admin_panel_settings, color: Colors.teal),
            title: const Text("Admin"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLoginPage()),
              );
            },
          ),

          // Manage Account
          ListTile(
            leading: const Icon(Icons.manage_accounts, color: Colors.teal),
            title: const Text("Manage Account"),
            onTap: () {
              Navigator.pop(context);
              if (widget.isLoggedIn) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ManageAccountPage(phone: widget.phoneNumber ?? "")
),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Please log in to manage your account.'),
                ));
              }
            },
          ),

          // Settings
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.teal),
            title: const Text("Settings"),
            onTap: () {
              Navigator.pop(context);
              // Navigate to Settings page
            },
          ),

          // Help & Support
          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.teal),
            title: const Text("Help & Support"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_page, color: Colors.teal),
            title: const Text("Contact Us"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactUsPage()),
              );
            },
          ),

          const Divider(),

          // Login / Logout dynamically
          if (widget.isLoggedIn)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout"),
              onTap: () async {
                Navigator.pop(context);
                if (widget.onLogout != null) await widget.onLogout!();
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.login, color: Colors.teal),
              title: const Text("Login"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
        ],
      ),
    );
  }
}
