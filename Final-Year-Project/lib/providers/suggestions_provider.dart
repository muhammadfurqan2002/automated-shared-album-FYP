import 'package:flutter/foundation.dart';
import 'package:fyp/services/album_service.dart';

class SuggestionProvider extends ChangeNotifier {
  final AlbumService albumService;

  String _suggestion = '';
  Map<String, dynamic> _details = {};
  bool _isLoading = false;
  String? _errorMessage;

  SuggestionProvider({required this.albumService});

  String get suggestion => _suggestion;
  Map<String, dynamic> get details => _details;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchSuggestions(int albumId) async {
    _setLoadingState(true);
    try {
      final response = await albumService.getSuggestions(albumId);

      if (response is Map<String, dynamic>) {
        _suggestion = response['suggestion'] ?? '';
        _details = response['details'] ?? {};
        _errorMessage = null; // Clear any previous error messages
      } else {
        _handleError("Unexpected response format.");
      }
    } catch (e) {
      _handleError("Failed to fetch suggestions: ${e.toString()}");
    } finally {
      _setLoadingState(false);
    }
  }

  Future<bool> pollSuggestions(int albumId, {int maxAttempts = 10, Duration interval = const Duration(seconds: 5)}) async {
    _setLoadingState(true);
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        final response = await albumService.getSuggestions(albumId);

        if (kDebugMode) {
          print("Polling attempt $attempts response: $response");
        }

        if (response is Map<String, dynamic> && response.isNotEmpty && !response.containsKey('message')) {
          _suggestion = response['suggestion'] ?? '';
          _details = response; // Store the entire response

          if (kDebugMode) {
            print("Suggestion populated with details");
          }

          _setLoadingState(false);
          notifyListeners(); // Notify listeners
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error polling suggestions on attempt $attempts: $e");
        }
      }

      attempts++;
      await Future.delayed(interval);
    }

    _setLoadingState(false);
    return false;
  }



  Future<void> fetchSuggestionsManually(int albumId) async {
    _setLoadingState(true);
    try {
      final response = await albumService.getSuggestionsManually(albumId);

      if (response is Map<String, dynamic>) {
        _suggestion = response['suggestion'] ?? '';
        _details = response;
        _errorMessage = null;
      } else {
        _handleError("Unexpected response format.");
      }
    } catch (e) {
      _handleError("Failed to fetch suggestions: ${e.toString()}");
    } finally {
      _setLoadingState(false);
    }
  }



  void _handleError(String message) {
    _suggestion = '';
    _details = {};
    _errorMessage = message;
    if (kDebugMode) {
      print(message);
    }
    notifyListeners();
  }

  void _setLoadingState(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }
}
