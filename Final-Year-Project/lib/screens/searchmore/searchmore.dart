import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fyp/models/album_model.dart';
import 'package:fyp/providers/album_provider.dart';
import 'package:fyp/screens/album/screens/shared_albums.dart';
import '../../providers/session_manager.dart';
import '../../utils/navigation_helper.dart';
import 'components/album_grid.dart';
import 'components/search_filter.dart';

class SearchMoreScreen extends StatefulWidget {
  const SearchMoreScreen({super.key});

  @override
  State<SearchMoreScreen> createState() => _SearchMoreScreenState();
}

class _SearchMoreScreenState extends State<SearchMoreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Album> allAlbums = [];
  List<Album> filteredAlbums = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  int currentPage = 1;
  int totalPages = 3;
  bool _isUpdating = false;
  AlbumProvider? _albumProvider;

  String _selectedSortOption = "Newest";

  @override
  void initState() {
    super.initState();
    SessionManager.checkJwtAndLogoutIfExpired(context);
    _searchController.addListener(_filterAlbums);
    _scrollController.addListener(_scrollListener);

    // Defer the fetchAlbums call until after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAlbums();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_albumProvider == null) {
      _albumProvider = Provider.of<AlbumProvider>(context, listen: false);
      _albumProvider!.addListener(_onAlbumProviderChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAlbums();
      });
    }
  }

  void _onAlbumProviderChanged() {
    if (mounted && !isLoading && !isLoadingMore && !_isUpdating) {
      if (_albumProvider != null) {
        setState(() {
          allAlbums = _albumProvider!.albums;
          _filterAlbums();
        });
      }
    }
  }

  Future<void> _loadAlbums() async {
    if (!mounted || _isUpdating) return;
    _isUpdating = true;
    setState(() {
      isLoading = allAlbums.isEmpty;
    });

    try {
      if (_albumProvider != null) {
        await _albumProvider!.fetchAlbums(page: currentPage);
        if (mounted) {
          setState(() {
            allAlbums = _albumProvider!.albums;
            filteredAlbums = List.from(allAlbums);
            _sortAlbums();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } finally {
      _isUpdating = false;
    }
  }

  void _filterAlbums() {
    if (!mounted) return;
    final query = _searchController.text;
    setState(() {
      filteredAlbums = allAlbums
          .where((album) =>
          album.albumTitle.toLowerCase().contains(query.toLowerCase()))
          .toList();
      _sortAlbums();
    });
  }

  void _sortAlbums() {
    if (_selectedSortOption == "Newest") {
      filteredAlbums.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      filteredAlbums.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        currentPage < totalPages) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      isLoadingMore = true;
      currentPage++;
    });
    if (_albumProvider != null) {
      await _albumProvider!.fetchAlbums(page: currentPage, append: true); // fetch next page
      if (mounted) {
        setState(() {
          allAlbums = _albumProvider!.albums;
          _filterAlbums();
          isLoadingMore = false;
        });
      }
    }
  }


  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    if (_albumProvider != null) {
      _albumProvider!.removeListener(_onAlbumProviderChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search',style: TextStyle(fontWeight: FontWeight.bold),),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              showGeneralDialog(
                context: context,
                barrierDismissible: true,
                barrierLabel: 'Menu',
                barrierColor: Colors.transparent,
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (context, anim1, anim2) {
                  return Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.only(
                          top: kToolbarHeight + 20, right: 10),
                      width: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: const Text('Shared Albums'),
                              onTap: () {
                                Navigator.pop(context);
                                navigateTo(context, const SharedAlbumsScreen());
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                transitionBuilder: (context, animation, secondaryAnimation, child) {
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(animation);
                  return SlideTransition(
                    position: offsetAnimation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          SearchFilterSection(
            searchController: _searchController,
            selectedSortOption: _selectedSortOption,
            onSortOptionChanged: (newOption) {
              setState(() {
                _selectedSortOption = newOption;
                _sortAlbums();
              });
            },
            albumCount: filteredAlbums.length,
          ),
          Expanded(
            child: AlbumsGridSection(
              filteredAlbums: filteredAlbums,
              scrollController: _scrollController,
              isLoadingMore: isLoadingMore,
            ),
          ),
        ],
      ),
    );
  }
}
