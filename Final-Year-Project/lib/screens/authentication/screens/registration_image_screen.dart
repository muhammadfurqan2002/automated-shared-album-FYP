import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fyp/screens/authentication/screens/login_screen.dart';
import 'package:fyp/screens/home/home_navigation.dart';
import 'package:face_camera/face_camera.dart';
import 'package:provider/provider.dart';
import 'package:mime/mime.dart';
import '../../../providers/AuthProvider.dart';
import '../../../providers/session_manager.dart';
import '../../../utils/navigation_helper.dart';
import '../../../utils/snackbar_helper.dart';

class RegistrationImage extends StatefulWidget {
  const RegistrationImage({
    Key? key,
  }) : super(key: key);

  @override
  State<RegistrationImage> createState() => _RegistrationImageState();
}

class _RegistrationImageState extends State<RegistrationImage> {
  final _imageRadiusFactor = 0.25;
  final _buttonHeight = 50.0;
  final _loadingIndicatorSize = 24.0;

  // Multiple image files for different angles
  File? _frontImage;
  File? _leftImage;
  File? _rightImage;

  bool _isLoading = false;
  String? _errorMessage;
  bool _showCamera = false;
  late FaceCameraController _faceCameraController;

  // Current capture mode
  CaptureMode _currentMode = CaptureMode.front;

  // Track completed captures
  Set<CaptureMode> _completedCaptures = {};

  @override
  void initState() {
    super.initState();
    SessionManager.checkJwtAndLogoutIfExpired(context);

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
    _faceCameraController.dispose();
    super.dispose();
  }

  Future<void> _startCapture(CaptureMode mode) async {
    if (_isLoading) return;
    setState(() {
      _currentMode = mode;
      _showCamera = true;
      _errorMessage = null;
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
        _showCamera = false;
      });
    } else {
      setState(() {
        _errorMessage = "No photo captured. Please try again.";
        _showCamera = false;
      });
      SnackbarHelper.showErrorSnackbar(context, "No photo captured. Please try again.");
    }
  }

  Future<void> _register() async {
    if (_frontImage == null || _leftImage == null || _rightImage == null) {
      SnackbarHelper.showErrorSnackbar(context, "Please capture all three angles");
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

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
        // Send all URLs to backend
        await authProvider.registerMultipleProfileImages({
          'frontImageUrl': frontResult['imageUrl'],
          'leftImageUrl': leftResult['imageUrl'],
          'rightImageUrl': rightResult['imageUrl'],
        });

        if (authProvider.error == null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const NavigationHome()),
                (route) => false,
          );
          SnackbarHelper.showSuccessSnackbar(
              context, "User Face Registered Successfully");
        } else {
          setState(() => _errorMessage = "Registration failed: ${authProvider.error}");
          SnackbarHelper.showErrorSnackbar(context, "Registration failed!");
        }
      } else {
        setState(() => _errorMessage = "Failed to upload images");
        SnackbarHelper.showErrorSnackbar(context, "Failed to upload images");
      }
    } catch (e) {
      setState(() => _errorMessage = "Error processing images: $e");
      SnackbarHelper.showErrorSnackbar(context, "Error processing images");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      _errorMessage = null;
      _currentMode = mode;
      _showCamera = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (_showCamera) {
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
                _showCamera = false;
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("Capture Photos"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            navigateTo(context, const LoginScreen(),clearStack: true);
          },
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.08,
          vertical: size.height * 0.06,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeader(size),
            Expanded(child: _buildContent(size)),
            _buildActionButton(size),
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

  Widget _buildHeader(Size size) {
    return Column(
      children: [
        Text("AI Facial Recognition",
            style: TextStyle(fontSize: size.width * 0.06, fontWeight: FontWeight.w700)),
        SizedBox(height: size.height * 0.01),
        Text("Capture 3 angles for better recognition",
            style: TextStyle(fontSize: size.width * 0.046, fontWeight: FontWeight.w300),textAlign: TextAlign.center,),
      ],
    );
  }

  Widget _buildContent(Size size) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
      child: Column(
        children: [
          if (_completedCaptures.isEmpty) _buildInitialContent(size),

          // Progress indicator
          _buildProgressIndicator(size),

          SizedBox(height: size.height * 0.03),

          // Image capture cards
          _buildCaptureGrid(size),

          if (_errorMessage != null)
            Padding(
              padding: EdgeInsets.only(top: size.height * 0.03),
              child: Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: size.width * 0.04,
                      color: Colors.red,
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  Widget _buildInitialContent(Size size) {
    return Column(
      children: [
        Text("Upload Multiple Angles",
            style: TextStyle(fontSize: size.width * 0.06, fontWeight: FontWeight.w700)),
        SizedBox(height: size.height * 0.01),
        Padding(
          padding: EdgeInsets.only(bottom: size.height * 0.03),
          child: Text("Capture front, left, and right angles for better recognition",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: size.width * 0.045, fontWeight: FontWeight.w300)),
        ),
        Image.asset("assets/face-detection.png", width: size.width * 0.3),
        SizedBox(height: size.height * 0.03),
      ],
    );
  }

  Widget _buildProgressIndicator(Size size) {
    return Column(
      children: [
        Text("Progress: ${_completedCaptures.length}/3 angles captured",
            style: TextStyle(fontSize: size.width * 0.045, fontWeight: FontWeight.w500)),
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
        // Front capture
        _buildCaptureCard(
          size,
          CaptureMode.front,
          _frontImage,
          "Front View",
          Icons.face,
        ),
        SizedBox(height: size.height * 0.02),

        // Left and Right captures
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
            SizedBox(width: size.width * 0.04),
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
      onTap: _isLoading ? null : () => _startCapture(mode),
      child: Container(
        height: size.height * 0.15,
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
                    Icon(icon, size: 40, color: Colors.grey[600]),
                    SizedBox(height: size.height * 0.01),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: size.width * 0.035,
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

  Widget _buildActionButton(Size size) {
    final allCaptured = _completedCaptures.length == 3;

    return GestureDetector(
      onTap: _isLoading ? null : (allCaptured ? _register : null),
      child: Container(
        width: size.width,
        height: _buttonHeight,
        decoration: BoxDecoration(
          color: _isLoading
              ? Colors.grey
              : allCaptured
              ? Colors.black
              : Colors.grey[400],
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(
            width: _loadingIndicatorSize,
            height: _loadingIndicatorSize,
            child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
          )
              : Text(
            allCaptured
                ? 'Register All Images'
                : 'Capture All 3 Angles (${_completedCaptures.length}/3)',
            style: TextStyle(
                color: Colors.white,
                fontSize: size.width * 0.045,
                fontWeight: FontWeight.w400),
          ),
        ),
      ),
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