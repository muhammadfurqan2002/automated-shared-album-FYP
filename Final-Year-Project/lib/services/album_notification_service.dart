import 'dart:async';
import 'package:fyp/providers/AuthProvider.dart';
import 'package:fyp/services/album_service.dart';
import 'package:fyp/services/sharedAlbum_service.dart';

import '../utils/ip.dart';

class AlbumNotificationService {
  static final AlbumNotificationService _instance = AlbumNotificationService._internal();
  factory AlbumNotificationService() => _instance;
  AlbumNotificationService._internal();

  final SharedAlbumService _sharedAlbumService = SharedAlbumService(baseUrl: IP.ip);
  final AlbumService _AlbumService = AlbumService(baseUrl:IP.ip);

  // Event bus or stream controller to notify listeners
  final _roleUpdateStreamController = StreamController<int>.broadcast();
  Stream<int> get onRoleUpdated => _roleUpdateStreamController.stream;
  final _sharedAlbumStreamController = StreamController<void>.broadcast();
  Stream<void> get onAlbumShared => _sharedAlbumStreamController.stream;

  Future<void> handleRoleUpdate(int albumId) async {
    try {
      await _sharedAlbumService.getMembersWithDetails(albumId);
      _roleUpdateStreamController.add(albumId);
    } catch (e) {
      print('Error handling role update in service: $e');
    }
  }
  Future<void> handleSharedAlbum() async {
    try {
      await _AlbumService.getSharedAlbums();
      _sharedAlbumStreamController.add(null);
    } catch (e) {
      print('Error handling role update in service: $e');
    }
  }



  void dispose() {
    _roleUpdateStreamController.close();
  }
}