import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/image_model.dart';
import '../services/sharedAlbum_service.dart';
import 'AuthProvider.dart';

class SharedAlbumProvider extends ChangeNotifier {
  final SharedAlbumService sharedAlbumService;
  final AuthProvider _authProvider;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _currentUserRole;
  List<Map<String, dynamic>> _participants = [];
  List<ImageModel> _sharedImages = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  String? get currentUserRole => _currentUserRole;
  List<Map<String, dynamic>> get participants => _participants;
  List<ImageModel> get sharedImages => _sharedImages;

  SharedAlbumProvider({
    required SharedAlbumService service,
    required AuthProvider authProvider,
  }) : sharedAlbumService = service, _authProvider = authProvider;

  Future<List<ImageModel>> fetchSharedImages(int albumId, {int page = 1, int limit = 10}) async {
    if (page == 1) _isLoading = true;
    else _isLoadingMore = true;

    _error = null;
    notifyListeners();

    List<ImageModel> newImages = [];

    try {
      newImages = await sharedAlbumService.getSharedImages(albumId: albumId, page: page, limit: limit);
      if (page == 1) {
        _sharedImages = newImages;
      } else {
        _sharedImages.addAll(newImages.where((img) => !_sharedImages.any((e) => e.id == img.id)));
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }

    return newImages;
  }

  Future<Map<String, dynamic>> createSharedAlbum({
    required int albumId,
    required int adminId,
    required List<dynamic> participantDetails,
  }) async {
    _setLoading(true);
    try {
      final result = await sharedAlbumService.createSharedAlbum(
        albumId: albumId,
        adminId: adminId,
        participantDetails: participantDetails,
      );
      if (result['error'] == null && result['message']?.contains('success') == true) {
        _error = null;
      } else {
        _setError(result['message'] ?? result['error'] ?? 'Failed to create shared album');
      }
      return result;
    } catch (e) {
      _setError(e.toString());
      return {'error': e.toString(), 'message': 'An exception occurred'};
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchMembersWithDetails(int albumId) async {
    _setLoading(true);
    try {
      final result = await sharedAlbumService.getMembersWithDetails(albumId);
      if (result['error'] == null && result['members'] != null) {
        _participants = List<Map<String, dynamic>>.from(result['members']);
        _error = null;
      } else {
        _setError(result['message'] ?? result['error'] ?? 'Failed to fetch members');
        _participants = [];
      }
    } catch (e) {
      _setError(e.toString());
      _participants = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> removeUser({required int albumId, required int userId}) async {
    _setLoading(true);
    try {
      final result = await sharedAlbumService.removeUserFromAlbum(albumId: albumId, userId: userId);
      if (result['error'] == null && result['message']?.contains('success') == true) {
        _participants.removeWhere((p) => p['user_id'] == userId);
        _error = null;
      } else {
        _setError(result['message'] ?? result['error'] ?? 'Failed to remove user');
      }
      return result;
    } catch (e) {
      _setError(e.toString());
      return {'error': e.toString(), 'message': 'An exception occurred during removal'};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> changeParticipantRole({
    required int albumId,
    required int userId,
    required String newRole,
  }) async {
    _setLoading(true);
    try {
      final result = await sharedAlbumService.changeParticipantRole(
        albumId: albumId,
        userId: userId,
        newRole: newRole,
      );
      if (result['error'] == null && result['message']?.contains('success') == true) {
        final index = _participants.indexWhere((p) => p['user_id'] == userId);
        if (index != -1) _participants[index]['access_role'] = newRole;
        _error = null;
      } else {
        _setError(result['message'] ?? result['error'] ?? 'Failed to change role');
      }
      return result;
    } catch (e) {
      _setError(e.toString());
      return {'error': e.toString(), 'message': 'An exception occurred during role change'};
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteImage(int imageId) async {
    try {
      _sharedImages.removeWhere((image) => image.id == imageId);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> deleteSharedImages(List<int> imageIds) async {
    try {
      _sharedImages.removeWhere((img) => imageIds.contains(img.id));
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> updateCurrentUserRole({String? email}) async {
    final userEmail = email ?? _authProvider.user?.email;
    if (userEmail == null) return;

    if (_participants.isNotEmpty) {
      final user = _participants.firstWhere(
            (p) => p['email'] == userEmail,
        orElse: () => {'access_role': 'viewer'},
      );
      setCurrentUserRole(user['access_role']);
    }
  }

  void setCurrentUserRole(String role) {
    _currentUserRole = role;
    notifyListeners();
  }

  void clearSharedImages() {
    _sharedImages.clear();
    notifyListeners();
  }

  void resetError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading == loading) return;
    _isLoading = loading;
    if (loading) _error = null;
    notifyListeners();
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
