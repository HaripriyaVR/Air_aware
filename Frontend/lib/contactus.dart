import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Ensure this is uncommented

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  void _launchURL(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $url'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width for responsiveness
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Contact Us",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        backgroundColor: Colors.teal.shade700,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        // Remove horizontal padding from here as the illustration container will handle its own width
        padding: const EdgeInsets.symmetric(vertical: 0), // Removed horizontal padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Illustration Section ---
            Container(
              width: screenWidth, // Set width to screenWidth
              // height: 200, // You can set a fixed height or let the SVG define it
              alignment: Alignment.topCenter, // Align content to top center
              padding: const EdgeInsets.only(bottom: 20, top: 20), // Adjusted padding
              color: Colors.white, // Optional: give it a background color if desired
              child: SvgPicture.asset(
                'assets/images/contact_illustration.svg',
                height: 200, // Adjusted height for a more "top of screen" feel
                width: screenWidth * 0.8, // Make SVG width 80% of screen width
                fit: BoxFit.contain, // Ensure the SVG fits within its bounds
              ),
            ),
            const SizedBox(height: 10), // Reduced space after illustration
            const Text(
              "We're here to help!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 30),

            // --- Rest of your content (adjusted padding) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24), // Apply horizontal padding here for the rest of the content
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Location Section ---
                  _buildSectionHeader(context, "Our Location"),
                  const SizedBox(height: 15),
                  _buildInfoTile(
                    context,
                    icon: Icons.location_on_outlined,
                    title: "Adi Shankara Institute of Engineering and Technology",
                    subtitle: "Kalady 683574, Ernakulam\nKerala, India",
                    iconColor: Colors.teal,
                    isLocation: true,
                  ),
                  const SizedBox(height: 30),

                  // --- Get in Touch Section ---
                  _buildSectionHeader(context, "Get in Touch"),
                  const SizedBox(height: 15),
                  _buildContactOption(
                    context,
                    icon: Icons.email_outlined,
                    label: "Email Us",
                    value: "aiiot@adishankara.ac.in",
                    onTap: () => _launchURL(context, 'mailto:aiiot@adishankara.ac.in'),
                  ),
                  _buildContactOption(
                    context,
                    icon: Icons.phone_outlined,
                    label: "Call Us",
                    value: "+91 9846900310",
                    onTap: () => _launchURL(context, 'tel:+919846900310'),
                  ),
                  _buildContactOption(
                    context,
                    icon: Icons.chat_bubble_outline,
                    label: "Live Chat",
                    value: "Available Mon-Fri, 9 AM - 5 PM",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Live chat coming soon!'),
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    },
                    isInformational: true,
                  ),
                  const SizedBox(height: 30),

                  // --- Follow Us Section ---
                  _buildSectionHeader(context, "Follow Us"),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialMediaIcon(
                        context,
                        icon: FontAwesomeIcons.instagram,
                        color: const Color(0xFFE4405F),
                        url: 'https://www.instagram.com/your_instagram/',
                        tooltip: 'Instagram',
                      ),
                      _buildSocialMediaIcon(
                        context,
                        icon: FontAwesomeIcons.linkedinIn,
                        color: const Color(0xFF0077B5),
                        url: 'https://www.linkedin.com/in/your_linkedin/',
                        tooltip: 'LinkedIn',
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // --- App Version / User ID (Subtle Footer) ---
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      "App Version: 1.0.0 | User ID: #A1B2C3D4",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (rest of your _buildSectionHeader, _buildInfoTile, _buildContactOption, _buildSocialMediaIcon methods remain the same)
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade700,
            letterSpacing: 0.5,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          height: 2,
          width: 60,
          color: Colors.teal.shade300,
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    bool isLocation = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isLocation ? 17 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    bool isInformational = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.teal.shade600),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: isInformational
                          ? Colors.grey.shade600
                          : Colors.blue.shade700,
                      decoration: isInformational
                          ? TextDecoration.none
                          : TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isInformational)
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialMediaIcon(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String url,
    required String tooltip,
  }) {
    return Expanded(
      child: IconButton(
        icon: FaIcon(icon),
        color: color,
        iconSize: 38,
        onPressed: () => _launchURL(context, url),
        tooltip: tooltip,
        padding: const EdgeInsets.all(10),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 4,
          shadowColor: color.withOpacity(0.2),
        ),
      ),
    );
  }
}