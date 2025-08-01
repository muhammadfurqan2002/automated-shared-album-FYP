import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LinkButton extends StatelessWidget {
  final String text;
  final String desc;
  final VoidCallback? onPressed;
  final Color descColor;
  final Color linkColor;
  final double fontSize;
  final FontWeight descFontWeight;
  final FontWeight linkFontWeight;

  const LinkButton({
    super.key,
    required this.text,
    required this.desc,
    this.onPressed,
    this.descColor = Colors.black,
    this.linkColor = Colors.blue,
    this.fontSize = 16.0,
    this.descFontWeight = FontWeight.normal,
    this.linkFontWeight = FontWeight.bold,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "$desc",
                style: TextStyle(
                  color: descColor,
                  fontSize: fontSize,
                  fontWeight: descFontWeight,
                ),
              ),
              Text(
                text,
                style: TextStyle(
                  color: linkColor,
                  fontSize: fontSize,
                  fontWeight: linkFontWeight,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      )
    );
  }
}