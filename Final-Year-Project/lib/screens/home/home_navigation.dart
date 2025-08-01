import 'package:flutter/material.dart';
import 'package:fyp/providers/session_manager.dart';
import 'widgets/navigation_menu.dart';

class NavigationHome extends StatefulWidget {
  const NavigationHome({super.key});

  @override
  State<NavigationHome> createState() => _NavigationHomeState();
}

class _NavigationHomeState extends State<NavigationHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SessionManager.checkJwtAndLogoutIfExpired(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const NavigationMenu();
  }
}
