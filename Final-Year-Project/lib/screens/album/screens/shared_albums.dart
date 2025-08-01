import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../providers/album_provider.dart';
import '../widgets/shared_album_card.dart';

class SharedAlbumsScreen extends StatefulWidget {
  const SharedAlbumsScreen({Key? key}) : super(key: key);

  @override
  State<SharedAlbumsScreen> createState() => _SharedAlbumsScreenState();
}

class _SharedAlbumsScreenState extends State<SharedAlbumsScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _limit = 10;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAlbums();
    });
    _scrollController.addListener(_scrollListener);
  }
  Future<void> _fetchAlbums({int page = 1, bool append = false}) async {
    await Provider.of<AlbumProvider>(context, listen: false)
        .fetchSharedAlbums(page: page, limit: _limit, append: append);
  }

  void _scrollListener() {
    final provider = Provider.of<AlbumProvider>(context, listen: false);

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        provider.sharedAlbumHasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await _fetchAlbums(page: _currentPage, append: true);
    setState(() {
      _isLoadingMore = false;
    });
  }

  Future<void> _refreshAlbums() async {
    _currentPage = 1;
    await _fetchAlbums(page: 1, append: false);

  }

  Widget buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Shared Albums',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAlbums,
        child: Consumer<AlbumProvider>(
          builder: (context, albumProvider, child) {
            if (albumProvider.isLoading && albumProvider.sharedAlbums.isEmpty) {
              return buildShimmer();
            } else if (albumProvider.error != null) {
              return Center(child: Text('${albumProvider.error}'));
            } else if (albumProvider.sharedAlbums.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No shared albums found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: albumProvider.sharedAlbums.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < albumProvider.sharedAlbums.length) {
                      return SharedAlbumCard(album: albumProvider.sharedAlbums[index]);
                    } else {
                      // Show loading indicator at bottom when loading more
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                  },
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
