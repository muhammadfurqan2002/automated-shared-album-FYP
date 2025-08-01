// file: flagged_image_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class FlaggedImageTransformationService {
  // Constants
  static const String _imggenApiKey = 'imggen_jicly32t01jm5t9pj3dwzm3a';
  static const String _imggenApiUrl = 'https://app.imggen.ai/v1/remove-background';

  Future<String> unblurImage(String imageUrl, int imageId) async {
    // Download original image
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download image');
    }

    // Send to unblur API
    final request = http.MultipartRequest('POST', Uri.parse(_imggenApiUrl))
      ..headers['X-IMGGEN-KEY'] = _imggenApiKey
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          response.bodyBytes,
          filename: imageUrl.split('/').last,
        ),
      );

    final streamedResponse = await request.send();
    final apiResponse = await http.Response.fromStream(streamedResponse);

    if (apiResponse.statusCode != 200) {
      throw Exception('API error: ${apiResponse.body}');
    }

    final responseData = json.decode(apiResponse.body) as Map<String, dynamic>;
    String? unblurredImagePath;

    // Handle different response formats
    if (responseData['enhanced_image_url'] != null) {
      unblurredImagePath = responseData['enhanced_image_url'] as String;
    } else if (responseData['image'] != null) {
      final base64String = (responseData['image'] as String)
          .replaceFirst(RegExp(r'data:image\/\w+;base64,'), '');
      final imageBytes = base64Decode(base64String);

      final tempDirectory = await getTemporaryDirectory();
      final tempFile = File('${tempDirectory.path}/unblur_$imageId.jpg');
      await tempFile.writeAsBytes(imageBytes);
      unblurredImagePath = tempFile.path;
    }

    if (unblurredImagePath == null) {
      throw Exception('No unblurred image received from API');
    }

    return unblurredImagePath;
  }
}