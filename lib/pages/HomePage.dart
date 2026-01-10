import 'package:flutter/material.dart';
import 'package:new_mapper/pages/CustomReport.dart';
import 'package:new_mapper/pages/SensorPage.dart';

import 'package:new_mapper/pages/map_page.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [HomePage(), MapPage(), Customreport()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),

        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,

        type: BottomNavigationBarType.fixed,
        elevation: 12,

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sensors), label: "Sensor"),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: "Map"),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: "Custom Report",
          ),
        ],
      ),
    );
  }
}
