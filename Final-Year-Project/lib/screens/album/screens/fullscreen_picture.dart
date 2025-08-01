// file: full_picture_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fyp/utils/flashbar_helper.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';

import 'package:fyp/models/image_model.dart';
import 'package:fyp/providers/images_provider.dart';
import 'package:fyp/providers/sharedAlbum_provider.dart';
import 'package:fyp/utils/snackbar_helper.dart';
import '../../../services/image_service.dart';
import '../../../utils/image_downloader.dart';
import '../widgets/dialog_helper.dart';
import '../widgets/image_transformation_menu.dart';
import '../widgets/image_transformation_service.dart';
import '../widgets/overlay_button.dart';

class FullPictureScreen extends StatefulWidget {
  final List<ImageModel> images;
  final int initialIndex;

  const FullPictureScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<FullPictureScreen> createState() => _FullPictureScreenState();
}

class _FullPictureScreenState extends State<FullPictureScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = false;
  Timer? _overlayTimer;
  bool _isProcessing = false;

  // Constants
  static const Duration _overlayDuration = Duration(seconds: 2);
  static const Duration _animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
      if (mounted) {
        setState(() => _showOverlay = false);
      }
    });
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
      if (_showOverlay) {
        _startOverlayTimer();
      } else {
        _overlayTimer?.cancel();
      }
    });
  }

  void _showProcessingDialog({required String title,required String path}) {
    DialogHelper.showProcessingDialog(context, title: title,animationPath: path,width:150 ,height:200 );
  }

  void _showConfirmationDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    DialogHelper.showConfirmationDialog(
      context,
      title: title,
      content: content,
      onConfirm: onConfirm,
    );
  }

  Future<void> _deleteCurrentImage() async {
    if (_isProcessing || widget.images.isEmpty) return;

    final deletedImage = widget.images[_currentIndex];
    final imagesProvider = Provider.of<ImagesProvider>(context, listen: false);
    final sharedImagesProvider = Provider.of<SharedAlbumProvider>(context, listen: false);

    setState(() => _isProcessing = true);
    _showProcessingDialog(title: 'Deleting...', path: 'assets/animations/delete.json');

    try {
      await imagesProvider.deleteImage(deletedImage.id);

      if (imagesProvider.error == null) {
        sharedImagesProvider.deleteImage(deletedImage.id);

        // Remove from local list
        setState(() {
          widget.images.removeAt(_currentIndex);
          if (widget.images.isNotEmpty) {
            _currentIndex = _currentIndex.clamp(0, widget.images.length - 1);
            _pageController.jumpToPage(_currentIndex);
          }
        });

        if (!mounted) return;
        Navigator.of(context).pop(); // Close processing dialog

        SnackbarHelper.showSuccessSnackbar(context, 'Image deleted successfully!');

        if (widget.images.isEmpty) {
          Navigator.of(context).pop(); // Exit screen if no images left
        }

      } else {
        // If backend returned an error
        if (!mounted) return;
        Navigator.of(context).pop(); // Close processing dialog
        SnackbarHelper.showErrorSnackbar(context, imagesProvider.error!);
      }

    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close processing dialog
      final errorMessage = imagesProvider.error ?? 'Failed to delete image.';
      SnackbarHelper.showErrorSnackbar(context, errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }


  Future<void> _downloadCurrentImage() async {
    final image = widget.images[_currentIndex];
    await downloadSelectedImages(context, [image]);
  }

  Future<void> _applyImageTransformation(ImageTransformation transformation) async {
    if (_isProcessing) return;

    final image = widget.images[_currentIndex];
    final transformationService = ImageTransformationService();
    final transformationName = transformationService.getTransformationInfo(transformation)['name']!;

    setState(() => _isProcessing = true);
    _showProcessingDialog(title: 'Processing...',path: 'assets/animations/ai-processing.json');

    try {
      final processedImagePath = await transformationService.applyTransformation(
        transformation: transformation,
        imageUrl: image.s3Url,
        imageId: image.id,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      await DialogHelper.showTransformedImageDialog(
          context,
          processedImagePath,
          transformation
      );
    } catch (error) {
      if (!mounted) return;

      Navigator.of(context).pop(); // Close processing dialog
      SnackbarHelper.showErrorSnackbar(context, '$transformationName failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showTransformationMenu() {
    showImageTransformationMenu(
      context,
      onTransformationSelected: _applyImageTransformation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRole = context.watch<SharedAlbumProvider>().currentUserRole;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleOverlay,
        child: Stack(
          children: [
            // Fullscreen Image Viewer using PhotoViewGallery
            PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (context, index) {
                final image = widget.images[index];
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(image.s3Url),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  heroAttributes: const PhotoViewHeroAttributes(tag: 'fullscreen_image'),
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.error, color: Colors.white, size: 48),
                  ),
                );
              },
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(),
              ),
            ),

            // Overlay Buttons (Back, Download, Delete, etc.)
            OverlayButtons(
              showOverlay: _showOverlay,
              animationDuration: _animationDuration,
              onBackPressed: () => Navigator.of(context).pop(),
              onTransformPressed: _showTransformationMenu,
              onDeletePressed: () {
                if (userRole != 'admin') {
                  FlushbarHelper.show(
                    context,
                    message: 'Only an album admin can delete photos',
                    backgroundColor: Colors.red,
                    icon: Icons.warning,
                  );
                } else {
                  _showConfirmationDialog(
                    title: 'Delete Photo',
                    content: 'Are you sure you want to delete this photo?',
                    onConfirm: _deleteCurrentImage,
                  );
                }
              },
              onDownloadPressed: _downloadCurrentImage,
            ),
          ],
        ),
      ),
    );
  }
}