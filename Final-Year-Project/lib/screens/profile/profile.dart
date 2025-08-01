import 'package:flutter/material.dart';
import 'package:fyp/screens/profile/widgets/profile_categories.dart';
import 'package:fyp/screens/profile/widgets/profile_header.dart';
import 'package:fyp/screens/profile/widgets/profile_menu.dart';
import 'package:fyp/screens/profile/widgets/profile_storage.dart';
import 'package:provider/provider.dart';
import '../../providers/AuthProvider.dart';
import '../../providers/session_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    SessionManager.checkJwtAndLogoutIfExpired(context);
    Future.microtask(() =>
        Provider.of<AuthProvider>(context, listen: false).fetchUserStorageUsage()
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: _buildAppBar(context),
        backgroundColor: Colors.white,
        body: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileHeader(user: authProvider.user),
                    const SizedBox(height: 10),
                    const ProfileCategories(),
                    const SizedBox(height: 15),
                    const ProfileStorage(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Profile',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: const [
        ProfileMenu(),
      ],
    );
  }
}
