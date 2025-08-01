import 'package:flutter/material.dart';

class GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double borderRadius;
  final String text;
  final EdgeInsets padding;
  final double iconSize;
  final double spacing;
  final double fontSize;
  final FontWeight fontWeight;
  final bool isLoading; // New property

  const GoogleButton({
    super.key,
    required this.text,
    this.onPressed,
    this.borderRadius = 5.0,
    this.padding = const EdgeInsets.all(8.0),
    this.iconSize = 24.0,
    this.spacing = 8.0,
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.w500,
    this.isLoading = false, // Default to false
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: isLoading ? null : onPressed, // Disable tap if loading
      child: Container(
        width: screenWidth,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Padding(
          padding: padding,
          child: Center(
            child: isLoading
                ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/google.png",
                  width: iconSize,
                ),
                SizedBox(width: spacing),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
