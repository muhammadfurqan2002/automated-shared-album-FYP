import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import '../models/image_model.dart';

class FlaggedImageService {
  final String baseUrl;
  FlaggedImageService({required this.baseUrl});

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> getToken() async {
    try {
      final token = await _storage.read(key: 'jwt');
      return token ?? '';
    } catch (e) {
      return '';
    }
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    try {
      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      } else {
        return {
          'error': body['error'] ?? body['message'] ?? 'Unknown error',
          'statusCode': response.statusCode
        };
      }
    } catch (e) {
      return {
        'error': 'Failed to parse response',
        'details': e.toString(),
        'statusCode': response.statusCode
      };
    }
  }

  Future<Map<String, dynamic>> getDuplicateImages({
    required int albumId,
    int page = 1,
    int limit = 10,
  }) async {
    final token = await getToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/images/$albumId/duplicate?page=$page&limit=$limit&duplicate=true'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final result = _processResponse(response);
      if (result.containsKey('error')) return result;

      final imagesList = (result['images'] as List)
          .map<ImageModel>((json) => ImageModel.fromJson(json))
          .toList();

      return {
        'success': true,
        'images': imagesList,
      };
    } catch (e) {
      return {
        'error': 'Exception occurred while loading duplicate images',
        'details': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> getBlurImages({
    required int albumId,
    int page = 1,
    int limit = 10,
  }) async {
    final token = await getToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/images/$albumId/blur?page=$page&limit=$limit&status=blur'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final result = _processResponse(response);
      if (result.containsKey('error')) return result;

      final imagesList = (result['images'] as List)
          .map<ImageModel>((json) => ImageModel.fromJson(json))
          .toList();

      return {
        'success': true,
        'images': imagesList,
      };
    } catch (e) {
      return {
        'error': 'Exception occurred while loading blur images',
        'details': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> deleteSingleFlaggedImage(int imageId) async {
    final token = await getToken();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/images/$imageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final result = _processResponse(response);
      return result.containsKey('error') ? result : { 'success': true };
    } catch (e) {
      return {
        'error': 'Exception while deleting flagged image',
        'details': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> deleteFlaggedImages(List<int> imageIds) async {
    final token = await getToken();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/images/delete-flagged'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'imageIds': imageIds}),
      );

      final result = _processResponse(response);
      return result.containsKey('error') ? result : { 'success': true };
    } catch (e) {
      return {
        'error': 'Exception while deleting flagged images',
        'details': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> unflagBlurImage(int imageId) async {
    final token = await getToken();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/images/$imageId/unflag-blur'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final result = _processResponse(response);
      return result.containsKey('error') ? result : { 'success': true };
    } catch (e) {
      return {
        'error': 'Exception while unflagging blur image',
        'details': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> unflagDuplicateImage(int imageId) async {
    final token = await getToken();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/images/$imageId/unflag-duplicate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final result = _processResponse(response);
      return result.containsKey('error') ? result : { 'success': true };
    } catch (e) {
      return {
        'error': 'Exception while unflagging duplicate image',
        'details': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> unflagMultipleBlurImages(List<int> imageIds) async {
    final token = await getToken();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/images/unflag-blur'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'imageIds': imageIds}),
      );

      final result = _processResponse(response);
      return result.containsKey('error') ? result : { 'success': true };
    } catch (e) {
      return {
        'error': 'Exception while unflagging multiple blur images',
        'details': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> unflagMultipleDuplicateImages(List<int> imageIds) async {
    final token = await getToken();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/images/unflag-duplicate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'imageIds': imageIds}),
      );

      final result = _processResponse(response);
      return result.containsKey('error') ? result : { 'success': true };
    } catch (e) {
      return {
        'error': 'Exception while unflagging multiple duplicate images',
        'details': e.toString()
      };
    }
  }
}
