// highlight_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fyp/screens/highlights/reel_screen.dart';
import 'package:fyp/screens/highlights/widgets/highlight_reel_list.dart';
import 'package:fyp/utils/ip.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

import '../../models/highlight.dart';
import '../../providers/session_manager.dart';

class HighlightScreen extends StatefulWidget {
  const HighlightScreen({Key? key}) : super(key: key);

  @override
  State<HighlightScreen> createState() => _HighlightScreenState();
}

class _HighlightScreenState extends State<HighlightScreen>
    with AutomaticKeepAliveClientMixin<HighlightScreen> {
  @override
  bool get wantKeepAlive => true;

  bool isLoading = true;
  List<ReelModel> reelsData = [];
  int currentPage = 1;
  int totalPages = 1;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SessionManager.checkJwtAndLogoutIfExpired(context);
    fetchReelsData(page: currentPage);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100 &&
        !isLoading &&
        currentPage < totalPages) {
      fetchReelsData(page: currentPage + 1);
    }
  }

  Future<void> fetchReelsData({required int page}) async {
    setState(() => isLoading = true);
    final token = await _storage.read(key: 'jwt');
    final url = '${IP.ip}/highlight?page=$page';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        final pagination = body['pagination'] as Map<String, dynamic>? ?? {};

        setState(() {
          currentPage = pagination['currentPage'] as int? ?? page;
          totalPages = pagination['totalPages'] as int? ?? totalPages;
          final newReels = data.map((e) => ReelModel.fromJson(e)).toList();
          if (page == 1) {
            reelsData = newReels;
          } else {
            reelsData.addAll(newReels);
          }
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        debugPrint('Failed to load reels data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error fetching reels data: $e');
    }
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(15),
      itemCount: 3,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: SingleReelWidget.imageHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Highlights',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        body: reelsData.isEmpty
            ? (isLoading
            ? _buildShimmerList()
            : const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_stable_outlined,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 12),
              Text(
                'No highlights available',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ))
            : HighlightReelList(
          reelsData: reelsData,
          scrollController: _scrollController,
          isLoading: isLoading,
        ),
      ),
    );
  }
}
