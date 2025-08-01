import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../models/album_model.dart';

class AlbumService {
  final String baseUrl;
  AlbumService({required this.baseUrl});
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> getToken() async {
    try {
      return await _storage.read(key: 'jwt') ?? '';
    } catch (e) {
      return '';
    }
  }

  // ✅ Standard response processing
  Map<String, dynamic> _processResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        return {
          'error': 'Request failed',
          'statusCode': response.statusCode,
          'message': data['error'] ?? data['message'] ?? 'Unknown error'
        };
      }
    } catch (e) {
      return {
        'error': 'Invalid response',
        'statusCode': response.statusCode,
        'message': e.toString()
      };
    }
  }

  /// Get presigned URL for cover image
  Future<Map<String, dynamic>> getPresignedUrl(String fileName, String fileType) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/albums/cover-presign');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'fileName': fileName, 'fileType': fileType}),
      );
      return _processResponse(response);
    } catch (e) {
      return {'error': 'Exception occurred', 'message': e.toString()};
    }
  }

  Future<void> uploadFileToS3(String uploadUrl, File file, String fileType) async {
    final bytes = await file.readAsBytes();
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': fileType},
      body: bytes,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to upload file to S3: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> createAlbum(String albumTitle, File coverFile, String fileType) async {
    try {
      final presigned = await getPresignedUrl(path.basename(coverFile.path), fileType);

      if (presigned.containsKey('error')) return presigned;

      await uploadFileToS3(presigned['uploadURL'], coverFile, fileType);

      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/albums'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'albumTitle': albumTitle,
          'coverImageUrl': presigned['s3ImageUrl'],
        }),
      );

      return _processResponse(response);
    } catch (e) {
      return {'error': 'Exception occurred', 'message': e.toString()};
    }
  }

  Future<List<Album>> getAlbums({int page = 1, int limit = 10}) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/albums?page=$page&limit=$limit');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final data = _processResponse(response);
    if (data.containsKey('albums')) {
      return (data['albums'] as List).map((e) => Album.fromJson(e)).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to load albums');
    }
  }

  Future<List<Album>> getSharedAlbums({int page = 1, int limit = 10}) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/albums/shared-albums?page=$page&limit=$limit');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final data = _processResponse(response);
    if (data.containsKey('albums')) {
      return (data['albums'] as List).map((e) => Album.fromJson(e)).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to load shared albums');
    }
  }

  Future<Map<String, dynamic>> updateAlbum(int albumId, String albumTitle, {File? coverFile, String? fileType}) async {
    String? coverImageUrl;

    if (coverFile != null && fileType != null) {
      final presigned = await getPresignedUrl(path.basename(coverFile.path), fileType);
      if (presigned.containsKey('error')) return presigned;

      await uploadFileToS3(presigned['uploadURL'], coverFile, fileType);
      coverImageUrl = presigned['s3ImageUrl'];
    }

    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/albums/$albumId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'albumId': albumId,
        'albumTitle': albumTitle,
        'coverImageUrl': coverImageUrl,
      }),
    );

    return _processResponse(response);
  }

  Future<Map<String, dynamic>> deleteAlbum(int albumId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/albums/$albumId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );

    return _processResponse(response);
  }

  Future<Map<String, dynamic>> getSuggestions(int albumId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/albums/get-suggestions?albumId=$albumId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );

    return _processResponse(response);
  }

  Future<Map<String, dynamic>> getSuggestionsManually(int albumId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/albums/get-suggestions-manually?albumId=$albumId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );

    return _processResponse(response);
  }
}
