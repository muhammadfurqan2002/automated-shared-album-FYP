import 'package:flutter/material.dart';
import 'app_page_route.dart';

void navigateTo(BuildContext context, Widget screen, {bool clearStack = false}) {
  if (clearStack) {
    Navigator.pushAndRemoveUntil(
      context,
      AppPageRoute(child: screen),
          (route) => false,
    );
  } else {
    Navigator.push(context, AppPageRoute(child: screen));
  }
}
