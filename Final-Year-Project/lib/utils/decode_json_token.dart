import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// Service for retrieving and decoding JWT tokens.
class DecodeJWTToken {
  // Key under which the JWT is stored in secure storage
  static const String _jwtKey = 'jwt';

  // Internal secure storage instance
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Singleton boilerplate
  DecodeJWTToken._internal();
  static final DecodeJWTToken _instance = DecodeJWTToken._internal();
  factory DecodeJWTToken() => _instance;

  /// Retrieves the raw JWT token string from secure storage.
  /// Returns an empty string if no token is found or on error.
  Future<String> getToken() async {
    try {
      final token = await _storage.read(key: _jwtKey);
      return token ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Decodes the stored JWT and returns its payload as a Map.
  /// Returns an empty Map if the token is missing or invalid.
  Future<Map<String, dynamic>> decodeToken() async {
    final token = await getToken();
    if (token.isEmpty || JwtDecoder.isExpired(token)) {
      return {};
    }
    return JwtDecoder.decode(token);
  }

  /// Retrieves a specific claim by [key] from the JWT payload.
  /// Returns null if the claim is not present or token is invalid.
  Future<dynamic> getClaim(String key) async {
    final payload = await decodeToken();
    return payload[key];
  }
}
