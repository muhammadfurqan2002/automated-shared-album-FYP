import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/storageModel.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['openid', 'email', 'profile'],
    serverClientId:
    '189023125877-s4k6oq8up5jm42hdl96m0hu94dqtbmbj.apps.googleusercontent.com',
  );

  String? _jwtToken;
  bool _isLoading = false;
  String? _error;
  String? _message;
  User? _user;
  String? _googleIdToken;

  StorageUsage? _storageUsage;
  bool _isLoadingStorageUsage = false;
  String? _storageUsageError;

  // Getters
  String? get jwtToken => _jwtToken;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get message => _message;
  User? get user => _user;
  String? get googleIdToken => _googleIdToken;
  StorageUsage? get storageUsage => _storageUsage;
  bool get isLoadingStorageUsage => _isLoadingStorageUsage;
  String? get storageUsageError => _storageUsageError;

  void clearMessages() {
    _error = null;
    _message = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    _jwtToken = await _storage.read(key: 'jwt');
    if (_jwtToken != null) {
      final userJson = await _storage.read(key: 'user');
      if (userJson != null) {
        _user = User.fromJson(jsonDecode(userJson));
      }
    }
    notifyListeners();
  }

  Future<void> _saveJwt(String token) async {
    _jwtToken = token;
    await _storage.write(key: 'jwt', value: token);
  }

  Future<void> _saveUser(User user) async {
    _user = user;
    await _storage.write(key: 'user', value: jsonEncode(user.toJson()));
  }

  /// 1) Register
  Future<String?> registerWithEmail(User user) async {
    _startLoading();
    if (user.password == null || user.password!.isEmpty) {
      _error = 'Password is required for registration';
      _stopLoading();
      return null;
    }

    final response = await _apiService.registerWithEmail(user);
    if (response.containsKey('error')) {
      _error = response['error'] as String;
      _stopLoading();
      return null;
    }

    _message = response['message']
        ?? 'Signup initiated. Verification code sent to email.';
    notifyListeners();
    _stopLoading();
    return _message;
  }

  /// 2) Login with email
  Future<void> loginWithEmail(User user) async {
    _startLoading();
    if (user.password == null || user.password!.isEmpty) {
      _error = 'Password is required for login';
      _stopLoading();
      return;
    }

    final response = await _apiService.loginWithEmail(user);
    if (response.containsKey('error')) {
      _error = response['error'] as String;
      _stopLoading();
      return;
    }

    final token = response['token'];
    if (token == null) {
      _error = 'No token received';
    } else {
      await _saveJwt(token as String);
      if (response['user'] != null) {
        await _saveUser(User.fromJson(response['user'] as Map<String, dynamic>));
      }
      notifyListeners();
    }

    _stopLoading();
  }

  /// 3) Sign up with Google
  Future<String?> signUpWithGoogle({
    required String? idToken,
    required User user,
  }) async {
    _startLoading();
    final response = await _apiService.signUpWithGoogle(
      idToken: idToken,
      user: user,
    );
    if (response.containsKey('error')) {
      _error = response['error'] as String;
      _stopLoading();
      return null;
    }

    final token = response['token'];
    if (token == null) {
      _error = 'No token received';
      _stopLoading();
      return null;
    }

    await _saveJwt(token as String);
    if (response['user'] != null) {
      await _saveUser(User.fromJson(response['user'] as Map<String, dynamic>));
    }
    _message = response['message'] ?? 'Google sign-up successful';
    notifyListeners();
    _stopLoading();
    return _message;
  }

  /// 4) Login with Google
  Future<void> loginWithGoogle() async {
    _startLoading();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      _error = 'Google sign-in cancelled';
      _stopLoading();
      return;
    }

    final googleAuth = await googleUser.authentication;
    final response = await _apiService.loginWithGoogle(
      googleAuth.idToken!,
      googleUser.email,
    );
    if (response.containsKey('error')) {
      _error = response['error'] as String;
      _stopLoading();
      return;
    }

    final token = response['token'];
    if (token == null) {
      _error = 'No token received';
    } else {
      await _saveJwt(token as String);
      if (response['user'] != null) {
        await _saveUser(User.fromJson(response['user'] as Map<String, dynamic>));
      }
      _message = response['message'] ?? 'Google login successful';
      notifyListeners();
    }

    _stopLoading();
  }

  /// 5) Fetch Google user data before signup
  Future<void> userGoogleData() async {
    _startLoading();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      _error = 'Google sign-in cancelled';
      _stopLoading();
      return;
    }

    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) {
      _error = 'Google ID token missing';
      _stopLoading();
      return;
    }

    _user = User(
      email: googleUser.email,
      username: googleUser.email.split('@')[0],
      isVerified: false,
    );
    _googleIdToken = googleAuth.idToken;
    notifyListeners();
    _stopLoading();
  }

  /// 6) Reset Password
  Future<bool> resetPassword(User user) async {
    _startLoading();
    final response = await _apiService.resetPassword(user.email);
    if (response.containsKey('error')) {
      _error = response['error'] as String;
      _stopLoading();
      return false;
    }

    _message = response['message'] ?? 'Reset link sent';
    notifyListeners();
    _stopLoading();
    return true;
  }

  /// 7) Verify Email
  Future<bool> verifyEmail(String token, User user) async {
    _startLoading();
    final response = await _apiService.verifyEmail(token, user.email);
    if (response.containsKey('error')) {
      _error = response['error'] as String;
      _stopLoading();
      return false;
    }

    // Expect token & user in response
    if (!response.containsKey('token') || !response.containsKey('user')) {
      _error = 'Invalid server response';
      _stopLoading();
      return false;
    }

    await _saveJwt(response['token'] as String);
    final userData = User.fromJson(response['user'] as Map<String, dynamic>);
    if (!userData.isVerified) {
      _error = 'Verification failed';
      _stopLoading();
      return false;
    }

    await _saveUser(userData);
    _message = response['message'] ?? 'Verification successful';
    notifyListeners();
    _stopLoading();
    return true;
  }

  /// 8) Resend Verification Code
  Future<bool> resendVerificationCode(User user) async {
    _startLoading();
    final response = await _apiService.resendVerificationCode(user.email);
    if (response.containsKey('error')) {
      _error = response['error'] as String;
      _stopLoading();
      return false;
    }

    _message =
        response['message'] ?? 'Verification code resent successfully';
    notifyListeners();
    _stopLoading();
    return true;
  }

  /// 9) Upload Profile Image
  Future<String?> registerProfileImage(File coverFile, String fileType) async {
    _startLoading();
    final response =
    await _apiService.uploadProfileImage(coverFile, fileType);

    if (response.containsKey('error')) {
      _error = response['error'] as String;
      _stopLoading();
      return null;
    }

    final token = response['token'];
    if (token == null) {
      _error = 'No token received';
      _stopLoading();
      return null;
    }

    await _saveJwt(token as String);
    if (response['user'] != null) {
      await _saveUser(User.fromJson(response['user'] as Map<String, dynamic>));
    }
    _message = response['message'] ?? 'Profile image updated';
    notifyListeners();
    _stopLoading();
    return _message;
  }

  /// 10) Update Profile
  Future<bool> updateProfile(User updatedUser) async {
    _startLoading();
    final response = await _apiService.updateProfile(updatedUser);
    if (response.containsKey('error')) {
      _error = response['error'] as String;
      notifyListeners();
      _stopLoading();
      return false;
    }

    if (response['user'] != null) {
      await _saveUser(User.fromJson(response['user'] as Map<String, dynamic>));
    }
    _message = response['message'] ?? 'Profile updated successfully';
    notifyListeners();
    _stopLoading();
    return true;
  }

  Future<void> fetchUserStorageUsage() async {
    _isLoadingStorageUsage = true;
    _storageUsageError = null;
    notifyListeners();

    try {
      final usage = await _apiService.getUserStorageUsage();
      _storageUsage = usage; // Already returns StorageUsage
    } catch (e) {
      _storageUsageError = e.toString();
      _storageUsage = null;
    } finally {
      _isLoadingStorageUsage = false;
      notifyListeners();
    }
  }



  /// 12) Logout
  Future<void> logout() async {
    _startLoading();
    await _storage.delete(key: 'jwt');
    await _storage.delete(key: 'user');
    await _googleSignIn.signOut();
    _jwtToken = null;
    _user = null;
    _message = 'Logged out successfully';
    notifyListeners();
    _stopLoading();
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



  // Add these methods to your existing AuthProvider class



  /// Upload profile image with custom filename

  Future<Map<String, dynamic>?> uploadProfileImageWithFilename(
      File imageFile,
      String customFilename,
      String fileType
      ) async {
    _startLoading();

    final response = await _apiService.uploadProfileImageWithFilename(
        imageFile,
        customFilename,
        fileType
    );

    if (response.containsKey('error')) {
      _error = response['error'] as String;
      _stopLoading();
      return null;
    }

    _stopLoading();
    return response;
  }

  /// Register multiple profile images
  Future<bool> registerMultipleProfileImages(Map<String, String> imageUrls) async {
    _startLoading();

    final response = await _apiService.registerMultipleProfileImages(imageUrls);

    if (response.containsKey('error')) {
      _error = response['error'] as String;
      _stopLoading();
      return false;
    }

    // Update user data if returned
    if (response['user'] != null) {
      await _saveUser(User.fromJson(response['user'] as Map<String, dynamic>));
    }

    // Update token if returned
    if (response['token'] != null) {
      await _saveJwt(response['token'] as String);
    }

    _message = response['message'] ?? 'Multiple profile images registered successfully';
    notifyListeners();
    _stopLoading();
    return true;
  }
}


