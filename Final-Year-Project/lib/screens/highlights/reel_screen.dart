import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fyp/screens/highlights/widgets/highlight_caption.dart';
import 'package:fyp/screens/highlights/widgets/highlight_overlay.dart';
import 'package:fyp/screens/highlights/widgets/slide_show.dart';
import 'package:fyp/screens/highlights/widgets/video_player_screen.dart';
import 'package:fyp/utils/flashbar_helper.dart';
import 'package:fyp/utils/ip.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../models/highlight.dart';

class SingleReelWidget extends StatefulWidget {
  final ReelModel reel;
  const SingleReelWidget({Key? key, required this.reel}) : super(key: key);

  static const Duration autoPlayInterval = Duration(seconds: 3);
  static const double borderRadius = 16.0;
  static const double imageHeight = 350.0;
  static const double captionPadding = 16.0;

  @override
  State<SingleReelWidget> createState() => _SingleReelWidgetState();
}

class _SingleReelWidgetState extends State<SingleReelWidget> {
  late Timer _autoPlayTimer;
  int _currentIndex = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _autoPlayTimer = Timer.periodic(SingleReelWidget.autoPlayInterval, (_) => _nextImage());
  }

  void _nextImage() {
    if (mounted) {
      setState(() => _currentIndex = (_currentIndex + 1) % widget.reel.images.length);
    }
  }

  @override
  void dispose() {
    _autoPlayTimer.cancel();
    super.dispose();
  }

  // Show dialog to ask user about audio preference
  Future<void> _showAudioSelectionDialog() async {
    final w=MediaQuery.of(context).size.width;
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.music_note, color: Colors.blue),
              SizedBox(width: 4),
              Text('Add Audio to Video?',style: TextStyle(fontSize: w*0.05),),
            ],
          ),
          content: const Text(
            'Would you like to add background music to your slideshow video?',
            style: TextStyle(fontSize: 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'No Audio',
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _createAndPlayVideo(null);
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.audiotrack, size: 18),
              label: const Text('Add Audio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _pickAudioFile();
              },
            ),
          ],
        );
      },
    );
  }

  // Function to pick audio file
  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File audioFile = File(result.files.single.path!);

        // Check file size (5MB = 5 * 1024 * 1024 bytes)
        int fileSizeInBytes = await audioFile.length();
        double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        if (fileSizeInMB > 5.0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio file is too large (${fileSizeInMB.toStringAsFixed(2)}MB). Please select a file smaller than 5MB.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        // Convert to base64
        List<int> audioBytes = await audioFile.readAsBytes();
        String audioBase64 = base64Encode(audioBytes);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio selected: ${result.files.single.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Create video with audio
        _createAndPlayVideo(audioBase64);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick audio file.try again!'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Function to create video from backend and play it
  Future<void> _createAndPlayVideo(String? audioBase64) async {
    final FlutterSecureStorage _storage = const FlutterSecureStorage();

    setState(() => _isProcessing = true);

    try {
      final dio = Dio();
      final token = await _storage.read(key: 'jwt');
      // Prepare request data
      Map<String, dynamic> requestData = {
        'images': widget.reel.images,
        'captions': widget.reel.captions,
      };

      // Add audio bytes if provided
      if (audioBase64 != null) {
        requestData['audioBytes'] = audioBase64;
      }

      final response = await dio.post(
        '${IP.ip_ffmpeg}/highlight', // Replace with your server address!
        data: requestData,
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 5), // Increase timeout for video processing
          sendTimeout: const Duration(minutes: 2), // Increase timeout for large audio files
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print(response.data);

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/highlight_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await file.writeAsBytes(response.data);

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(videoFilePath: file.path),
          ),
        );
        FlushbarHelper.show(context, message: 'Video created successfully!',backgroundColor: Colors.green);
      } else {
        if (!mounted) return;
        FlushbarHelper.show(
          context,
          message: 'Failed to create video. Please try again.',
          icon: Icons.error,
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      FlushbarHelper.show(context, message: 'Failed to create video',backgroundColor: Colors.red,icon: Icons.error);

    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(SingleReelWidget.borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageSlideshow(images: widget.reel.images, currentIndex: _currentIndex),
              const GradientOverlay(),
              CaptionWidget(caption: widget.reel.captions[_currentIndex]),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Transform.scale(
            scale: 0.8,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isProcessing
                  ? FloatingActionButton(
                key: const ValueKey('loading'),
                heroTag: "reel_loading_fab_${widget.reel.hashCode}", // Unique hero tag
                mini: true,
                backgroundColor: Colors.grey[400],
                elevation: 3,
                onPressed: null,
                child: const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
                  : FloatingActionButton(
                key: const ValueKey('play'),
                heroTag: "reel_play_fab_${widget.reel.hashCode}", // Unique hero tag
                mini: true,
                backgroundColor: Colors.blue,
                elevation: 4,
                onPressed: _showAudioSelectionDialog,
                child: const Icon(Icons.play_arrow, size: 30, color: Colors.white),
                tooltip: 'Create Slideshow Video',
              ),
            ),
          ),
        ),
      ],
    );
  }
}