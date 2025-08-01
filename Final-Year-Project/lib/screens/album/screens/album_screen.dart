import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:fyp/screens/album/widgets/dialog_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:fyp/models/album_model.dart';
import 'package:fyp/models/image_model.dart';
import 'package:fyp/providers/album_provider.dart';
import 'package:fyp/providers/suggestions_provider.dart';
import 'package:fyp/providers/sharedAlbum_provider.dart';
import 'package:fyp/screens/album/widgets/action_button.dart';
import 'package:fyp/screens/album/widgets/album_header.dart';
import 'package:fyp/screens/album/widgets/album_title.dart';
import 'package:fyp/screens/album/widgets/share_user_modal.dart';
import 'package:fyp/screens/album/widgets/toggle_button_group.dart';
import 'package:fyp/utils/snackbar_helper.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../../../providers/session_manager.dart';
import '../../../services/album_notification_service.dart';
import '../../../services/image_service.dart';
import '../../../utils/image_downloader.dart';
import '../../../utils/lottie_loading_widget.dart';
import 'album_setting.dart';
import 'fullscreen_picture.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Album album;
  const AlbumDetailScreen({Key? key, required this.album}) : super(key: key);

  @override
  _AlbumDetailScreenState createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> with AutomaticKeepAliveClientMixin {
  bool isPhotosSelected = true;
  bool isSelectingForDownload = false;
  // Upload cancellation flag
  bool _cancelUpload = false;
  List<ImageModel> selectedImagesForDownload = [];
  // final ImagePicker _picker = ImagePicker();
  bool isDownloading = false;
  late Album currentAlbum;
  List<dynamic> recognitionResults = [];
  bool _isProcessing = false;

  // Pagination for regular images
  int currentPage = 1;
  final int limit = 10;
  bool _isLoadingMore = false;
  bool _hasMoreImages = true;
  bool _regularImagesFetched = false;

  // Pagination for shared images
  int sharedCurrentPage = 2;
  bool _isLoadingMoreShared = false;
  bool _hasMoreSharedImages = true;
  bool _sharedImagesFetched = false;

  // Track tab changes to prevent duplicate loading
  bool _isChangingTab = false;

  final ScrollController _scrollController = ScrollController();
  bool _isNavigatingToFullScreen = false;

  late String currentUserRole;
  @override
  bool get wantKeepAlive => true;
  late final StreamSubscription<int> _roleSub;

  @override
  void initState() {
    super.initState();
    currentAlbum = widget.album;

    // 1️⃣ Listen for live role updates
    _setupNotificationListener();

    // 2️⃣ Kick off the very first load of members & images
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SessionManager.checkJwtAndLogoutIfExpired(context);

      final sharedProv = Provider.of<SharedAlbumProvider>(context, listen: false);
      sharedProv
          .fetchMembersWithDetails(currentAlbum.id)
          .then((_) => sharedProv.updateCurrentUserRole());
      _resetAndLoadInitialImages();
    });

    // 3️⃣ Wire up infinite scroll
    _scrollController.addListener(_onScroll);
  }

  void _setupNotificationListener() {
    _roleSub = AlbumNotificationService()
        .onRoleUpdated
        .listen((albumId) {
      if (albumId == currentAlbum.id && mounted) {
        final sharedProv = Provider.of<SharedAlbumProvider>(context, listen: false);
        sharedProv
            .fetchMembersWithDetails(albumId)
            .then((_) => sharedProv.updateCurrentUserRole());
        // _resetAndLoadInitialImages();
      }
    });
  }

  @override
  void dispose() {
    _roleSub.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  // Reset all image data and load only the first page
  void _resetAndLoadInitialImages() {
    if (mounted) {
      final imagesProvider = Provider.of<ImagesProvider>(context, listen: false);

      // Reset image state
      setState(() {
        currentPage = 1;
        sharedCurrentPage = 1;
        _hasMoreImages = true;
        _hasMoreSharedImages = true;
        _regularImagesFetched = false;
        _sharedImagesFetched = false;
      });

      // Clear existing cached images for this album
      imagesProvider.clearAlbumImages(currentAlbum.id);

      // Load first page of current tab
      if (isPhotosSelected) {
        _fetchImages(forceRefresh: true);
      } else {
        _fetchSharedImages(forceRefresh: true);
      }
    }
  }



  // Add method to fetch shared images with pagination
  Future<void> _fetchSharedImages({bool forceRefresh = false}) async {
    if (_isLoadingMoreShared) return;

    try {
      setState(() {
        _isLoadingMoreShared = true;
      });

      final sharedAlbumProvider = Provider.of<SharedAlbumProvider>(context, listen: false);

      // Clear existing shared images if forcing refresh
      if (forceRefresh) {
        sharedAlbumProvider.clearSharedImages();
        sharedCurrentPage = 1;
      }

      await sharedAlbumProvider.fetchSharedImages(
          currentAlbum.id,
          page: sharedCurrentPage,
          limit: limit
      );

      if (mounted) {
        setState(() {
          _sharedImagesFetched = true;
          if (sharedAlbumProvider.sharedImages.length < sharedCurrentPage * limit) {
            _hasMoreSharedImages = false;
          } else {
            sharedCurrentPage++;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackbar(
          context,
          "Failed to load shared images: ${e.toString()}",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreShared = false;
        });
      }
    }
  }

  // @override
  // void dispose() {
  //   _scrollController.removeListener(_onScroll);
  //   _scrollController.dispose();
  //   super.dispose();
  // }

  void _onScroll() {
    if (_isNavigatingToFullScreen) return;

    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {

      if (isPhotosSelected) {
        if (!_isLoadingMore && _hasMoreImages) {
          _fetchImages();
        }
      } else {
        if (!_isLoadingMoreShared && _hasMoreSharedImages) {
          _fetchSharedImages();
        }
      }
    }
  }

  Future<void> _fetchImages({bool forceRefresh = false}) async {
    if (_isLoadingMore) return;
    try {
      setState(() {
        _isLoadingMore = true;
      });
      final imagesProvider = Provider.of<ImagesProvider>(context, listen: false);
      if (forceRefresh) {
        imagesProvider.clearAlbumImages(currentAlbum.id);
        currentPage = 1;
      }
      await imagesProvider.fetchImages(currentAlbum.id, page: currentPage, limit: limit);
      if (mounted) {
        setState(() {
          _regularImagesFetched = true;
          final albumImages = imagesProvider.getImagesForAlbum(currentAlbum.id);
          if (albumImages.length < currentPage * limit) {
            _hasMoreImages = false;
          } else {
            currentPage++;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackbar(
          context,
          "Failed to load images",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _refreshAlbumData() {
    final albumProvider = Provider.of<AlbumProvider>(context, listen: false);
    setState(() {
      for (var album in albumProvider.albums) {
        if (album.id == currentAlbum.id) {
          currentAlbum = album;
          break;
        }
      }
    });
  }

  // Smart loading when switching between tabs
  void _handleTabChange(bool isPhotos) {
    if (isPhotos == isPhotosSelected || _isChangingTab) return;

    setState(() {
      _isChangingTab = true;
      isPhotosSelected = isPhotos;
      // Clear selection when switching tabs
      if (isSelectingForDownload) {
        isSelectingForDownload = false;
        selectedImagesForDownload.clear();
      }
    });

    // Load data for the newly selected tab if not loaded yet
    if (isPhotos) {
      if (!_regularImagesFetched) {
        _fetchImages();
      }
    } else {
      if (!_sharedImagesFetched) {
        _fetchSharedImages();
      }
    }

    // Allow tab changes again after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isChangingTab = false;
        });
      }
    });
  }

  void _showShareModal() {
    showDialog(
      context: context,
      builder: (context) => ShareModal(
          suggestions: recognitionResults,
          albumId: currentAlbum.id,
          adminId: currentAlbum.userId
      ),
    );
  }

  Future<void> _pickAndUploadImages() async {
    // 1️⃣ Launch picker
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 20,
        requestType: RequestType.image,
        gridCount: 4,
        themeColor: Colors.blue,
      ),
    );
    if (assets == null || assets.isEmpty) return;

    // 2️⃣ Convert to File
    final List<File?> files = await Future.wait(assets.map((asset) => asset.file));
    final images = files.where((f) => f != null).cast<File>().toList();

    // 3️⃣ Show progress dialog
    ValueNotifier<int> progress = ValueNotifier<int>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Center(child: const Text("Uploading images",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),)),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, value, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value / images.length),
              const SizedBox(height: 20),
              Text("Uploading $value of ${images.length} images"),
            ],
          ),
        ),
      ),
    );

    // 4️⃣ Upload one by one with error check
    final imagesProvider = Provider.of<ImagesProvider>(context, listen: false);

    try {
      for (final file in images) {
        await imagesProvider.uploadImage(file, currentAlbum.id);

        if (imagesProvider.error != null) {
          Navigator.of(context).pop(); // close progress dialog
          SnackbarHelper.showErrorSnackbar(context, imagesProvider.error!);
          return;
        }

        progress.value++;
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // close progress dialog

      SnackbarHelper.showSuccessSnackbar(
        context,
        "${images.length} images uploaded successfully!",
      );

      // Show processing snackbar
      final processingSnackBar = ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please wait, processing images..."),
          duration: Duration(seconds: 30),
        ),
      );
      await Future.delayed(const Duration(seconds: 10));
      processingSnackBar.close();

      // Refresh UI
      _resetAndLoadInitialImages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please wait finding your users")),
      );
      await _fetchSuggestions();

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // close progress dialog
        SnackbarHelper.showErrorSnackbar(context, "Failed to upload images!");
      }
    }
  }




  Future<void> _fetchSuggestions() async {
    if (!mounted) return;

    final suggestionProvider = Provider.of<SuggestionProvider>(context, listen: false);

    setState(() {
      _isProcessing = true;
    });

    final success = await suggestionProvider.pollSuggestions(currentAlbum.id);

    if (kDebugMode) {
      print("Poll suggestions result: $success");
      print("Suggestion details: ${suggestionProvider.details}");
      print("Recognition results length: ${suggestionProvider.details['details']?.length ?? 0}");
    }

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      recognitionResults = suggestionProvider.details['details'] ?? [];
    });

    if (success && recognitionResults.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) _showShareModal();
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Suggestions not available yet. Please try again later."),
        ),
      );
    }
  }
  Future<void> _fetchSuggestionsManually() async {
    if (!mounted) return;

    final suggestionProvider = Provider.of<SuggestionProvider>(context, listen: false);

    setState(() {
      _isProcessing = true;
    });

    await suggestionProvider.fetchSuggestionsManually(currentAlbum.id);


    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      recognitionResults = suggestionProvider.details['details'] ?? [];
    });

    if (recognitionResults.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) _showShareModal();
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Suggestions not available yet. Please try again later."),
        ),
      );
    }
  }



  void _toggleSelection(ImageModel image) {
    setState(() {
      if (selectedImagesForDownload.contains(image)) {
        selectedImagesForDownload.remove(image);
      } else {
        selectedImagesForDownload.add(image);
      }
    });
  }


  void _downloadSelectedImages() async {
    if (selectedImagesForDownload.isEmpty) {
      SnackbarHelper.showErrorSnackbar(
        context,
        "Please select at least one image to download.",
      );
      return;
    }

    setState(() {
      isDownloading = true;
    });

    try {
      await downloadSelectedImages(context, selectedImagesForDownload);

      if (!mounted) return;

    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackbar(
          context,
          "Download failed: ${e.toString()}",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isDownloading = false;
          selectedImagesForDownload.clear();
          isSelectingForDownload = false;
        });
      }
    }
  }

  void _deleteSelectedImages() {
    if (selectedImagesForDownload.isEmpty) {
      SnackbarHelper.showErrorSnackbar(
        context,
        "Please select at least one image to delete.",
      );
      return;
    }

    final parentContext = context;

    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Delete Selected Images"),
          content: Text(
            "Are you sure you want to delete ${selectedImagesForDownload.length} images?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                DialogHelper.showProcessingDialog(
                  context,
                  title: 'Deleting...',
                  animationPath: "assets/animations/delete.json",
                  width: 150,
                  height: 200,
                );

                final sharedImagesProvider = Provider.of<SharedAlbumProvider>(parentContext, listen: false);
                final imageProvider = Provider.of<ImagesProvider>(parentContext, listen: false);
                final imageIds = selectedImagesForDownload.map((i) => i.id).toList();

                try {
                  await imageProvider.deleteImages(imageIds);

                  // Close progress dialog
                  if (mounted) {
                    Navigator.of(parentContext, rootNavigator: true).pop();
                  }

                  if (imageProvider.error == null) {
                    // Only update state and show success if no error
                    sharedImagesProvider.deleteSharedImages(imageIds);
                    if (mounted) {
                      setState(() {
                        selectedImagesForDownload.clear();
                        isSelectingForDownload = false;
                      });
                      SnackbarHelper.showSuccessSnackbar(
                        parentContext,
                        "Selected images deleted successfully!",
                      );
                    }
                  } else {
                    // Show backend-provided error
                    SnackbarHelper.showErrorSnackbar(parentContext, imageProvider.error!);
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(parentContext, rootNavigator: true).pop();
                    print(imageProvider.error);
                    final errorMessage = imageProvider.error ?? "Failed to delete images.";
                    SnackbarHelper.showErrorSnackbar(parentContext, errorMessage);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }


  void _openFullPictureScreen(int initialIndex, List<ImageModel> images) async {
    setState(() {
      _isNavigatingToFullScreen = true;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullPictureScreen(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );

    setState(() {
      _isNavigatingToFullScreen = false;
    });
  }

  Widget _buildUpperActionRow() {
    final userRole = context.watch<SharedAlbumProvider>().currentUserRole;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ActionButton(
          label: isSelectingForDownload ? "Cancel" : "Select",
          onTap: () {
            setState(() {
              isSelectingForDownload = !isSelectingForDownload;
              selectedImagesForDownload.clear();
            });
          },
        ),
        const SizedBox(width: 10),
        ActionButton(
          label: "Share",
          onTap: userRole != 'admin' ? null : _fetchSuggestionsManually,
        ),
      ],
    );
  }

  Widget _buildLowerActionRow() {
    final userRole = context.watch<SharedAlbumProvider>().currentUserRole;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ActionButton(
          label: "Download (${selectedImagesForDownload.length})",
          onTap: _downloadSelectedImages,
        ),
        const SizedBox(width: 10),
        ActionButton(
          label:  "Delete (${ userRole != 'admin' ? 0: selectedImagesForDownload.length})",
          onTap:  userRole != 'admin' ? null : _deleteSelectedImages,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final imagesProvider = Provider.of<ImagesProvider>(context);
    final sharedAlbumProvider = Provider.of<SharedAlbumProvider>(context);
    final memberCount = sharedAlbumProvider.participants.length;

    final currentUserRole = context.watch<SharedAlbumProvider>().currentUserRole;
    print("Inside album_screen button – role is $currentUserRole");
    // Get real images from provider
    final realImages = imagesProvider
        .getImagesForAlbum(currentAlbum.id);

    // Get shared images from shared album provider
    final sharedImages = sharedAlbumProvider.sharedImages;

    // Choose which images to display based on toggle
    final imagesToDisplay = isPhotosSelected ? realImages : sharedImages;

    // Calculate loading state based on the selected tab - avoid double indicators
    final bool isLoading = isPhotosSelected
        ? (!_regularImagesFetched && imagesProvider.isLoading)
        : (!_sharedImagesFetched && sharedAlbumProvider.isLoading && !_isChangingTab);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            margin: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.settings, color: Colors.white, size: 22),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AlbumSetting(
                        album: currentAlbum,
                        participants: sharedAlbumProvider.participants
                    ),
                  ),
                );
                _refreshAlbumData();
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _resetAndLoadInitialImages(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: AlbumHeader(album: currentAlbum)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
            SliverToBoxAdapter(
              child: AlbumTitleSection(
                album: currentAlbum,
                photoCount: imagesToDisplay.length,
                memberCount: memberCount,
              ),
            ),
            const SliverToBoxAdapter(child:  SizedBox(height: 5)),
            SliverToBoxAdapter(child: _buildUpperActionRow()),
            // 5. Lower action row (when selecting)
            if (isSelectingForDownload)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.only(bottom: 5,top: 10),
                child: _buildLowerActionRow(),
              )),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(child: ToggleButtonGroup(
              isPhotosSelected: isPhotosSelected,
              onToggle: _handleTabChange,
            )),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            if (imagesToDisplay.isEmpty && !isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No images found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      (isPhotosSelected && currentUserRole == 'admin')
                          ? ElevatedButton.icon(
                        onPressed: _pickAndUploadImages,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Images'),
                      )
                          : const SizedBox(),
                    ],
                  ),
                ),
              ) else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 60,left: 10,right: 10),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 5,
                crossAxisSpacing: 10,
                childCount: imagesToDisplay.length + ( (isPhotosSelected ? _hasMoreImages : _hasMoreSharedImages) ? 1 : 0 ),
                itemBuilder: (context, index) {
                  final hasMore = isPhotosSelected ? _hasMoreImages : _hasMoreSharedImages;
                  final isPaginating = isPhotosSelected ? _isLoadingMore : _isLoadingMoreShared;

                  if (index == imagesToDisplay.length && hasMore) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          height: 120,
                          width: 120,
                          child: LottieWidget(),
                        ),
                      ),
                    );
                  }
                  // image tile
                  final image = imagesToDisplay[index];
                  final isSelected = selectedImagesForDownload.contains(image);
                  return GestureDetector(
                    onTap: isSelectingForDownload
                        ? () => _toggleSelection(image)
                        : () => _openFullPictureScreen(index, imagesToDisplay),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: image.s3Url,
                            width: double.infinity,
                            height: index.isEven ? 150 : 200,
                            fit: BoxFit.cover,
                            memCacheWidth: (600 * MediaQuery.of(context).devicePixelRatio).round(),
                            memCacheHeight: ((index.isEven ? 300 : 400) * MediaQuery.of(context).devicePixelRatio).round(),
                            placeholder: (c, u) => Shimmer.fromColors(
                              baseColor: Colors.grey.shade300,
                              highlightColor: Colors.grey.shade100,
                              child: Container(
                                width: double.infinity,
                                height: index.isEven ? 150 : 200,
                                color: Colors.white,
                              ),
                            ),
                            errorWidget: (c, u, e) => const Icon(Icons.error),
                          ),
                        ),
                        if (isSelectingForDownload)
                          Positioned(
                            top: 5,
                            right: 10,
                            child: Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              color: Colors.blue,
                            ),
                          ),

                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),


      floatingActionButton:  context.watch<SharedAlbumProvider>().currentUserRole!='admin'?null: FloatingActionButton(
        onPressed: _isProcessing ? null : _pickAndUploadImages,
        mini: true,
        backgroundColor: _isProcessing ? Colors.grey : Colors.blue,
        child: _isProcessing
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            )
        )
            : const Icon(Icons.add, size: 30, color: Colors.white),
      ),
    );
  }
}