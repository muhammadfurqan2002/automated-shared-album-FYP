// file: flagged_image_menu.dart
import 'package:flutter/material.dart';

void showFlaggedImageMenu(
    BuildContext context, {
      required VoidCallback onUnflagSelected,
    }) {
  const animationDuration = Duration(milliseconds: 300);

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Menu',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: animationDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.only(top: kToolbarHeight + 20, right: 10),
          width: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              title: const Text('Unflag'),
              onTap: () {
                Navigator.of(context).pop();
                onUnflagSelected();
              },
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(animation);

      return SlideTransition(
        position: slideAnimation,
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}