// lib/utils/image_downloader.dart

import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fyp/utils/snackbar_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../models/image_model.dart';
import 'components/image_download_progress.dart';

// Function to download either ImageModel list or a single transformed image
Future<void> downloadSelectedImages(
    BuildContext context,
    dynamic imagesToDownload, {
      String? transformedImageFileName,
      String? transformationType,
    }) async {
  List<Map<String, String>> downloadQueue = [];

  // Handle different input types
  if (imagesToDownload is List<ImageModel>) {
    // Case 1: List of ImageModel objects
    if (imagesToDownload.isEmpty) {
      SnackbarHelper.showErrorSnackbar(
        context,
        "Please select at least one image to download.",
      );
      return;
    }

    // Convert ImageModels to download queue entries
    downloadQueue = imagesToDownload.map((image) => {
      'url': image.s3Url,
      'fileName': image.fileName ?? 'image_${DateTime.now().millisecondsSinceEpoch}',
    }).toList();
  } else if (imagesToDownload is String) {
    // Case 2: Single transformed image URL/path
    final imageUrl = imagesToDownload;
    if (imageUrl.isEmpty) {
      SnackbarHelper.showErrorSnackbar(
        context,
        "No image to download.",
      );
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = transformedImageFileName ??
        '${transformationType ?? 'transformed'}_image_$timestamp';

    downloadQueue = [{
      'url': imageUrl,
      'fileName': fileName,
    }];
  } else {
    SnackbarHelper.showErrorSnackbar(
      context,
      "Invalid image format for download.",
    );
    return;
  }

  // Check permissions for Android and iOS
  bool hasPermission = false;
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      final status = await Permission.photos.request();
      hasPermission = status.isGranted;
      if (!hasPermission) {
        SnackbarHelper.showErrorSnackbar(
          context,
          "Media permission is required to save images.",
        );
        return;
      }
    } else {
      final status = await Permission.storage.request();
      hasPermission = status.isGranted;
      if (!hasPermission) {
        SnackbarHelper.showErrorSnackbar(
          context,
          "Storage permission is required to save images.",
        );
        return;
      }
    }
  } else if (Platform.isIOS) {
    final status = await Permission.photos.request();
    hasPermission = status.isGranted;
    if (!hasPermission) {
      SnackbarHelper.showErrorSnackbar(
        context,
        "Photos permission is required to save images.",
      );
      return;
    }
  }

  // Download setup
  final cancelToken = CancelToken();
  OverlayEntry? overlayEntry;
  int downloadedCount = 0;
  int successCount = 0;
  final totalImages = downloadQueue.length;
  final progressController = StreamController<double>.broadcast();
  bool isCancelled = false;
  List<String> savedFilePaths = [];

  // Progress overlay
  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: StreamBuilder<double>(
          stream: progressController.stream,
          initialData: 0.0,
          builder: (context, snapshot) {
            final progress = snapshot.data ?? 0.0;
            return DownloadProgressWidget(
              totalImages: totalImages,
              downloadedImages: downloadedCount,
              progress: progress,
              onCancel: () {
                if (isCancelled) return;
                isCancelled = true;
                cancelToken.cancel("User cancelled download");
                if (overlayEntry?.mounted == true) overlayEntry!.remove();
                if (context.mounted) {
                  if (successCount > 0) {
                    SnackbarHelper.showSuccessSnackbar(
                      context,
                      "$successCount image${successCount > 1 ? 's' : ''} downloaded before cancel",
                    );
                    if (savedFilePaths.isNotEmpty) {
                      launch(savedFilePaths.last);
                    }
                  } else {
                    SnackbarHelper.showSuccessSnackbar(
                      context,
                      "Download cancelled",
                    );
                  }
                }
              },
            );
          },
        ),
      ),
    ),
  );
  Overlay.of(context).insert(overlayEntry);

  final dio = Dio();

  try {
    for (var i = 0; i < downloadQueue.length; i++) {
      if (isCancelled || cancelToken.isCancelled) return;

      final imageInfo = downloadQueue[i];
      final imageUrl = imageInfo['url']!;
      final fileName = imageInfo['fileName']!;

      try {
        // Handle both remote URLs and local file paths
        Uint8List imageData;

        if (imageUrl.startsWith('http')) {
          // Download with cancel support for remote URLs
          final response = await dio.get(
            imageUrl,
            options: Options(responseType: ResponseType.bytes),
            cancelToken: cancelToken,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                final indiv = received / total;
                final overall = (i + indiv) / totalImages;
                if (!progressController.isClosed) progressController.add(overall);
              }
            },
          );
          imageData = Uint8List.fromList(response.data);
        } else {
          // Read local file
          final file = File(imageUrl);
          imageData = await file.readAsBytes();
          // Update progress
          if (!progressController.isClosed) {
            progressController.add((i + 0.5) / totalImages);
          }
        }

        if (isCancelled || cancelToken.isCancelled) return;

        // Save (no cancelToken)
        final result = await ImageGallerySaver.saveImage(
          imageData,
          quality: 100,
          name: fileName,
        );
        if (isCancelled) return;

        // Count success
        if (result != null && (result['isSuccess'] == true || result['isSuccess'] == null)) {
          successCount++;
          downloadedCount++;
          if (!progressController.isClosed) progressController.add(downloadedCount / totalImages);
          final path = result['filePath'];
          if (path != null) savedFilePaths.add(path);
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          // Cancel during download
          print("Download cancelled by user");
          if (overlayEntry?.mounted == true) overlayEntry!.remove();
          if (!progressController.isClosed) await progressController.close();
          if (context.mounted) {
            if (successCount > 0) {
              SnackbarHelper.showSuccessSnackbar(
                context,
                "$successCount image${successCount > 1 ? 's' : ''} downloaded before cancel",
              );
              if (savedFilePaths.isNotEmpty) await launch(savedFilePaths.last);
            } else {
              SnackbarHelper.showSuccessSnackbar(
                context,
                "Download cancelled",
              );
            }
          }
          return;
        }
        print("Error saving image: $e");
        if (context.mounted) {
          SnackbarHelper.showErrorSnackbar(
            context,
            "Error saving image: ${e.toString()}",
          );
        }
        return;
      }
    }

    // Completed without cancel
    if (overlayEntry?.mounted == true) overlayEntry!.remove();
    if (!progressController.isClosed) await progressController.close();

    if (context.mounted) {
      if (successCount > 0) {
        SnackbarHelper.showSuccessSnackbar(
          context,
          "$successCount image${successCount > 1 ? 's' : ''} downloaded successfully!",
        );
        if (savedFilePaths.isNotEmpty) await launch(savedFilePaths.last);
      } else {
        SnackbarHelper.showErrorSnackbar(
          context,
          "No images were downloaded. Please try again.",
        );
      }
    }
  } catch (e) {
    // Skip error on cancel
    if (isCancelled || (e is DioException && e.type == DioExceptionType.cancel)) return;
    print("Global error: $e");
    if (overlayEntry?.mounted == true) overlayEntry!.remove();
    if (!progressController.isClosed) await progressController.close();
    if (context.mounted) {
      SnackbarHelper.showErrorSnackbar(
        context,
        "An error occurred: ${e.toString().replaceAll(RegExp(r'[\\$+]'), '')}",
      );
    }
  }
}