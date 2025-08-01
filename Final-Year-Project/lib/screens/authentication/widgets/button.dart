import 'package:flutter/material.dart';

class AuthenticationButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final VoidCallback? onPressed;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isLoading;
  final Widget? leadingIcon;

  const AuthenticationButton({
    super.key,
    required this.text,
    this.backgroundColor = Colors.black,
    this.textColor = Colors.white,
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.w600,
    this.onPressed,
    this.borderRadius = 8.0,
    this.padding = const EdgeInsets.symmetric(vertical: 14.0),
    this.isLoading = false,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: textColor,
          backgroundColor: backgroundColor,
          padding: padding, // Button padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
            ? SizedBox(
          height: fontSize, // Match the height with the font size for consistency
          width: fontSize,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(textColor),
            strokeWidth: 2.0,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              leadingIcon!,
              SizedBox(width: 8.0), // Spacing between icon and text
            ],
            Text(
              text,
              style: TextStyle(
                color: textColor, // Text color
                fontSize: fontSize, // Text size
                fontWeight: fontWeight, // Text weight
              ),
            ),
          ],
        ),
      ),
    );
  }
}
