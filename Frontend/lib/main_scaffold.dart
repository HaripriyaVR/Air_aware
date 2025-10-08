import 'package:flutter/material.dart';
import 'package:aqmapp/forecast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'support.dart';
import 'home.dart';
import 'map.dart';
import 'livegas.dart';
import 'profile.dart';
import 'config.dart';

class MainScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final String? phone;

  const MainScaffold({
    Key? key,
    required this.body,
    required this.currentIndex,
    this.phone,
  }) : super(key: key);

  bool get isLoggedIn => phone != null && phone!.isNotEmpty;

  

@override
Widget build(BuildContext context) {
  final bool isLoggedIn = phone != null && phone!.isNotEmpty;
  final int profileIndex = isLoggedIn ? 3 : -1;
  final int menuIndex = isLoggedIn ? 4 : 3;

  final List<BottomNavigationBarItem> navItems = [
    const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        const BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),
        const BottomNavigationBarItem(icon: Icon(Icons.devices), label: "Stations"),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        //const BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
      ];

  return Scaffold(
    body: body,
    bottomNavigationBar: BottomNavigationBar(
      backgroundColor: Colors.white,
      currentIndex: currentIndex,
      selectedItemColor: Colors.teal,
      unselectedItemColor: Colors.black,
      type: BottomNavigationBarType.fixed,
      items: navItems,
      onTap: (index) {
        if (index == currentIndex) return;

        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AQIDashboardPage(phone: phone),
            ),
          );
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SensorMapPage(phone: phone),
            ),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LiveGasPage(phone: phone),
            ),
          );
        } else if ( index == profileIndex) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MainScaffold(
                body: ProfilePage(phone: phone!),
                currentIndex: profileIndex,
                phone: phone,
              ),
            ),
          );
        } /*else if (index == menuIndex) {
          _showMenuOptions(context);
        }*/
      },
    ),
  );
}


  void _showMenuOptions(BuildContext context) {
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
                  final forecastData = await fetchForecast();
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ForecastDataPage(forecastData: forecastData,),
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
    Navigator.pop(bottomSheetContext); // Close the bottom sheet
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
  }
Future<Map<String, dynamic>> fetchForecast() async {
  final response = await http.get(
    Uri.parse('${AppConfig.baseUrl}/api/forecast'), // ✅ API route
  );

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(response.body);

    // Build a new map of forecasts for each sensor
    final Map<String, dynamic> forecasts = {};

    data.forEach((sensor, sensorData) {
      final List<dynamic> rawForecast = sensorData['forecast'] ?? [];

      final List<Map<String, dynamic>> filteredForecast = rawForecast
          .where((item) =>
              !(item['day'].toString().toLowerCase().contains('today') ||
                item['day'].toString().toLowerCase().contains('tomorrow')))
          .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
          .toList();

      forecasts[sensor] = {
        'forecast': filteredForecast,
        'updated_at': sensorData['updated_at'],
      };
    });

    return forecasts;
  } else {
    throw Exception('Failed to fetch forecast data');
  }
}
}