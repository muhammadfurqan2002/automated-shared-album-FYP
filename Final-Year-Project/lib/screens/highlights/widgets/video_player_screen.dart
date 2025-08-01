import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class VideoPlayerScreen extends StatefulWidget {
  final String videoFilePath;
  const VideoPlayerScreen({Key? key, required this.videoFilePath}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isFullScreen = false;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  final List<double> _playbackSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.file(File(widget.videoFilePath))
      ..initialize().then((_) {
        setState(() {
          _totalDuration = _controller.value.duration;
        });
        _controller.play();
        _isPlaying = true;

        _controller.addListener(() {
          setState(() {
            _currentPosition = _controller.value.position;
            _isPlaying = _controller.value.isPlaying;
          });
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  void _changeVolume(double value) {
    setState(() {
      _volume = value;
      _controller.setVolume(_volume);
    });
  }

  void _changePlaybackSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      _controller.setPlaybackSpeed(_playbackSpeed);
    });
  }

  void _seekToPosition(double value) {
    final position = Duration(milliseconds: (value * _totalDuration.inMilliseconds).round());
    _controller.seekTo(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _shareVideo() {
    Share.shareXFiles([XFile(widget.videoFilePath)], text: 'Check out this video!');
  }

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Playback Speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _playbackSpeeds.map((speed) {
            return RadioListTile<double>(
              title: Text('${speed}x'),
              value: speed,
              groupValue: _playbackSpeed,
              onChanged: (value) {
                _changePlaybackSpeed(value!);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.black.withOpacity(0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.volume_down, color: Colors.white),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: _changeVolume,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white54,
                  ),
                ),
                Icon(Icons.volume_up, color: Colors.white),
              ],
            ),
            Row(
              children: [
                Text(_formatDuration(_currentPosition), style: TextStyle(color: Colors.white)),
                Expanded(
                  child: Slider(
                    value: _totalDuration.inMilliseconds > 0
                        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                        : 0.0,
                    onChanged: _seekToPosition,
                    activeColor: Colors.red,
                    inactiveColor: Colors.white54,
                  ),
                ),
                Text(_formatDuration(_totalDuration), style: TextStyle(color: Colors.white)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.share, color: Colors.white),
                  onPressed: _shareVideo,
                ),
                IconButton(
                  icon: Icon(Icons.speed, color: Colors.white),
                  onPressed: _showSpeedDialog,
                ),
                IconButton(
                  icon: Icon(
                    _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                  ),
                  onPressed: _toggleFullScreen,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller.value.isInitialized
          ? GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
            if (_showControls)
              Positioned(
                top: 40,
                left: 12,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            if (_showControls) _buildControls(),
            if (_showControls)
              Center(
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 64,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
          ],
        ),
      )
          : const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
