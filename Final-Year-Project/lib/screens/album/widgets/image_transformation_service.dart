// file: image_transformation_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

enum ImageTransformation {
  removeBackground,
  upscale,
  sharpen,
  restore,
  colorCorrection,
  retouch,
  unblur,
}

class ImageTransformationService {
  // Constants
  static const String _imggenApiKey = '';
  static const String _imggenBaseUrl = 'https://app.imggen.ai/v1';

  // API endpoints
  static const Map<ImageTransformation, String> _apiEndpoints = {
    ImageTransformation.removeBackground: '$_imggenBaseUrl/remove-background',
    ImageTransformation.upscale: '$_imggenBaseUrl/upscale-image',
    ImageTransformation.sharpen: '$_imggenBaseUrl/sharpen-photo',
    ImageTransformation.restore: '$_imggenBaseUrl/image-restoration',
    ImageTransformation.colorCorrection: '$_imggenBaseUrl/image-color-correction',
    ImageTransformation.retouch: '$_imggenBaseUrl/retouch-photo',
    ImageTransformation.unblur: '$_imggenBaseUrl/unblur-image',
  };

  // Transformation display names and descriptions
  static const Map<ImageTransformation, Map<String, String>> _transformationInfo = {
    ImageTransformation.removeBackground: {
      'name': 'Remove Background',
      'icon': '🎭'
    },
    ImageTransformation.upscale: {
      'name': 'Upscale Image',
      'icon': '📈'
    },
    ImageTransformation.sharpen: {
      'name': 'Sharpen Photo',
      'icon': '✨'
    },
    ImageTransformation.restore: {
      'name': 'Restore Image',
      'icon': '🔧'
    },
    ImageTransformation.colorCorrection: {
      'name': 'Color Correction',
      'icon': '🎨'
    },
    ImageTransformation.retouch: {
      'name': 'Retouch Photo',
      'icon': '💫'
    },
    ImageTransformation.unblur: {
      'name': 'Unblur Image',
      'icon': '🔍'
    },
  };

  Map<String, String> getTransformationInfo(ImageTransformation transformation) {
    return _transformationInfo[transformation]!;
  }

  List<ImageTransformation> getAllTransformations() {
    return ImageTransformation.values;
  }

  Future<String> applyTransformation({
    required ImageTransformation transformation,
    required String imageUrl,
    required int imageId,
  }) async {
    final apiEndpoint = _apiEndpoints[transformation]!;

    // Download original image
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download image');
    }

    // Prepare API request
    final request = http.MultipartRequest('POST', Uri.parse(apiEndpoint))
      ..headers['X-IMGGEN-KEY'] = _imggenApiKey
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          response.bodyBytes,
          filename: imageUrl.split('/').last,
        ),
      );

    // Send request to API
    final streamedResponse = await request.send();
    final apiResponse = await http.Response.fromStream(streamedResponse);

    if (apiResponse.statusCode != 200) {
      throw Exception('API error: ${apiResponse.body}');
    }

    final responseData = json.decode(apiResponse.body) as Map<String, dynamic>;
    String? processedImagePath;

    // Handle different response formats
    if (responseData['enhanced_image_url'] != null) {
      processedImagePath = responseData['enhanced_image_url'] as String;
    } else if (responseData['processed_image_url'] != null) {
      processedImagePath = responseData['processed_image_url'] as String;
    } else if (responseData['result_url'] != null) {
      processedImagePath = responseData['result_url'] as String;
    } else if (responseData['image'] != null) {
      final base64String = (responseData['image'] as String)
          .replaceFirst(RegExp(r'data:image\/\w+;base64,'), '');
      final imageBytes = base64Decode(base64String);

      final tempDirectory = await getTemporaryDirectory();
      final tempFile = File('${tempDirectory.path}/${transformation.name}_$imageId.jpg');
      await tempFile.writeAsBytes(imageBytes);
      processedImagePath = tempFile.path;
    }

    if (processedImagePath == null) {
      throw Exception('No processed image received from API');
    }

    return processedImagePath;
  }
}