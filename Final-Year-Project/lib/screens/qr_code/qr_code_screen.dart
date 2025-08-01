import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fyp/services/api_service.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import '../../../models/album_model.dart';
import '../../providers/session_manager.dart';
import '../album/screens/album_screen.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({Key? key}) : super(key: key);

  @override
  _QrScanScreenState createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> with WidgetsBindingObserver {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  bool _isFlashOn = false;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    SessionManager.checkJwtAndLogoutIfExpired(context);

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;

    if (state == AppLifecycleState.paused) {
      controller.pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      controller.resumeCamera();
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (_scanned) return;
      _scanned = true;

      final tokenFromQR = scanData.code;
      debugPrint('[QR] token from QR: $tokenFromQR');

      if (tokenFromQR == null || tokenFromQR.length < 20) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code')),
        );
        Future.delayed(const Duration(seconds: 2), () => _scanned = false);
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final token = await _storage.read(key: 'jwt');

        final url = Uri.parse('${ApiService().baseUrl}/shared/join-with-token');
        debugPrint('[HTTP] POST $url');

        final resp = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            "token": tokenFromQR,
          }),
        );
        print(resp);

        Navigator.of(context).pop(); // remove loading

        if (resp.statusCode == 200) {
          final Map<String, dynamic> jsonResp = json.decode(resp.body);
          final albumJson = jsonResp['album'] as Map<String, dynamic>;
          final Album album = Album.fromJson(albumJson);
          debugPrint('[QR] Joined album: ${album.id} - ${album.albumTitle}');

          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AlbumDetailScreen(album: album),
            ),
          );

          _scanned = false;
          if (_controller != null) {
            await _controller!.resumeCamera();
          }
        } else {
          final errorText = json.decode(resp.body)['error'] ?? 'Join failed';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorText)),
          );
          _scanned = false;
        }
      } catch (e) {
        Navigator.of(context).pop();
        debugPrint('[ERROR] $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        _scanned = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        QRView(
          key: _qrKey,
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: Theme.of(context).colorScheme.secondary,
            borderRadius: 16,
            borderLength: 40,
            borderWidth: 8,
            cutOutSize: MediaQuery.of(context).size.width * 0.7,
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              _buildCircleButton(
                icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                onTap: () async {
                  if (_controller == null) return;
                  await _controller!.toggleFlash();
                  final flash = await _controller!.getFlashStatus();
                  setState(() => _isFlashOn = flash ?? false);
                },
              ),

            ],
          ),
        ),
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 24,
          left: 24,
          right: 24,
          child: Center(
            child: Text(
              'Align the QR code within the frame to scan',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}