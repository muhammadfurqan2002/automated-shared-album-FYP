import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:photo_view/photo_view.dart';
import '../../../utils/image_downloader.dart';
import 'image_transformation_service.dart';

class DialogHelper {
  static void showProcessingDialog(
      BuildContext context, {
        required String title,
        required String animationPath,
        required double width,
        required double height,
      }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white.withOpacity(0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(8),
            constraints: BoxConstraints(
              minWidth: width * 0.8,
              maxWidth: width,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3), // Glassy effect
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 150,
                  height: 200,
                  child: Lottie.asset(
                    animationPath,
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w500
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  static void showConfirmationDialog(
      BuildContext context, {
        required String title,
        required String content,
        required VoidCallback onConfirm,
      }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:Colors.red ,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }



  static Future<void> showTransformedImageDialog(
      BuildContext context,
      String processedImagePath,
      ImageTransformation transformation,
      ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: Stack(
          children: [
            PhotoView(
              imageProvider: processedImagePath.startsWith('http')
                  ? NetworkImage(processedImagePath) as ImageProvider
                  : FileImage(File(processedImagePath)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              heroAttributes: PhotoViewHeroAttributes(tag: '${transformation.name}_image'),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),Positioned(
              top: 20,
              left: 20,
              child: GestureDetector(
                onTap:()async => {
                  await downloadSelectedImages(context, processedImagePath, transformationType: 'unblur'),
                  Navigator.of(context).pop()
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showUnblurredImageDialog(
      BuildContext context,
      String unblurredImagePath,
      ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: Stack(
          children: [
            PhotoView(
              imageProvider: unblurredImagePath.startsWith('http')
                  ? NetworkImage(unblurredImagePath) as ImageProvider
                  : FileImage(File(unblurredImagePath)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              heroAttributes: const PhotoViewHeroAttributes(tag: 'unblurred_image'),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}