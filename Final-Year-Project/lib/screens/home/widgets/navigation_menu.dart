import 'package:flutter/material.dart';
import 'package:fyp/screens/profile/profile.dart';
import 'package:fyp/screens/qr_code/qr_code_screen.dart';
import 'package:fyp/screens/searchmore/searchmore.dart';
import 'package:iconsax/iconsax.dart';

import '../../album/screens/create_album_screen.dart';
import '../../highlights/highlightsScreen.dart';
import '../home.dart';

class NavigationMenu extends StatefulWidget {
  const NavigationMenu({super.key});

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  int selectedIndex = 0;

  final List<Widget> screens = const [
    HomeScreen(),
    SearchMoreScreen(),
    CreateAlbumScreen(),
    HighlightScreen(),
    ProfileScreen(),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void resetNavigation() {
    setState(() {
      selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        height: 70,
        elevation: 0,
        selectedIndex: selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        backgroundColor: Colors.transparent,
        indicatorColor: const Color.fromARGB(255, 230, 229, 229),
        destinations: const [
          NavigationDestination(icon: Icon(Iconsax.home), label: ''),
          NavigationDestination(
              icon: Icon(Icons.search_sharp, size: 28), label: ''),
          NavigationDestination(
              icon: Icon(Iconsax.folder_add, size: 32), label: ''),
          NavigationDestination(icon: Icon(Iconsax.story), label: ''),
          NavigationDestination(
              icon: Icon(Icons.person_2_outlined), label: ''),
        ],
      ),
      body: screens[selectedIndex],
    );
  }
}
