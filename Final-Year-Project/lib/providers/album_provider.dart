import 'dart:io';
import 'package:flutter/material.dart';
import '../models/album_model.dart';
import '../services/album_service.dart';

class AlbumProvider with ChangeNotifier {
  final AlbumService albumService;
  List<Album> _albums = [];
  List<Album> _sharedAlbums = [];
  bool _isLoading = false;
  String? _error;
  String? _message;

  // For pagination
  int _albumPage = 1;
  bool _albumHasMore = true;
  int _sharedAlbumPage = 1;
  bool _sharedAlbumHasMore = true;

  AlbumProvider({required this.albumService});

  List<Album> get albums => _albums;
  List<Album> get sharedAlbums => _sharedAlbums;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get message => _message;
  int get albumPage => _albumPage;
  bool get albumHasMore => _albumHasMore;
  int get sharedAlbumPage => _sharedAlbumPage;
  bool get sharedAlbumHasMore => _sharedAlbumHasMore;

  void clearMessages() {
    _error = null;
    _message = null;
    notifyListeners();
  }

  Future<void> fetchAlbums({int page = 1, int limit = 10, bool append = false}) async {
    if (!append) {
      _albumHasMore = true;
      _albumPage = 1;
      _error = null;
      _message = null;
    }
    _startLoading();
    try {
      final response = await albumService.getAlbums(page: page, limit: limit);

      final fetchedAlbums = response;
      if (append) {
        final existingIds = _albums.map((a) => a.id).toSet();
        _albums.addAll(fetchedAlbums.where((a) => !existingIds.contains(a.id)));
        _albumPage = page;
      } else {
        _albums = fetchedAlbums;
        _albumPage = 1;
      }

      _albumHasMore = fetchedAlbums.length == limit;
      _message = 'Albums fetched successfully';
    } catch (e) {
      _error = e.toString();
    } finally {
      _stopLoading();
    }
  }

  Future<void> fetchSharedAlbums({int page = 1, int limit = 10, bool append = false}) async {
    if (!append) {
      _sharedAlbumHasMore = true;
      _sharedAlbumPage = 1;
      _error = null;
      _message = null;
    }
    _startLoading();
    try {
      final response = await albumService.getSharedAlbums(page: page, limit: limit);

      final fetchedAlbums = response;
      if (append) {
        final existingIds = _sharedAlbums.map((a) => a.id).toSet();
        _sharedAlbums.addAll(fetchedAlbums.where((a) => !existingIds.contains(a.id)));
        _sharedAlbumPage = page;
      } else {
        _sharedAlbums = fetchedAlbums;
        _sharedAlbumPage = 1;
      }

      _sharedAlbumHasMore = fetchedAlbums.length == limit;
      _message = 'Shared albums fetched successfully';
    } catch (e) {
      _error = e.toString();
    } finally {
      _stopLoading();
    }
  }

  Future<void> createAlbum(String albumTitle, File coverFile, String fileType) async {
    _startLoading();
    try {
      final response = await albumService.createAlbum(albumTitle, coverFile, fileType);

      if (response.containsKey('error')) {
        _error = response['message'];
        return;
      }

      final newAlbum = Album.fromJson(response);
      _albums.insert(0, newAlbum);
      _message = 'Album created successfully';
    } catch (e) {
      _error = e.toString();
    } finally {
      _stopLoading();
    }
  }

  Future<bool> updateAlbum(int albumId, String albumTitle, {File? coverFile, String? fileType}) async {
    _startLoading();
    try {
      final response = await albumService.updateAlbum(albumId, albumTitle, coverFile: coverFile, fileType: fileType);

      if (response.containsKey('error')) {
        _error = response['message'];
        return false;
      }

      final updatedAlbum = Album.fromJson(response);
      final index = _albums.indexWhere((a) => a.id == albumId);
      if (index != -1) _albums[index] = updatedAlbum;

      _message = 'Album updated successfully';
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _stopLoading();
    }
  }

  Future<void> deleteAlbum(int albumId) async {
    _startLoading();
    try {
      final response = await albumService.deleteAlbum(albumId);
      if (response.containsKey('error')) {
        _error = response['message'];
        return;
      }

      _albums.removeWhere((album) => album.id == albumId);
      _sharedAlbums.removeWhere((album) => album.id == albumId);
      _message = 'Album deleted successfully';
    } catch (e) {
      _error = e.toString();
    } finally {
      _stopLoading();
    }
  }

  Future<void> addSharedAlbum(Album album) async {
    _sharedAlbums.insert(0, album);
    _albums.insert(0, album);
    notifyListeners();
  }

  Future<void> removeSharedAlbum(int albumId) async {
    _sharedAlbums.removeWhere((a) => a.id == albumId);
    _albums.removeWhere((a) => a.id == albumId);
    notifyListeners();
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
}
