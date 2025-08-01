import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/storageModel.dart';
import '../models/user.dart';
import 'package:path/path.dart' as path;

import '../utils/ip.dart';

class ApiService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final baseUrl =IP.ip;

  bool _isSuccessful(int statusCode) => statusCode >= 200 && statusCode < 300;


  String _getErrorMessage(http.Response response) {
    try {
      final decodedBody = jsonDecode(response.body);
      final errorMessage = decodedBody['error'] ?? 'Unknown error occurred';
      print("Error message: $errorMessage");
      return errorMessage;
    } catch (e) {
      return 'Error: Status code ${response.statusCode}';
    }
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    final statusCode = response.statusCode;
    final body = response.body;

    print(body);

    if (_isSuccessful(statusCode)) {
      try {
        // Normal success: parse and return JSON
        return jsonDecode(body) as Map<String, dynamic>;
      } catch (e) {
        // Parsing failed—return an error map instead of throwing
        final fallbackMessage = _getErrorMessage(response);
        return {
          'error': fallbackMessage,
          'details': e.toString(),
        };
      }
    } else {
      final errorMessage = _getErrorMessage(response);
      return {
        'error': errorMessage,
        'statusCode': statusCode,
      };
    }
  }



  Future<Map<String, dynamic>> registerWithEmail(User user) async {
    final fcmToken=await FirebaseMessaging.instance.getToken();

    final uri = Uri.parse('$baseUrl/auth/signup');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': user.email,
        'password': user.password,
        'username':user.username,
        'fcmToken':fcmToken
      }),
    );

    return _processResponse(response);
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/auth/profile');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _processResponse(response);
    } catch (e) {
      print('Error fetching user profile: $e');
      return {'error': 'Failed to fetch user profile'};
    }
  }

  Future<Map<String, dynamic>> loginWithEmail(User user) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final fcmToken=await FirebaseMessaging.instance.getToken();

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': user.email,
        'password': user.password,
        'fcmToken':fcmToken
      }),
    );
    print(response);
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> signUpWithGoogle({
    required String? idToken,
    required User user,
  }) async {
    final fcmToken=await FirebaseMessaging.instance.getToken();

    final uri = Uri.parse('$baseUrl/auth/signup/google');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
        'email':user.email,
        'username':user.username,
        'fcmToken':fcmToken
      }),
    );
    return _processResponse(response);
  }
  Future<Map<String, dynamic>> loginWithGoogle(String idToken, String email) async {
    final uri = Uri.parse('$baseUrl/auth/login/google');
    final fcmToken=await FirebaseMessaging.instance.getToken();

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
        'email': email,
        'fcmToken':fcmToken
      }),
    );
    return _processResponse(response);
  }
  Future<Map<String, dynamic>> resetPassword(String email) async {
    final uri = Uri.parse('$baseUrl/auth/forgot-password');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return _processResponse(response);
  }
  Future<Map<String, dynamic>> verifyEmail(String code, String email) async {
    final uri = Uri.parse('$baseUrl/auth/verify');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'verificationCode': code,
        'email': email,
      }),
    );

    return _processResponse(response);
  }
  Future<Map<String, dynamic>> updateProfile(User updatedUser) async {
    final uri = Uri.parse('$baseUrl/auth/update');
    final token = await _secureStorage.read(key: 'jwt');

    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json',
        'Authorization':'Bearer $token'
      },
      body: jsonEncode({
        'password':updatedUser.password,
        'email': updatedUser.email,
        'username':updatedUser.username
      }),
    );

    return _processResponse(response);
  }
  Future<Map<String, dynamic>> resendVerificationCode(String email) async {
    final uri = Uri.parse('$baseUrl/auth/resend-code');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return _processResponse(response);
  }
  Future<Map<String, dynamic>> uploadProfileImage(File coverFile, String fileType) async {


      final presignedResponse = await getPresignedUrl(
        path.basename(coverFile.path),
        fileType,
      );

      final String uploadUrl = presignedResponse['uploadURL'];
      final String s3ImageUrl = presignedResponse['s3ImageUrl'];

      await uploadFileToS3(uploadUrl, coverFile, fileType);

      final createAlbumUrl = Uri.parse('$baseUrl/auth/updateProfileImage');
      final token = await getToken();

      final response = await http.post(
        createAlbumUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'profileImageUrl': s3ImageUrl,
        }),
      );

      return _processResponse(response);
  }
  // Future<Map<String, dynamic>> getPresignedUrl(String fileName, String fileType) async {
  //   final token = await getToken();
  //   print(token);
  //   print('Token for presigned URL request: $token');
  //   final url = Uri.parse('$baseUrl/auth/profile-presign');
  //
  //   try {
  //     final response = await http.post(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $token',
  //       },
  //       body: jsonEncode({
  //         'fileName': fileName,
  //         'fileType': fileType,
  //       }),
  //     );
  //
  //     print('Presigned URL response status: ${response.statusCode}');
  //     print('Presigned URL response body: ${response.body}');
  //
  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body);
  //     } else {
  //       throw Exception('Failed to get presigned URL: ${response.statusCode}, ${response.body}');
  //     }
  //   } catch (e) {
  //     print('Error getting presigned URL: $e');
  //     rethrow;
  //   }
  // }
  Future<String> getToken() async {
    try {
      final token = await _secureStorage.read(key: 'jwt');
      print("Jwt Token");
      print(token);
      return token ?? '';
    } catch (e) {
      return '';
    }
  }
  Future<void> uploadFileToS3(String uploadUrl, File file, String fileType) async {
    try {
      final bytes = await file.readAsBytes();
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': fileType,
        },
        body: bytes,
      );

      print('S3 upload response status: ${response.statusCode}');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to upload file to S3: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading to S3: $e');
      rethrow;
    }
  }
  Future<StorageUsage> getUserStorageUsage() async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/auth/storage-stats');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );


    final data = _processResponse(response);
    return StorageUsage.fromJson(data);
  }

  // Add these methods to your existing ApiService class

  Future<Map<String, dynamic>> uploadProfileImageWithFilename(
      File imageFile,
      String customFilename,
      String fileType
      ) async {
    try {
      // Create filename with custom name and proper extension
      final extension = imageFile.path.split('.').last;
      final fileName = '$customFilename.$extension';

      final presignedResponse = await getPresignedUrl(fileName, fileType);

      final String uploadUrl = presignedResponse['uploadURL'];
      final String s3ImageUrl = presignedResponse['s3ImageUrl'];

      await uploadFileToS3(uploadUrl, imageFile, fileType);

      return {
        'success': true,
        'imageUrl': s3ImageUrl,
        'filename': fileName,
      };
    } catch (e) {
      print('Error uploading image with filename: $e');
      return {
        'error': 'Failed to upload image: $e',
      };
    }
  }

  Future<Map<String, dynamic>> registerMultipleProfileImages(
      Map<String, String> imageUrls
      ) async {
    final uri = Uri.parse('$baseUrl/auth/updateProfileImage');
    final token = await getToken();

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(imageUrls),
    );

    return _processResponse(response);
  }

// Enhanced getPresignedUrl method to handle custom filenames
  Future<Map<String, dynamic>> getPresignedUrl(String fileName, String fileType) async {
    final token = await getToken();
    print('Token for presigned URL request: $token');
    final url = Uri.parse('$baseUrl/auth/profile-presign');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fileName': fileName,
          'fileType': fileType,
        }),
      );

      print('Presigned URL response status: ${response.statusCode}');
      print('Presigned URL response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get presigned URL: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('Error getting presigned URL: $e');
      rethrow;
    }
  }

}