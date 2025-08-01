import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/image_model.dart';

class SharedAlbumService {
  final String baseUrl;
  SharedAlbumService({required this.baseUrl});

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> getToken() async {
    try {
      final token = await _storage.read(key: 'jwt');
      return token ?? '';
    } catch (e) {
      return '';
    }
  }

  Future<Map<String, dynamic>> createSharedAlbum({
    required int albumId,
    required int adminId,
    required List<dynamic> participantDetails,
  }) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shared/create-shared-album'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'albumId': albumId,
          'adminId': adminId,
          'participantDetails': participantDetails,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return responseData;
      } else {
        return {
          'error': 'Failed to create shared album',
          'statusCode': response.statusCode,
          'message': responseData['error'] ?? responseData['message'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      return {'error': 'Exception occurred', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getMembersWithDetails(int albumId) async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shared/$albumId/members'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        return {
          'error': 'Failed to retrieve members',
          'statusCode': response.statusCode,
          'message': responseData['error'] ?? responseData['message'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      return {'error': 'Exception occurred', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> removeUserFromAlbum({
    required int albumId,
    required int userId,
  }) async {
    final token = await getToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/shared/$albumId/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        return {
          'error': 'Failed to remove user',
          'statusCode': response.statusCode,
          'message': responseData['error'] ?? responseData['message'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      return {'error': 'Exception occurred', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changeParticipantRole({
    required int albumId,
    required int userId,
    required String newRole,
  }) async {
    final token = await getToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/shared/$albumId/$userId/role'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'newRole': newRole}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        return {
          'error': 'Failed to update role',
          'statusCode': response.statusCode,
          'message': responseData['error'] ?? responseData['message'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      return {'error': 'Exception occurred', 'message': e.toString()};
    }
  }

  Future<List<ImageModel>> getSharedImages({
    required int albumId,
    int page = 1,
    int limit = 10,
  }) async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shared/$albumId/images?page=$page&limit=$limit&duplicate=false&status=clear'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> imagesList = jsonData["images"];
        return imagesList.map<ImageModel>((json) => ImageModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load shared images');
      }
    } catch (e) {
      throw Exception('Exception occurred: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> canAccessAlbum({
    required int albumId,
  }) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/albums/$albumId');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {'statusCode': 200, 'hasAccess': true};
      } else if (response.statusCode == 403) {
        return {'statusCode': 403, 'hasAccess': false};
      } else {
        return {
          'statusCode': response.statusCode,
          'error': response.body,
        };
      }
    } catch (e) {
      return {'statusCode': -1, 'error': e.toString()};
    }
  }
}
