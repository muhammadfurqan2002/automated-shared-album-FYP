
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:fyp/providers/flaggedImage_provider.dart';
import 'package:fyp/screens/album/screens/flagged_images_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../utils/flagged_tab_enum.dart';
import '../../../utils/image_downloader.dart';
import '../../../models/album_model.dart';
import '../../../models/image_model.dart';
import '../../../utils/lottie_loading_widget.dart';
import '../../../utils/snackbar_helper.dart';
import '../widgets/flagged_group_buttons.dart';



class FlaggedImages extends StatefulWidget {
  final Album album;
  const FlaggedImages({super.key, required this.album});

  @override
  State<FlaggedImages> createState() => _FlaggedImagesState();
}

class _FlaggedImagesState extends State<FlaggedImages> {
  // Tab and selection state
  FlaggedImageTab _selectedTab = FlaggedImageTab.duplicate;
  bool _isSelectingForDownload = false;
  List<ImageModel> _selectedImagesForDownload = [];

  // Processing states
  bool _isDeleting = false;
  bool _isUnflagging = false;
  bool _isDownloading = false;
  bool _isNavigatingToFullScreen = false;
  bool _isChangingTab = false;

  // Pagination state for duplicate images
  int _duplicateCurrentPage = 1;
  bool _isLoadingMoreDuplicate = false;
  bool _hasMoreDuplicateImages = true;
  bool _duplicateImagesFetched = false;

  // Pagination state for blur images
  int _blurCurrentPage = 1;
  bool _isLoadingMoreBlur = false;
  bool _hasMoreBlurImages = true;
  bool _blurImagesFetched = false;

  static const int _limit = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialImages();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isPhotosSelected => _selectedTab == FlaggedImageTab.duplicate;
  bool get _isProcessing => _isDeleting || _isUnflagging;
  FlaggedImageProvider get _provider => Provider.of<FlaggedImageProvider>(context, listen: false);

  // Initial data loading
  void _loadInitialImages() {
    _fetchDuplicateImages();
    _fetchBlurImages();
  }

  Future<void> _fetchImages({
    required FlaggedImageTab tab,
    bool forceRefresh = false,
  }) async {
    switch (tab) {
      case FlaggedImageTab.duplicate:
        await _fetchDuplicateImages(forceRefresh: forceRefresh);
        break;
      case FlaggedImageTab.blur:
        await _fetchBlurImages(forceRefresh: forceRefresh);
        break;
    }
  }

  Future<void> _fetchDuplicateImages({bool forceRefresh = false}) async {
    if (_isLoadingMoreDuplicate) return;

    setState(() => _isLoadingMoreDuplicate = true);

    try {
      if (forceRefresh) {
        _provider.clearDuplicateImages();
        _duplicateCurrentPage = 1;
        _hasMoreDuplicateImages = true;
      }

      await _provider.fetchDuplicateImages(
        widget.album.id,
        page: _duplicateCurrentPage,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          _duplicateImagesFetched = true;
          if (_provider.duplicateImages.length < _duplicateCurrentPage * _limit) {
            _hasMoreDuplicateImages = false;
          } else {
            _duplicateCurrentPage++;
          }
        });
      }
    } catch (e) {
      _showErrorSnackbar("Failed to load duplicate images: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoadingMoreDuplicate = false);
      }
    }
  }

  Future<void> _fetchBlurImages({bool forceRefresh = false}) async {
    if (_isLoadingMoreBlur) return;

    setState(() => _isLoadingMoreBlur = true);

    try {
      if (forceRefresh) {
        _provider.clearBlurImages();
        _blurCurrentPage = 1;
        _hasMoreBlurImages = true;
      }

      await _provider.fetchBlurImages(
        widget.album.id,
        page: _blurCurrentPage,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          _blurImagesFetched = true;
          if (_provider.blurImages.length < _blurCurrentPage * _limit) {
            _hasMoreBlurImages = false;
          } else {
            _blurCurrentPage++;
          }
        });
      }
    } catch (e) {
      _showErrorSnackbar("Failed to load blur images: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoadingMoreBlur = false);
      }
    }
  }

  void _onScroll() {
    if (_isNavigatingToFullScreen) return;

    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      _loadMoreImagesForCurrentTab();
    }
  }

  void _loadMoreImagesForCurrentTab() {
    switch (_selectedTab) {
      case FlaggedImageTab.duplicate:
        if (!_isLoadingMoreDuplicate && _hasMoreDuplicateImages) {
          _fetchDuplicateImages();
        }
        break;
      case FlaggedImageTab.blur:
        if (!_isLoadingMoreBlur && _hasMoreBlurImages) {
          _fetchBlurImages();
        }
        break;
    }
  }

  void _handleTabChange(FlaggedImageTab newTab) {
    if (newTab == _selectedTab || _isChangingTab) return;

    setState(() {
      _isChangingTab = true;
      _selectedTab = newTab;
      _clearSelection();
    });

    _loadTabDataIfNeeded(newTab);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _isChangingTab = false);
      }
    });
  }

  void _loadTabDataIfNeeded(FlaggedImageTab tab) {
    switch (tab) {
      case FlaggedImageTab.duplicate:
        if (!_duplicateImagesFetched) {
          _fetchDuplicateImages();
        }
        break;
      case FlaggedImageTab.blur:
        if (!_blurImagesFetched) {
          _fetchBlurImages();
        }
        break;
    }
  }

  void _clearSelection() {
    if (_isSelectingForDownload) {
      setState(() {
        _isSelectingForDownload = false;
        _selectedImagesForDownload.clear();
      });
    }
  }

  void _openFullPictureScreen(int initialIndex, List<ImageModel> images) async {
    setState(() => _isNavigatingToFullScreen = true);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlaggedFullPictureScreen(
          images: images,
          initialIndex: initialIndex,
          flagType: _isPhotosSelected ? FlagType.duplicate : FlagType.blur,
        ),
      ),
    );

    setState(() => _isNavigatingToFullScreen = false);
  }

  void _resetAndLoadInitialImages() {
    if (!mounted) return;

    setState(() {
      _duplicateCurrentPage = 1;
      _blurCurrentPage = 1;
      _hasMoreDuplicateImages = true;
      _hasMoreBlurImages = true;
      _duplicateImagesFetched = false;
      _blurImagesFetched = false;
    });

    _provider.clearBlurImages();
    _provider.clearDuplicateImages();

    _fetchImages(tab: _selectedTab, forceRefresh: true);
  }

  void _toggleSelection(ImageModel image) {
    setState(() {
      if (_selectedImagesForDownload.contains(image)) {
        _selectedImagesForDownload.remove(image);
      } else {
        _selectedImagesForDownload.add(image);
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectingForDownload = !_isSelectingForDownload;
      if (!_isSelectingForDownload) {
        _selectedImagesForDownload.clear();
      }
    });
  }

  Future<void> _unflagSelectedImages() async {
    if (_selectedImagesForDownload.isEmpty) {
      _showErrorSnackbar("No images selected");
      return;
    }

    final bool? confirmed = await _showUnflagConfirmationDialog();
    if (confirmed != true) return;

    setState(() => _isUnflagging = true);

    try {
      final imageIds = _selectedImagesForDownload.map((e) => e.id).toList();

      if (_isPhotosSelected) {
        await _provider.unflagMultipleDuplicateImages(imageIds);
      } else {
        await _provider.unflagMultipleBlurImages(imageIds);
      }

      if (_provider.error != null) {
        _showErrorSnackbar(_provider.error!);
        return;
      }

      _clearSelection();
      _showSuccessSnackbar("Images unflagged successfully");
    } catch (e) {
      _showErrorSnackbar(_provider.error ?? "Failed to unflag images");
    } finally {
      setState(() => _isUnflagging = false);
    }
  }

  Future<void> _deleteSelectedImages() async {
    if (_selectedImagesForDownload.isEmpty) {
      _showErrorSnackbar("No images selected");
      return;
    }

    final bool? confirmed = await _showDeleteConfirmationDialog();
    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final imageIds = _selectedImagesForDownload.map((e) => e.id).toList();
      await _provider.deleteImages(imageIds);

      if (_provider.error != null) {
        _showErrorSnackbar(_provider.error!);
        return;
      }

      _clearSelection();
      _showSuccessSnackbar("Images deleted successfully");
    } catch (e) {
      _showErrorSnackbar(_provider.error ?? "Failed to delete images");
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  Future<bool?> _showDeleteConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Images"),
        content: Text(
          "Are you sure you want to delete ${_selectedImagesForDownload.length} selected images? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showUnflagConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Unflag Images"),
        content: Text(
          "Are you sure you want to unflag ${_selectedImagesForDownload.length} selected images? They will be moved back to the regular album.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Unflag"),
          ),
        ],
      ),
    );
  }


  Future<void> _downloadSelectedImages() async {
    if (_selectedImagesForDownload.isEmpty) {
      _showErrorSnackbar("No images selected");
      return;
    }

    setState(() => _isDownloading = true);

    try {
      await downloadSelectedImages(context, _selectedImagesForDownload);
    } catch (e) {
      _showErrorSnackbar("Failed to download images");
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _selectedImagesForDownload.clear();
          _isSelectingForDownload = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackbarHelper.showErrorSnackbar(context, message);
      });
    }
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      SnackbarHelper.showSuccessSnackbar(context, message);
    }
  }

  List<ImageModel> _getCurrentImages() {
    final flaggedImagesProvider = Provider.of<FlaggedImageProvider>(context);
    return _isPhotosSelected
        ? flaggedImagesProvider.duplicateImages
        : flaggedImagesProvider.blurImages;
  }

  bool _isCurrentTabLoading() {
    final flaggedImagesProvider = Provider.of<FlaggedImageProvider>(context);
    return _isPhotosSelected
        ? (!_duplicateImagesFetched && flaggedImagesProvider.isLoading)
        : (!_blurImagesFetched && flaggedImagesProvider.isLoading && !_isChangingTab);
  }

  @override
  Widget build(BuildContext context) {
    final imagesToDisplay = _getCurrentImages();
    final isLoading = _isCurrentTabLoading();

    return Scaffold(
      appBar: _buildAppBar(imagesToDisplay),
      body: Stack(
        children: [
          _buildImageGrid(imagesToDisplay, isLoading),
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(List<ImageModel> imagesToDisplay) {
    return AppBar(
      title: Text(
        _isSelectingForDownload
            ? "${_selectedImagesForDownload.length} selected"
            : widget.album.albumTitle,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      leading: _isSelectingForDownload
          ? IconButton(
        icon: const Icon(Icons.close, color: Colors.black),
        onPressed: _toggleSelectionMode,
      )
          : IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (!_isSelectingForDownload)
          IconButton(
            icon: const Icon(Icons.select_all, color: Colors.black),
            onPressed: imagesToDisplay.isEmpty ? null : _toggleSelectionMode,
          ),
        if (_isSelectingForDownload) _buildActionMenu(),
      ],
    );
  }

  Widget _buildActionMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.black),
      onSelected: (value) async {
        switch (value) {
          case 'download':
            await _downloadSelectedImages();
            break;
          case 'unflag':
            await _unflagSelectedImages();
            break;
          case 'delete':
            await _deleteSelectedImages();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'download',
          child: Row(
            children: [
              Icon(Icons.download),
              SizedBox(width: 8),
              Text('Download'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'unflag',
          child: Row(
            children: [
              Icon(Icons.flag_outlined),
              SizedBox(width: 8),
              Text('Unflag'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButtons() {
    return FlaggedToggleButtonGroup(
      isPhotosSelected: _isPhotosSelected,
      onToggle: (isPhotos) => _handleTabChange(
        isPhotos ? FlaggedImageTab.duplicate : FlaggedImageTab.blur,
      ),
    );
  }

  Widget _buildImageGrid(List<ImageModel> imagesToDisplay, bool isLoading) {
    final hasMore = _isPhotosSelected
        ? _hasMoreDuplicateImages
        : _hasMoreBlurImages;
    final isPaginating = _isPhotosSelected
        ? _isLoadingMoreDuplicate
        : _isLoadingMoreBlur;

    return RefreshIndicator(
      onRefresh: () async => _resetAndLoadInitialImages(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverToBoxAdapter(child: _buildToggleButtons()),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          if (imagesToDisplay.isEmpty && !isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPhotosSelected
                          ? Icons.copy_outlined
                          : Icons.blur_on,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isPhotosSelected
                          ? 'No duplicates found'
                          : 'No blurry images found',
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _resetAndLoadInitialImages,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload'),
                    ),
                  ],
                ),
              ),
            )else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0).copyWith(bottom: 60),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 5,
              crossAxisSpacing: 10,
              childCount: imagesToDisplay.length + (hasMore ? 1 : 0),
              itemBuilder: (ctx, idx) {
                // spinner at end
                if (idx == imagesToDisplay.length && hasMore) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: SizedBox(
                        width: 120,height: 120,
                        child: LottieWidget())),
                  );
                }
                final img = imagesToDisplay[idx];
                final selected = _selectedImagesForDownload.contains(img);
                return GestureDetector(
                  onTap: _isSelectingForDownload
                      ? () => _toggleSelection(img)
                      : () => _openFullPictureScreen(idx, imagesToDisplay),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CachedNetworkImage(
                          imageUrl: img.s3Url,
                          width: double.infinity,
                          height: idx.isEven ? 150 : 200,
                          fit: BoxFit.cover,
                          memCacheWidth:
                          (300 * MediaQuery.of(context).devicePixelRatio).round(),
                          memCacheHeight: ((idx.isEven ? 150 : 200)
                              * MediaQuery.of(context).devicePixelRatio)
                              .round(),
                          placeholder: (c, u) => Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor: Colors.grey.shade100,
                            child: Container(
                              width: double.infinity,
                              height: idx.isEven ? 150 : 200,
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (c, u, e) => const Icon(Icons.error),
                        ),
                      ),

                      ((_isPhotosSelected && img.duplicate) ||
                          (!_isPhotosSelected && img.status == 'blur'))
                          ? Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (_isPhotosSelected
                                ? Colors.red.withOpacity(0.7)
                                : Colors.blue.withOpacity(0.7)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isPhotosSelected ? 'Duplicate' : 'Blur',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ): const SizedBox.shrink(),

                      if (_isSelectingForDownload)
                        Positioned(
                          top: 5,
                          right: 10,
                          child: Icon(
                            selected ? Icons.check_circle : Icons.circle_outlined,
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
    );
  }

  Widget _buildProcessingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
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
                  height: 150,
                  width: 200,
                  child: Lottie.asset(
                    _isDeleting
                        ? 'assets/animations/delete.json'
                        : 'assets/animations/unflag.json',
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _isDeleting?'Deleting...':'Unflagging...',
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
        ),
      ),
    );
  }


}

