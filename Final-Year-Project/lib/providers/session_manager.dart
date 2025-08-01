import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';

import 'AuthProvider.dart';

class SessionManager {
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();


  /// Call this method on each protected screen to validate the token.
  static Future<void> checkJwtAndLogoutIfExpired(BuildContext context) async {

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final token = await _storage.read(key: 'jwt');

      if (token == null || JwtDecoder.isExpired(token)) {
        print("⚠️ JWT EXPIRED or MISSING");

        await authProvider.logout();
        // await _storage.delete(key: 'jwt');

        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text("Session Expired"),
              content: const Text("Your session has expired. Please log in again."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                          (_) => false,
                    );
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      } else {
        print("✅ JWT valid");
      }
    } catch (e) {
      print("❌ Error checking JWT: $e");
    }
  }
}
