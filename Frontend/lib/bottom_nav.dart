import 'package:flutter/material.dart';
import 'map.dart';
import 'livegas.dart';
import 'profile.dart';
import 'home.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isLoggedIn;
  final String? phone;
  final Function(BuildContext) showMenu;
  final Function(int) onIndexChanged;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.isLoggedIn,
    required this.phone,
    required this.showMenu,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      currentIndex: currentIndex,
      selectedItemColor: Colors.teal,
      unselectedItemColor: Colors.black,
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        const BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),
        const BottomNavigationBarItem(icon: Icon(Icons.devices), label: "Stations"),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        //const BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
      ],
      onTap: (index) {
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => AQIDashboardPage(phone: phone)),
          );
        }
        else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => SensorMapPage(phone: phone)),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LiveGasPage(phone: phone)),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfilePage(phone: phone ?? "Unknown")),
          );
        } /*else if ((!isLoggedIn && index == 3) || index == 4) {
          showMenu(context);
        }*/

        onIndexChanged(index); // notify parent
      },
    );
  }
}
