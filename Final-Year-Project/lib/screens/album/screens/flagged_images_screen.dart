// file: flagged_full_picture_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fyp/screens/album/widgets/flagged_image_transformation_service.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';

import 'package:fyp/models/image_model.dart';
import 'package:fyp/providers/flaggedImage_provider.dart';
import 'package:fyp/utils/snackbar_helper.dart';
import '../../../utils/image_downloader.dart';
import '../widgets/dialog_helper.dart';
import '../widgets/flagged_image_menu.dart';
import '../widgets/flagged_overlay_buttons.dart';

enum FlagType { blur, duplicate }

class FlaggedFullPictureScreen extends StatefulWidget {
  final List<ImageModel> images;
  final int initialIndex;
  final FlagType flagType;

  const FlaggedFullPictureScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
    required this.flagType,
  });

  @override
  State<FlaggedFullPictureScreen> createState() => _FlaggedFullPictureScreenState();
}

class _FlaggedFullPictureScreenState extends State<FlaggedFullPictureScreen> {
  late List<ImageModel> _images;
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = false;
  Timer? _overlayTimer;
  bool _isProcessing = false;

  static const Duration _overlayDuration = Duration(seconds: 2);
  static const Duration _animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    // make a mutable copy
    _images = List<ImageModel>.from(widget.images);
    _currentIndex = widget.initialIndex.clamp(0, _images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startOverlayTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(_overlayDuration, () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
      if (_showOverlay) _startOverlayTimer();
      else _overlayTimer?.cancel();
    });
  }

  Future<void> _deleteCurrentImage() async {
    if (_isProcessing || _images.isEmpty) return;

    final toDelete = _images[_currentIndex];
    final flaggedProvider = Provider.of<FlaggedImageProvider>(context, listen: false);

    setState(() => _isProcessing = true);
    DialogHelper.showProcessingDialog(
      context,
      title: 'Deleting...',
      animationPath: 'assets/animations/delete.json',
      width: 150,
      height: 200,
    );

    try {
      await flaggedProvider.deleteImage(toDelete.id);
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss dialog

      if (flaggedProvider.error != null) {
        SnackbarHelper.showErrorSnackbar(context, flaggedProvider.error!);
        return;
      }

      setState(() {
        _images.removeAt(_currentIndex);
        if (_images.isNotEmpty) {
          _currentIndex = _currentIndex.clamp(0, _images.length - 1);
          _pageController.jumpToPage(_currentIndex);
        }
      });

      SnackbarHelper.showSuccessSnackbar(context, 'Image deleted successfully!');

      if (_images.isEmpty) Navigator.of(context).pop(); // exit screen
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      final errorMsg = flaggedProvider.error ?? 'Failed to delete image';
      SnackbarHelper.showErrorSnackbar(context, errorMsg);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }


  Future<void> _unflagCurrentImage() async {
    if (_isProcessing || _images.isEmpty) return;

    final toUnflag = _images[_currentIndex];
    final provider = Provider.of<FlaggedImageProvider>(context, listen: false);

    setState(() => _isProcessing = true);
    DialogHelper.showProcessingDialog(
      context,
      title: 'Unflagging...',
      animationPath: 'assets/animations/unflag.json',
      width: 150,
      height: 200,
    );

    try {
      if (widget.flagType == FlagType.duplicate) {
        await provider.unflagDuplicateImage(toUnflag.id);
      } else {
        await provider.unflagBlurImage(toUnflag.id);
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss dialog

      if (provider.error != null) {
        SnackbarHelper.showErrorSnackbar(context, provider.error!);
        return;
      }

      setState(() {
        _images.removeAt(_currentIndex);
        if (_images.isNotEmpty) {
          _currentIndex = _currentIndex.clamp(0, _images.length - 1);
          _pageController.jumpToPage(_currentIndex);
        }
      });

      SnackbarHelper.showSuccessSnackbar(context, 'Image unflagged successfully!');
      if (_images.isEmpty) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      final errorMsg = provider.error ?? 'Failed to unflag image';
      SnackbarHelper.showErrorSnackbar(context, errorMsg);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }



  Future<void> _downloadCurrentImage() async {
    if (_images.isEmpty) return;
    final image = _images[_currentIndex];
    await downloadSelectedImages(context, [image]);
  }

  void _showUnflagMenu() {
    showFlaggedImageMenu(
      context,
      onUnflagSelected: _unflagCurrentImage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleOverlay,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _images.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) {
                final img = _images[i];
                return PhotoView(
                  imageProvider: CachedNetworkImageProvider(img.s3Url),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  enableRotation: true,
                  heroAttributes: const PhotoViewHeroAttributes(tag: 'flagged_image'),
                );
              },
            ),

            FlaggedOverlayButtons(
              showOverlay: _showOverlay,
              animationDuration: _animationDuration,
              flagType: widget.flagType,
              onBackPressed:    () => Navigator.of(context).pop(),
              onMorePressed:    _showUnflagMenu,
              onDeletePressed:  () => _deleteCurrentImage(),
              onDownloadPressed:() => _downloadCurrentImage(),
            ),
          ],
        ),
      ),
    );
  }
}
