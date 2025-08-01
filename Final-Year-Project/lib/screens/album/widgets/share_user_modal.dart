import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../providers/sharedAlbum_provider.dart';

class ShareModal extends StatefulWidget {
  final List<dynamic> suggestions;
  final int albumId, adminId;

  const ShareModal({
    super.key,
    required this.suggestions,
    required this.albumId,
    required this.adminId,
  });

  @override
  _ShareModalState createState() => _ShareModalState();
}

class _ShareModalState extends State<ShareModal> {
  late List<Map<String, dynamic>> usersList;

  @override
  void initState() {
    super.initState();
    usersList = widget.suggestions.map((s) => {
      "userId": s['userId'],
      "profileImage": s['photoUrl'],
      "isSelected": true,
    }).toList();
  }

  void _toggleSelection(int idx) {
    setState(() => usersList[idx]['isSelected'] = !usersList[idx]['isSelected']);
  }

  Future<void> _shareSelectedUsers() async {
    final selected = usersList
        .where((u) => u['isSelected'])
        .map<int>((u) => u['userId'] as int)
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please select at least one user.")));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await context.read<SharedAlbumProvider>().createSharedAlbum(
        albumId: widget.albumId,
        adminId: widget.adminId,
        participantDetails: selected,
      );
      Navigator.pop(context); // close loader

      if (result['error'] == null) {
        await context.read<SharedAlbumProvider>().fetchMembersWithDetails(widget.albumId);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Album shared successfully!")));
        Navigator.pop(context); // close modal
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${result['message'] ?? result['error']}")),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Suggested Users",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // Users list
              usersList.isEmpty
                  ? Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("No suggestions found",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              )
                  : SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: usersList.length,
                  itemBuilder: (ctx, i) {
                    final user = usersList[i];
                    return ListTile(
                      leading: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user['profileImage'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (c, url) => Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor: Colors.grey.shade100,
                            child: Container(
                              width: 60,
                              height: 60,
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (c, url, err) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.person, size: 30),
                          ),
                        ),
                      ),
                      trailing: Checkbox(
                        value: user['isSelected'],
                        onChanged: (_) => _toggleSelection(i),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (usersList.isNotEmpty)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                      onPressed: _shareSelectedUsers,
                      child: const Text("Share", style: TextStyle(color: Colors.white)),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
