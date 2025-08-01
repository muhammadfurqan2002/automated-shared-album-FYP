import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fyp/models/album_model.dart';
import 'package:fyp/providers/album_provider.dart';
import 'package:fyp/screens/home/widgets/albums_list.dart';
import 'package:fyp/screens/home/widgets/home_appbar.dart';
import 'package:fyp/screens/home/widgets/home_header.dart';
import 'package:fyp/screens/home/widgets/home_recenlty_added_header.dart';
import 'package:fyp/screens/home/widgets/recenlty_added_albums.dart';

import '../../providers/session_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentPage = 1;
  bool _isLoadingMore = false;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SessionManager.checkJwtAndLogoutIfExpired(context);
      _fetchAlbums();
      _getFcmToken();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreAlbums();
      }
    });
  }

  Future<void> _fetchAlbums({int page = 1, bool append = false}) async {
    await Provider.of<AlbumProvider>(context, listen: false)
        .fetchAlbums(page: page, limit: 10, append: append);
  }

  Future<void> _loadMoreAlbums() async {
    final albumProvider = Provider.of<AlbumProvider>(context, listen: false);
    if (_isLoadingMore || !albumProvider.albumHasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await albumProvider.fetchAlbums(page: _currentPage, limit: _limit, append: true);

    setState(() {
      _isLoadingMore = false;
    });
  }



  Future<void> _getFcmToken() async {
    final fcmToken=await FirebaseMessaging.instance.getToken();
    print("Token Of Fcm Device");
    print(fcmToken);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: Consumer<AlbumProvider>(
        builder: (context, albumProvider, child) {
          final List<Album> albums = albumProvider.albums;
          final List<Album> recentlyAddedAlbums = albums.take(4).toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                const AlbumsHeader(),
                const SizedBox(height: 15),
                AlbumsList(
                  albums: albums,
                  isLoading: albumProvider.isLoading,
                  controller: _scrollController,
                  isLoadingMore: _isLoadingMore,
                  hasMore: albumProvider.albumHasMore,
                ),
                const SizedBox(height: 20),
                RecentlyAddedList(
                  recentlyAddedAlbums: recentlyAddedAlbums,
                  isLoading: albumProvider.isLoading,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
