import 'package:flutter/material.dart';
import 'package:fyp/screens/qr_code/qr_code_screen.dart';
import 'package:fyp/utils/navigation_helper.dart';
import 'package:provider/provider.dart';
import '../../../providers/AuthProvider.dart';
import 'package:fyp/screens/profile/update_profile.dart';
import 'logout_dialog.dart';

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key});

  void _showUpdateProfile(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Update Profile',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (ctx, anim, sec) => const UpdateProfileModal(),
      transitionBuilder: (ctx, anim, secAnim, child) {
        // Elastic out on entry, easeIn on exit
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeIn,
        );

        final scale = Tween<double>(begin: 0.8, end: 1.0).animate(curved);

        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
    ).then((_) {
      Provider.of<AuthProvider>(context, listen: false).notifyListeners();
    });
  }

  Future<String?> _showAnimatedPopupMenu(BuildContext context) {
    return showGeneralDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight + 20,left: 200 ,right: 20),
            child: Material(
              elevation: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop("Edit Profile");
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      child: const Row(
                        children: [
                          Text(
                            'Edit Profile',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop("Scan QR");
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: const Text(
                        'Scan QR',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop("Logout");
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      child: const Row(
                        children: [
                          Text(
                            'Logout',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.more_horiz_outlined,
        color: Colors.black,
        size: 30,
      ),
      onPressed: () async {
        final result = await _showAnimatedPopupMenu(context);
        if (result != null) {
          switch (result) {
            case "Edit Profile":
              _showUpdateProfile(context);
              break;
            case "Scan QR":
              navigateTo(context,const QrScanScreen(),clearStack: false);
              break;
            case "Logout":
              showLogoutDialog(context);
              break;
          }
        }
      },
    );
  }
}
