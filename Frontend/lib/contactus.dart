import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  // Function to launch URLs
  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Contact Us"),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Institute Info Card
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: const [
                    Icon(Icons.location_on, size: 50, color: Colors.teal),
                    SizedBox(height: 10),
                    Text(
                      "Adi Shankara Institute of Engineering and Technology",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Kalady 683574, Ernakulam\nKerala, India",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Contact Info Card
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.contact_mail,
                        size: 50, color: Colors.teal),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _launchURL('mailto:aiiot@adishankara.ac.in'),
                      child: const Text(
                        "Email: aiiot@adishankara.ac.in",
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _launchURL('tel:+919846900310'),
                      child: const Text(
                        "Phone: +91 9846900310",
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Social Media Card
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      "Follow Us",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.camera_alt),
                          color: Colors.pink,
                          iconSize: 40,
                          onPressed: () => _launchURL(
                              'https://www.instagram.com/your_instagram/'),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.business),
                          color: Colors.blue,
                          iconSize: 40,
                          onPressed: () => _launchURL(
                              'https://www.linkedin.com/in/your_linkedin/'),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.code),
                          color: Colors.black,
                          iconSize: 40,
                          onPressed: () =>
                              _launchURL('https://github.com/your_github/'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
