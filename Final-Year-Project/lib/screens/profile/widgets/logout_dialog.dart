import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/AuthProvider.dart';
import '../../authentication/screens/login_screen.dart';
import '../../home/widgets/navigation_menu.dart';
import 'package:get/get.dart';

void showLogoutDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Logout',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, anim, sec) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child:AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Future.delayed(const Duration(milliseconds: 300));
                  _handleLogout(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, secAnim, child) {
      // Soft ease-out for entry, ease-in for exit
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );

      // Slide from just below (20% down) → original position
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(curved);

      return SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: anim,
          child: child,
        ),
      );
    },
  );
}


Future<void> _handleLogout(BuildContext context) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);

  try {

    await authProvider.logout();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logged out successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    // Animate to LoginScreen with a slide-from-right + fade
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secAnim) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 1000),
        transitionsBuilder: (ctx, anim, secAnim, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          );

          // Slide from right (x: +1 → 0) and fade in/out.
          final offset = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved);

          return SlideTransition(
            position: offset,
            child: FadeTransition(opacity: anim, child: child),
          );
        },
      ),
          (route) => false,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logout failed: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
