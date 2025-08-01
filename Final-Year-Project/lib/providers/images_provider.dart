import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import '../models/image_model.dart';

class ImageService {
  final String baseUrl;

  ImageService({required this.baseUrl});

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> getToken() async {
    try {
      final token = await _storage.read(key: 'jwt');
      return token ?? '';
    } catch (e) {
      return '';
    }
  }

  // Centralized response handler
  Map<String, dynamic> _processResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      } else {
        return {
          'error': decoded['error'] ?? 'Unexpected error occurred',
          'statusCode': response.statusCode
        };
      }
    } catch (e) {
      return {
        'error': 'Failed to parse response',
        'statusCode': response.statusCode,
        'details': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> uploadImageToS3(File file, int albumId) async {
    final token = await getToken();

    final fileName = path.basename(file.path);
    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';

    // Get presigned URL
    final presignUrl = Uri.parse('$baseUrl/images/images-presign');
    final presignResponse = await http.post(
      presignUrl,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fileName': fileName,
        'fileType': mimeType,
        'albumId': albumId,
      }),
    );

    final presignResult = _processResponse(presignResponse);
    if (presignResult.containsKey('error')) return presignResult;

    final String uploadURL = presignResult['uploadURL'];
    final String s3ImageUrl = presignResult['s3ImageUrl'];

    // Upload to S3
    try {
      final fileBytes = await file.readAsBytes();
      final uploadResponse = await http.put(
        Uri.parse(uploadURL),
        headers: {'Content-Type': mimeType},
        body: fileBytes,
      );

      if (uploadResponse.statusCode >= 200 && uploadResponse.statusCode < 300) {
        return {
          'success': true,
          's3ImageUrl': s3ImageUrl,
        };
      } else {
        return {
          'error': 'Failed to upload file to S3',
          'statusCode': uploadResponse.statusCode
        };
      }
    } catch (e) {
      return {
        'error': 'S3 upload failed',
        'details': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> createImage(
      String albumId,
      String fileName,
      String s3ImageUrl,
      ) async {
    final token = await getToken();

    final url = Uri.parse('$baseUrl/images');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'albumId': int.parse(albumId),
        'fileName': fileName,
        's3ImageUrl': s3ImageUrl,
      }),
    );

    final result = _processResponse(response);
    if (result.containsKey('error')) return result;

    return {
      'success': true,
      'image': ImageModel.fromJson(result),
    };
  }

  Future<Map<String, dynamic>> getImages(
      int albumId, {
        int page = 1,
        int limit = 10,
      }) async {
    final token = await getToken();
    final url = Uri.parse(
      '$baseUrl/images/$albumId?page=$page&limit=$limit&duplicate=false&status=clear',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      final result = _processResponse(response);
      if (result.containsKey('error')) return result;

      if (result.containsKey('images')) {
        final List<dynamic> imagesData = result['images'];
        return {
          'success': true,
          'images': imagesData.map((e) => ImageModel.fromJson(e)).toList(),
        };
      } else {
        return {
          'error': 'Response does not contain images key',
          'statusCode': response.statusCode
        };
      }
    } catch (e) {
      return {
        'error': 'Exception occurred while fetching images',
        'details': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> deleteImage(int imageId) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/images/$imageId');

    try {
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      final result = _processResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return { 'success': true };
      } else {
        return result;
      }
    } catch (e) {
      return {
        'error': 'Exception occurred while deleting image',
        'details': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> deleteImages(List<int> imageIds) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/images/delete-flagged');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'imageIds': imageIds}),
      );

      final result = _processResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return { 'success': true };
      } else {
        return result;
      }
    } catch (e) {
      return {
        'error': 'Exception occurred while deleting images',
        'details': e.toString()
      };
    }
  }
}
