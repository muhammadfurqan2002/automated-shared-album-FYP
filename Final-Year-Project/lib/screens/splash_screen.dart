import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyp/screens/authentication/screens/email_verification.dart';
import 'package:fyp/screens/authentication/screens/login_screen.dart';
import 'package:fyp/screens/authentication/screens/registration_image_screen.dart';
import 'package:fyp/screens/home/home_navigation.dart';
import 'package:provider/provider.dart';
import '../providers/AuthProvider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Animation controller for 3 seconds.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // More dramatic scale: from 0.0 to full size.
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // More dramatic rotation: from -1.0 rad (approx -57°) to 0.
    _rotationAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Fades in.
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // When the animation completes, check the user status.
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkUserStatus();
      }
    });

    _controller.forward();
  }

  Future<void> _checkUserStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initialize();

    Widget destination;
    if (authProvider.jwtToken != null) {
      if (authProvider.user == null) {
        destination = const LoginScreen();
      } else if (!authProvider.user!.isVerified) {
        destination = EmailVerification(email: authProvider.user!.email);
      }
      else if(authProvider.user!.profileImageUrl!.isEmpty && authProvider.jwtToken!=null && authProvider.user!=null ){
        destination=const RegistrationImage();
      }
      else{
        destination = const NavigationHome();
      }
    } else {
      destination = const LoginScreen();
    }

    if (!mounted) return;
    _navigateTo(destination);
  }

  void _navigateTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Image.asset(
                  "assets/logo.png",
                  width: size.width * 0.8,
                  height: size.height * 0.3,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text(
              '© 2025 Giftian | Developed as a Final Year Project',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
