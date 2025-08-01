// file: flagged_overlay_buttons.dart
import 'package:flutter/material.dart';
import 'package:fyp/screens/album/screens/flagged_images_screen.dart';

class FlaggedOverlayButtons extends StatelessWidget {
  final bool showOverlay;
  final Duration animationDuration;
  final FlagType flagType;
  final VoidCallback onBackPressed;
  final VoidCallback onMorePressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onDownloadPressed;

  const FlaggedOverlayButtons({
    Key? key,
    required this.showOverlay,
    required this.animationDuration,
    required this.flagType,
    required this.onBackPressed,
    required this.onMorePressed,
    required this.onDeletePressed,
    required this.onDownloadPressed,
  }) : super(key: key);

  Widget _buildTopButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Icon(icon, color: Colors.white, size: 25),
      ),
    );
  }

  Widget _buildOverlayButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 28,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(50),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: size),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Back button
        Positioned(
          top: 45,
          left: 20,
          child: AnimatedOpacity(
            opacity: showOverlay ? 1.0 : 0.0,
            duration: animationDuration,
            child: _buildTopButton(
              icon: Icons.arrow_back,
              onPressed: onBackPressed,
            ),
          ),
        ),

        // More options button
        Positioned(
          top: 45,
          right: 20,
          child: AnimatedOpacity(
            opacity: showOverlay ? 1.0 : 0.0,
            duration: animationDuration,
            child: _buildTopButton(
              icon: Icons.more_horiz,
              onPressed: onMorePressed,
            ),
          ),
        ),

        // Delete button
        Positioned(
          bottom: 20,
          left: 90,
          child: AnimatedOpacity(
            opacity: showOverlay ? 1.0 : 0.0,
            duration: animationDuration,
            child: _buildOverlayButton(
              icon: Icons.delete,
              onPressed: onDeletePressed,
            ),
          ),
        ),

        // Download button
        Positioned(
          bottom: 20,
          right: 90,
          child: AnimatedOpacity(
            opacity: showOverlay ? 1.0 : 0.0,
            duration: animationDuration,
            child: _buildOverlayButton(
              icon: Icons.download,
              onPressed: onDownloadPressed,
            ),
          ),
        ),

      ],
    );
  }
}