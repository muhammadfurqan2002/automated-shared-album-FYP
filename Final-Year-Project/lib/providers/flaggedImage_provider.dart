import 'package:flutter/material.dart';
import '../models/image_model.dart';
import '../services/flaggedImage_service.dart';

class FlaggedImageProvider with ChangeNotifier {
  final FlaggedImageService flaggedImageService;

  List<ImageModel> _duplicateImages = [];
  List<ImageModel> _blurImages = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  List<ImageModel> get duplicateImages => _duplicateImages;
  List<ImageModel> get blurImages => _blurImages;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;

  FlaggedImageProvider({required this.flaggedImageService});

  Future<List<ImageModel>> fetchDuplicateImages(int albumId, {int page = 1, int limit = 10}) async {
    if (page == 1) {
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }
    _error = null;
    notifyListeners();

    List<ImageModel> newImages = [];

    final result = await flaggedImageService.getDuplicateImages(albumId: albumId, page: page, limit: limit);

    if (result.containsKey('error')) {
      _error = result['error'];
    } else {
      newImages = result['images'] as List<ImageModel>;

      if (page == 1) {
        _duplicateImages = newImages;
      } else {
        _duplicateImages.addAll(newImages.where(
                (newImg) => !_duplicateImages.any((existingImg) => existingImg.id == newImg.id)));
      }

      _error = null;
    }

    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();

    return newImages;
  }

  Future<List<ImageModel>> fetchBlurImages(int albumId, {int page = 1, int limit = 10}) async {
    if (page == 1) {
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }
    _error = null;
    notifyListeners();

    List<ImageModel> newImages = [];

    final result = await flaggedImageService.getBlurImages(albumId: albumId, page: page, limit: limit);

    if (result.containsKey('error')) {
      _error = result['error'];
    } else {
      newImages = result['images'] as List<ImageModel>;

      if (page == 1) {
        _blurImages = newImages;
      } else {
        _blurImages.addAll(newImages.where(
                (newImg) => !_blurImages.any((existingImg) => existingImg.id == newImg.id)));
      }

      _error = null;
    }

    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();

    return newImages;
  }

  Future<void> deleteImage(int imageId) async {
    _isLoading = true;
    notifyListeners();

    final result = await flaggedImageService.deleteSingleFlaggedImage(imageId);

    if (result.containsKey('error')) {
      _error = result['error'];
    } else {
      _blurImages.removeWhere((image) => image.id == imageId);
      _duplicateImages.removeWhere((image) => image.id == imageId);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteImages(List<int> imageIds) async {
    _isLoading = true;
    notifyListeners();

    final result = await flaggedImageService.deleteFlaggedImages(imageIds);

    if (result.containsKey('error')) {
      _error = result['error'];
    } else {
      _blurImages.removeWhere((image) => imageIds.contains(image.id));
      _duplicateImages.removeWhere((image) => imageIds.contains(image.id));
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> unflagBlurImage(int imageId) async {
    _isLoading = true;
    notifyListeners();

    final result = await flaggedImageService.unflagBlurImage(imageId);

    if (result.containsKey('error')) {
      _error = result['error'];
    } else {
      _blurImages.removeWhere((image) => image.id == imageId);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> unflagDuplicateImage(int imageId) async {
    _isLoading = true;
    notifyListeners();

    final result = await flaggedImageService.unflagDuplicateImage(imageId);

    if (result.containsKey('error')) {
      _error = result['error'];
    } else {
      _duplicateImages.removeWhere((image) => image.id == imageId);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> unflagMultipleBlurImages(List<int> imageIds) async {
    _isLoading = true;
    notifyListeners();

    final result = await flaggedImageService.unflagMultipleBlurImages(imageIds);

    if (result.containsKey('error')) {
      _error = result['error'];
    } else {
      _blurImages.removeWhere((image) => imageIds.contains(image.id));
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> unflagMultipleDuplicateImages(List<int> imageIds) async {
    _isLoading = true;
    notifyListeners();

    final result = await flaggedImageService.unflagMultipleDuplicateImages(imageIds);

    if (result.containsKey('error')) {
      _error = result['error'];
    } else {
      _duplicateImages.removeWhere((image) => imageIds.contains(image.id));
    }

    _isLoading = false;
    notifyListeners();
  }

  void resetError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void clearDuplicateImages() {
    _duplicateImages.clear();
    notifyListeners();
  }

  void clearBlurImages() {
    _blurImages.clear();
    notifyListeners();
  }
}
