import 'dart:io';
import 'package:another_flushbar/flushbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fyp/utils/flashbar_helper.dart';
import 'package:face_camera/face_camera.dart';
import 'package:provider/provider.dart';
import 'package:mime/mime.dart';

import '../../models/user.dart';
import '../../providers/AuthProvider.dart';
import '../../providers/session_manager.dart';

class UpdateProfileModal extends StatefulWidget {
  const UpdateProfileModal({super.key});

  @override
  _UpdateProfileModalState createState() => _UpdateProfileModalState();
}

class _UpdateProfileModalState extends State<UpdateProfileModal> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Multiple image files for different angles
  File? _frontImage;
  File? _leftImage;
  File? _rightImage;

  String? _profileImageUrl;
  bool    _obscurePassword = true;
  bool    _isLoading       = false;
  bool    _isImageLoading  = false;
  bool    _showFaceCapture = false;

  // Face capture related variables
  late FaceCameraController _faceCameraController;
  CaptureMode _currentMode = CaptureMode.front;
  Set<CaptureMode> _completedCaptures = {};

  @override
  void initState() {
    super.initState();
    SessionManager.checkJwtAndLogoutIfExpired(context);
    _initializeUserData();
    _initializeFaceCamera();
  }

  void _initializeUserData() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _usernameController.text   = user.username;
      _emailController.text      = user.email;
      _profileImageUrl           = user.profileImageUrl;
    }
  }

  void _initializeFaceCamera() {
    _faceCameraController = FaceCameraController(
      autoCapture: false,
      defaultCameraLens: CameraLens.front,
      onCapture: _onCapture,
      onFaceDetected: (Face? face) {
        // Handle face detection feedback if needed
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _faceCameraController.dispose();
    super.dispose();
  }

  Future<void> _startCapture(CaptureMode mode) async {
    if (_isImageLoading) return;
    setState(() {
      _currentMode = mode;
      _showFaceCapture = true;
    });
  }

  void _onCapture(File? image) {
    if (image != null) {
      setState(() {
        switch (_currentMode) {
          case CaptureMode.front:
            _frontImage = image;
            break;
          case CaptureMode.left:
            _leftImage = image;
            break;
          case CaptureMode.right:
            _rightImage = image;
            break;
        }
        _completedCaptures.add(_currentMode);
        _showFaceCapture = false;
      });
    } else {
      setState(() {
        _showFaceCapture = false;
      });
      _showLocalMessage("No photo captured. Please try again.", isError: true);
    }
  }

  Future<void> _retakePhoto(CaptureMode mode) async {
    await _faceCameraController.startImageStream();
    setState(() {
      switch (mode) {
        case CaptureMode.front:
          _frontImage = null;
          break;
        case CaptureMode.left:
          _leftImage = null;
          break;
        case CaptureMode.right:
          _rightImage = null;
          break;
      }
      _completedCaptures.remove(mode);
      _currentMode = mode;
      _showFaceCapture = true;
    });
  }

  Future<void> _openFaceCamera() async {
    setState(() {
      _showFaceCapture = true;
      _currentMode = CaptureMode.front;
      _completedCaptures.clear();
      _frontImage = null;
      _leftImage = null;
      _rightImage = null;
    });
  }

  Future<void> _updateMultipleProfileImages() async {
    if (_frontImage == null || _leftImage == null || _rightImage == null) {
      _showLocalMessage("Please capture all three angles", isError: true);
      return;
    }

    setState(() => _isImageLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final rootContext = Overlay.of(context)!.context;

    try {
      // Upload all three images with specific filenames
      final frontResult = await authProvider.uploadProfileImageWithFilename(
          _frontImage!,
          'front',
          lookupMimeType(_frontImage!.path) ?? 'image/jpeg'
      );

      final leftResult = await authProvider.uploadProfileImageWithFilename(
          _leftImage!,
          'left',
          lookupMimeType(_leftImage!.path) ?? 'image/jpeg'
      );

      final rightResult = await authProvider.uploadProfileImageWithFilename(
          _rightImage!,
          'right',
          lookupMimeType(_rightImage!.path) ?? 'image/jpeg'
      );

      if (frontResult != null && leftResult != null && rightResult != null) {
        // Send all URLs to backend for update
        await authProvider.registerMultipleProfileImages({
          'frontImageUrl': frontResult['imageUrl'],
          'leftImageUrl': leftResult['imageUrl'],
          'rightImageUrl': rightResult['imageUrl'],
        });

        if (mounted) {
          if (authProvider.error == null) {
            print(authProvider.user);
            setState(() {
              _profileImageUrl = authProvider.user?.profileImageUrl;
              _frontImage = null;
              _leftImage = null;
              _rightImage = null;
              _completedCaptures.clear();
            });
          }
        }

        // Show success/error message
        Flushbar(
          margin: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(8),
          icon: Icon(
            authProvider.error == null ? Icons.check_circle : Icons.error,
            color: Colors.white,
          ),
          messageText: Text(
            authProvider.error == null
                ? 'Profile images updated successfully!'
                : authProvider.error!,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          backgroundColor: authProvider.error == null ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ).show(rootContext);
      } else {
        _showLocalMessage("Failed to upload images", isError: true);
      }
    } catch (e) {
      Flushbar(
        margin: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(8),
        icon: const Icon(Icons.error, color: Colors.white),
        messageText: Text(
          'Image upload failed: $e',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ).show(rootContext);
    } finally {
      if (mounted) setState(() => _isImageLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);
    try {
      final current = context.read<AuthProvider>().user;
      if (current == null) {
        if (!mounted) return;
        _showLocalMessage('User not found', isError: true);
        return;
      }

      final updated = User(
        email:      _emailController.text.trim(),
        username:   _usernameController.text.trim(),
        password:   _passwordController.text.isNotEmpty
            ? _passwordController.text
            : null,
        isVerified: current.isVerified,
      );

      final success = await context.read<AuthProvider>().updateProfile(updated);
      if (!mounted) return;

      if (success) {
        _showLocalMessage('Profile updated successfully!');
        Navigator.pop(context);
      } else {
        final err = context.read<AuthProvider>().error;
        _showLocalMessage(err ?? 'Update failed', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showLocalMessage('Failed to update profile: $e', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  bool _validateInputs() {
    final name = _usernameController.text.trim();
    final pwd  = _passwordController.text;

    if (name.isEmpty) {
      FlushbarHelper.show(context, message: 'Username cannot be empty',icon: Icons.info_outline,backgroundColor: Colors.red);
      return false;
    }
    if (name.length < 3) {
      FlushbarHelper.show(context, message: 'Username must be at least 3 characters',icon: Icons.info_outline,backgroundColor: Colors.red);
      return false;
    }

    if (pwd.isNotEmpty) {
      final specialCharRegex = RegExp(r'[!@#\\$%^&*(),.?":{}|<>]');
      if (pwd.length < 6 || !specialCharRegex.hasMatch(pwd)) {
        FlushbarHelper.show(context, message: 'Password must be at least 6 characters and include a special character',icon: Icons.info_outline,backgroundColor: Colors.red);
        return false;
      }
    }

    return true;
  }

  void _showLocalMessage(String msg, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Show face capture screen when needed
    if (_showFaceCapture) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text("Capture ${_currentMode.displayName}"),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _showFaceCapture = false;
              });
            },
          ),
        ),
        body: SmartFaceCamera(
          controller: _faceCameraController,
          showControls: true,
          showCaptureControl: true,
          messageBuilder: (context, face) {
            if (face == null) {
              return _buildMessage('Place your face in the camera');
            }
            if (!face.wellPositioned) {
              return _buildMessage('Center your face in the square');
            }
            return _buildMessage('Perfect! Tap to capture ${_currentMode.displayName}');
          },
        ),
      );
    }

    // Show multi-angle capture interface if any images are captured
    if (_completedCaptures.isNotEmpty) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFaceCaptureHeader(size),
              const SizedBox(height: 20),
              _buildProgressIndicator(size),
              const SizedBox(height: 20),
              _buildCaptureGrid(size),
              const SizedBox(height: 20),
              _buildFaceCaptureActions(size),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    }

    // Default modal view
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProfileImage(),
            const SizedBox(height: 25),
            _buildInputSection(),
            const SizedBox(height: 25),
            _buildUpdateButton(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 15),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFaceCaptureHeader(Size size) {
    return Column(
      children: [
        Center(
          child: Text("Update Face Recognition",
              style: TextStyle(fontSize: size.width * 0.045, fontWeight: FontWeight.w700)),
        ),
        SizedBox(height: size.height * 0.01),
        Center(
          child: Text("Capture 3 angles for better recognition",
              style: TextStyle(fontSize: size.width * 0.04, fontWeight: FontWeight.w300),textAlign: TextAlign.center,),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(Size size) {
    return Column(
      children: [
        Text("Progress: ${_completedCaptures.length}/3 angles captured",
            style: TextStyle(fontSize: size.width * 0.04, fontWeight: FontWeight.w500)),
        SizedBox(height: size.height * 0.01),
        LinearProgressIndicator(
          value: _completedCaptures.length / 3.0,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      ],
    );
  }

  Widget _buildCaptureGrid(Size size) {
    return Column(
      children: [
        _buildCaptureCard(
          size,
          CaptureMode.front,
          _frontImage,
          "Front View",
          Icons.face,
        ),
        SizedBox(height: size.height * 0.015),
        Row(
          children: [
            Expanded(
              child: _buildCaptureCard(
                size,
                CaptureMode.left,
                _leftImage,
                "Left View",
                Icons.keyboard_arrow_left,
              ),
            ),
            SizedBox(width: size.width * 0.03),
            Expanded(
              child: _buildCaptureCard(
                size,
                CaptureMode.right,
                _rightImage,
                "Right View",
                Icons.keyboard_arrow_right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCaptureCard(Size size, CaptureMode mode, File? imageFile, String title, IconData icon) {
    final isCompleted = _completedCaptures.contains(mode);

    return GestureDetector(
      onTap: _isImageLoading ? null : () => _startCapture(mode),
      child: Container(
        height: size.height * 0.12,
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCompleted ? Colors.green : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageFile != null)
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        imageFile,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => _retakePhoto(mode),
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(Icons.refresh, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                    if (isCompleted)
                      Positioned(
                        bottom: 5,
                        left: 5,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(Icons.check, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
              )
            else
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 30, color: Colors.grey[600]),
                    SizedBox(height: size.height * 0.005),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: size.width * 0.03,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceCaptureActions(Size size) {
    final allCaptured = _completedCaptures.length == 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel button
        GestureDetector(
          onTap: _isImageLoading ? null : () {
            setState(() {
              _completedCaptures.clear();
              _frontImage = null;
              _leftImage = null;
              _rightImage = null;
            });
          },
          child: Container(
            width: size.width * 0.25,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: size.width * 0.035,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),

        // Update button
        GestureDetector(
          onTap: _isImageLoading ? null : (allCaptured ? _updateMultipleProfileImages : null),
          child: Container(
            width: size.width * 0.35,
            height: 40,
            decoration: BoxDecoration(
              color: _isImageLoading
                  ? Colors.grey
                  : allCaptured
                  ? Colors.black
                  : Colors.grey[400],
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: _isImageLoading
                  ? SizedBox(
                width: 20,
                height: 20,
                child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
                  : Text(
                allCaptured
                    ? 'Update Images'
                    : 'Capture (${_completedCaptures.length}/3)',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: size.width * 0.035,
                    fontWeight: FontWeight.w400),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    final user = context.read<AuthProvider>().user;
    final imageUrl = user?.profileImageUrl;
    final updatedAt = user?.imageUpdated;

    // Append ?t=timestamp if available
    final imageUrlWithTimestamp = (imageUrl != null && updatedAt != null)
        ? '$imageUrl?t=${updatedAt.millisecondsSinceEpoch}'
        : imageUrl;

    final providerImage = imageUrlWithTimestamp != null
        ? CachedNetworkImageProvider(imageUrlWithTimestamp)
        : null;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage: providerImage,
          backgroundColor: Colors.grey[200],
          child: providerImage == null
              ? const Icon(Icons.person, size: 50, color: Colors.grey)
              : null,
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: GestureDetector(
            onTap: _isImageLoading ? null : _openFaceCamera,
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.green,
              child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField('Username', _usernameController),
        _buildField('Email', _emailController, readOnly: true),
        _buildPasswordField(),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          readOnly:   readOnly,
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Password',
            style:
            TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextField(
          controller:  _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility
                  : Icons.visibility_off),
              onPressed: () {
                if (!mounted) return;
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildUpdateButton() {
    final busy = _isLoading || _isImageLoading;
    return ElevatedButton(
      onPressed: busy ? null : _updateProfile,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding:
        const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
      child: _isImageLoading
          ? const Text('Processing image...',
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold))
          : _isLoading
          ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
            color: Colors.white),
      )
          : const Text('Save',
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold)),
    );
  }
}

enum CaptureMode {
  front,
  left,
  right;

  String get displayName {
    switch (this) {
      case CaptureMode.front:
        return 'Front View';
      case CaptureMode.left:
        return 'Left View';
      case CaptureMode.right:
        return 'Right View';
    }
  }
}