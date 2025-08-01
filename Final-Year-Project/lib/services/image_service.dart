import 'dart:io';
import 'package:flutter/material.dart';
import '../models/image_model.dart';
import 'package:path/path.dart' as path;

import '../providers/images_provider.dart';

class ImagesProvider with ChangeNotifier {
  final ImageService imageService;
  List<ImageModel> _images = [];
  bool _isLoading = false;
  String? _error;
  String? _message;

  Set<int> _fetchedAlbumIds = {};
  Map<int, int> _lastFetchedPage = {};

  ImagesProvider({required this.imageService});

  List<ImageModel> get images => _images;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get message => _message;

  bool hasAlbumBeenFetched(int albumId) => _fetchedAlbumIds.contains(albumId);

  List<ImageModel> getImagesForAlbum(int albumId) {
    return _images.where((img) => img.albumId == albumId).toList();
  }

  void clearMessages() {
    _error = null;
    _message = null;
    notifyListeners();
  }

  Future<void> fetchImages(int albumId, {int page = 1, int limit = 10}) async {
    _startLoading();
    try {
      final result = await imageService.getImages(albumId, page: page, limit: limit);

      if (result.containsKey('error')) {
        _error = result['error'];
      } else {
        final fetchedImages = result['images'] as List<ImageModel>;

        if (page == 1) {
          _images = _images.where((img) => img.albumId != albumId).toList();
          _images.addAll(fetchedImages);
        } else {
          final existingIds = _images.map((img) => img.id).toSet();
          final newImages = fetchedImages.where((img) => !existingIds.contains(img.id));
          _images.addAll(newImages);
        }

        if (!_lastFetchedPage.containsKey(albumId) || page > _lastFetchedPage[albumId]!) {
          _lastFetchedPage[albumId] = page;
        }

        if (fetchedImages.length < limit) {
          _fetchedAlbumIds.add(albumId);
        }

        _message = 'Images fetched successfully';
      }
    } catch (e) {
      _error = e.toString();
      print("Error fetching images: $_error");
    } finally {
      _stopLoading();
    }
  }

  Future<void> uploadImage(File file, int albumId) async {
    _startLoading();
    try {
      final uploadResult = await imageService.uploadImageToS3(file, albumId);
      if (uploadResult.containsKey('error')) {
        _error = uploadResult['error'];
        return;
      }

      final s3ImageUrl = uploadResult['s3ImageUrl'];
      final fileName = path.basename(s3ImageUrl);

      final createResult = await imageService.createImage(
        albumId.toString(),
        fileName,
        s3ImageUrl,
      );

      if (createResult.containsKey('error')) {
        _error = createResult['error'];
        return;
      }

      final newImage = createResult['image'] as ImageModel;

      if (!_images.any((img) => img.id == newImage.id)) {
        _images.add(newImage);
      }

      _message = 'Image uploaded successfully';
    } catch (e) {
      _error = e.toString();
      print("Error uploading image: $_error");
    } finally {
      _stopLoading();
    }
  }

  Future<void> createImage(int albumId, String fileName, String s3ImageUrl) async {
    _startLoading();
    try {
      final result = await imageService.createImage(
        albumId.toString(),
        fileName,
        s3ImageUrl,
      );

      if (result.containsKey('error')) {
        _error = result['error'];
        return;
      }

      final newImage = result['image'] as ImageModel;

      if (!_images.any((img) => img.id == newImage.id)) {
        _images.add(newImage);
      }

      _message = 'Image created successfully';
    } catch (e) {
      _error = e.toString();
      print("Error creating image: $_error");
    } finally {
      _stopLoading();
    }
  }

  Future<void> deleteImage(int imageId) async {
    _startLoading();
    try {
      final result = await imageService.deleteImage(imageId);

      if (result.containsKey('error')) {
        _error = result['error'];
        return;
      }

      _images.removeWhere((image) => image.id == imageId);
      _message = 'Image deleted successfully';
    } catch (e) {
      _error = e.toString();
      print("Error deleting image: $_error");
    } finally {
      _stopLoading();
    }
  }

  Future<void> deleteImages(List<int> imageIds) async {
    _startLoading();
    try {
      final result = await imageService.deleteImages(imageIds);

      if (result.containsKey('error')) {
        _error = result['error'];

        print(result["error"]);
        return;
      }

      _images.removeWhere((image) => imageIds.contains(image.id));
      _message = 'Images deleted successfully';
    } catch (e) {
      _error = e.toString();
      print("Error deleting images: $_error");
    } finally {
      _stopLoading();
    }
  }

  void _startLoading() {
    _isLoading = true;
    _error = null;
    _message = null;
    notifyListeners();
  }

  void _stopLoading() {
    _isLoading = false;
    notifyListeners();
  }

  void clearAlbumImages(int albumId) {
    _images.removeWhere((img) => img.albumId == albumId);
    notifyListeners();
  }
}
