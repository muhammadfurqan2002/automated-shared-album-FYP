import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fyp/services/api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:fyp/utils/snackbar_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mime/mime.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../models/album_model.dart';
import '../../../providers/album_provider.dart';
import '../../../providers/session_manager.dart';
import '../../../providers/sharedAlbum_provider.dart';
import '../../../services/album_notification_service.dart';
import '../../../utils/decode_json_token.dart';
import '../../../utils/flashbar_helper.dart';
import '../widgets/album_participant_cards.dart';
import 'flagged_images.dart';

class AlbumSetting extends StatefulWidget {
  final Album album;
  final List<Map<String, dynamic>> participants;


  const AlbumSetting({
    Key? key,
    required this.album,
    required this.participants,
  }) : super(key: key);

  @override
  _AlbumSettingState createState() => _AlbumSettingState();
}

class _AlbumSettingState extends State<AlbumSetting> {
  // Constants
  String? _currentUserId;
  static const double _qrCodeSize = 300.0;
  static const double _avatarRadius = 55.0;
  static const double _editIconSize = 35.0;

  // Services and Storage
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();

  // State variables
  File? _selectedCoverImage;
  late Album _currentAlbum;
  late final StreamSubscription _streamSubscription;
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();

    SessionManager.checkJwtAndLogoutIfExpired(context);

    _initializeAlbum();
    _setupNotificationListener();

    DecodeJWTToken()
        .getClaim('id')
        .then((id) {
      if (mounted) setState(() => _currentUserId = id?.toString());
    });
  }

  @override
  void dispose() {
    _streamSubscription.cancel();
    super.dispose();
  }


  void _initializeAlbum() {
    _currentAlbum = widget.album;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final sharedAlbumProvider = Provider.of<SharedAlbumProvider>(context, listen: false);
      sharedAlbumProvider
          .fetchMembersWithDetails(_currentAlbum.id)
          .then((_) => sharedAlbumProvider.updateCurrentUserRole());
    });
  }

  void _setupNotificationListener() {
    final albumNotificationService = AlbumNotificationService();
    _streamSubscription = albumNotificationService.onRoleUpdated.listen((albumId) {
      if (albumId == _currentAlbum.id && mounted) {
        final sharedAlbumProvider = Provider.of<SharedAlbumProvider>(context, listen: false);
        sharedAlbumProvider
            .fetchMembersWithDetails(albumId)
            .then((_) => sharedAlbumProvider.updateCurrentUserRole());
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      centerTitle: true,
      title: const Text(
        'Album Settings',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      actions: [_buildPopupMenu()],
    );
  }

  Widget _buildBody() {
    return Consumer<SharedAlbumProvider>(
      builder: (context, sharedAlbumProvider, _) {
        if (sharedAlbumProvider.isLoading && sharedAlbumProvider.participants.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (sharedAlbumProvider.error != null && sharedAlbumProvider.participants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sharedAlbumProvider.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _initializeAlbum(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final participants = sharedAlbumProvider.participants;
        if (participants.isEmpty) {
          return const Center(child: Text("No participants found."));
        }

        return _buildParticipantsList(participants);
      },
    );
  }

  List<Map<String, dynamic>> _sortAdminsFirst(
      List<Map<String, dynamic>> participants,
      int albumOwnerId,
      ) {
    // 1. Extract owner, admins, and others
    final ownerList = participants
        .where((p) => p['user_id'] == albumOwnerId)
        .toList();

    final adminList = participants
        .where((p) =>
    p['user_id'] != albumOwnerId &&
        (p['access_role'] as String).toLowerCase() == 'admin')
        .toList();

    final memberList = participants
        .where((p) =>
    (p['access_role'] as String).toLowerCase() != 'admin')
        .toList();

    // 2. Sort only the adminList by username (safe against null)
    adminList.sort((a, b) {
      final na = ((a['username'] as String?) ?? '').toLowerCase();
      final nb = ((b['username'] as String?) ?? '').toLowerCase();
      return na.compareTo(nb);
    });

    // 3. Concatenate: owner, sorted admins, then the rest
    return [...ownerList, ...adminList, ...memberList];
  }


  // Widget _buildParticipantsList(List<Map<String, dynamic>> participants) {
  //   final currentUserRole    = context.watch<SharedAlbumProvider>().currentUserRole;
  //   final isCurrentUserOwner = _currentUserId == _currentAlbum.userId.toString();
  //
  //   return ListView.builder(
  //     key: const PageStorageKey('participants_list'),
  //     padding: const EdgeInsets.all(16),
  //     itemCount: participants.length,
  //     itemBuilder: (context, index) {
  //       final participant = participants[index];
  //       final int participantId = participant['user_id'];
  //       final bool isOwner      = participantId == _currentAlbum.userId;
  //       final String role       = (participant['access_role'] as String).toLowerCase();
  //       final bool isAdmin      = role == 'admin';
  //
  //       // ← updated: disable if
  //       // 1) I'm not an admin at all
  //       // 2) the row is the owner themself
  //       // 3) it's another admin and I'm not the owner
  //       final bool isDisabled =
  //           currentUserRole != 'admin'
  //               || isOwner
  //               || (isAdmin && !isCurrentUserOwner);
  //
  //       return Padding(
  //         padding: const EdgeInsets.only(bottom: 8),
  //         child: ParticipantCard(
  //           key: ValueKey(participantId),
  //           participant: participant,
  //           isDisabled: isDisabled,
  //           onRoleChanged: (newRole) =>
  //               _handleRoleChange(participant, newRole, isDisabled),
  //         ),
  //       );
  //     },
  //   );
  // }


  Widget _buildParticipantsList(List<Map<String, dynamic>> participants) {
    // 1) Pre-sort participants
    final sortedParticipants =
    _sortAdminsFirst(participants, _currentAlbum.userId);

    // 2) Build the ListView with sorted data
    return ListView.builder(
      key: const PageStorageKey('participants_list'),
      padding: const EdgeInsets.all(16),
      itemCount: sortedParticipants.length,
      itemBuilder: (context, index) {
        final participant = sortedParticipants[index];
        final pid = participant['user_id'] as int;
        final role = (participant['access_role'] as String).toLowerCase();
        final isOwner = pid == _currentAlbum.userId;
        final isAdmin = role == 'admin';
        final currentUserRole =
            context.watch<SharedAlbumProvider>().currentUserRole;
        final isCurrentUserOwner =
            _currentUserId == _currentAlbum.userId.toString();

        // Reuse your existing disable logic:
        final bool isDisabled =
            currentUserRole != 'admin' ||
                isOwner ||
                (isAdmin && !isCurrentUserOwner);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ParticipantCard(
            key: ValueKey(pid),
            participant: participant,
            isDisabled: isDisabled,
            onRoleChanged: (newRole) =>
                _handleRoleChange(participant, newRole, isDisabled),
          ),
        );
      },
    );
  }
  Widget _buildPopupMenu() {
    final currentUserRole = context.watch<SharedAlbumProvider>().currentUserRole;

    return IconButton(
      icon: const Icon(Icons.more_horiz_sharp),
      onPressed: () => _showPopupMenu(currentUserRole),
    );
  }

  // ==========================================================================
  // POPUP MENU METHODS
  // ==========================================================================

  Future<void> _showPopupMenu(String? currentUserRole) async {
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => _buildPopupMenuContent(currentUserRole),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: anim1,
          alignment: Alignment.topRight,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );

    if (result != null) {
      await _handleMenuSelection(result, currentUserRole);
    }
  }

  Widget _buildPopupMenuContent(String? currentUserRole) {
    final isCurrentUserOwner = _currentUserId == _currentAlbum.userId.toString();

    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: const EdgeInsets.only(
          top: kToolbarHeight + 10,
          right: 10,
        ),
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuTile(
                title: 'Update Album',
                icon: Icons.edit,
                onTap: () => Navigator.pop(context, 'Update Album'),
              ),
              _buildMenuTile(
                title: 'Delete Album',
                icon: Icons.delete,
                textColor: Colors.red,
                onTap: () => Navigator.pop(context, 'Delete Album'),
              ),
              if (!isCurrentUserOwner)
                _buildMenuTile(
                  title: 'Leave Album',
                  icon: Icons.exit_to_app,
                  onTap: () => Navigator.pop(context, 'Leave Album'),
                ),
              _buildMenuTile(
                title: 'Flagged Images',
                icon: Icons.flag,
                isEnabled: isCurrentUserOwner||currentUserRole=='admin',
                onTap: () => Navigator.pop(context, 'Flagged Images'),
              ),
              _buildMenuTile(
                title: 'QR Code',
                icon: Icons.qr_code,
                isEnabled: currentUserRole == 'admin' || isCurrentUserOwner,
                onTap: () => Navigator.pop(context, 'QR Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? textColor,
    bool isEnabled = true,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isEnabled ? (textColor ?? Colors.black) : Colors.grey,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isEnabled ? (textColor ?? Colors.black) : Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: isEnabled ? onTap : null,
      enabled: isEnabled,
    );
  }

  // ==========================================================================
  // MENU ACTION HANDLERS
  // ==========================================================================

  Future<void> _handleMenuSelection(String selection, String? currentUserRole) async {
    if (!mounted) return;

    switch (selection) {
      case 'Update Album':
        await _handleUpdateAlbum(currentUserRole);
        break;
      case 'Delete Album':
        await _handleDeleteAlbum(currentUserRole);
        break;
      case 'Leave Album':
        await _handleLeaveAlbum();
        break;
      case 'Flagged Images':
        await _handleFlaggedImages();
        break;
      case 'QR Code':
        await _handleQRCode();
        break;
    }
  }

  Future<void> _handleUpdateAlbum(String? currentUserRole) async {
    final isCurrentUserOwner = _currentUserId == _currentAlbum.userId.toString();

    if (!isCurrentUserOwner || currentUserRole!="admin" ) {
      await _showErrorDialog(
        title: "Cannot Update Album",
        message: "You must be an admin and owner to update album details.",
      );
      return;
    }
    _showUpdateAlbumDialog();
  }

  Future<void> _handleDeleteAlbum(String? currentUserRole) async {
    final isCurrentUserOwner = _currentUserId == _currentAlbum.userId.toString();

    if (widget.participants.length > 1 || !isCurrentUserOwner) {
      await _showErrorDialog(
        title: 'Cannot Delete Album',
        message: 'You must remove all participants before deleting the album and must be an admin and owner.',
      );
      return;
    }

    await _showConfirmationDialog(
      title: 'Delete Album',
      message: 'Are you sure you want to delete this album? This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
      onConfirm: _performAlbumDeletion,
    );
  }

  Future<void> _handleLeaveAlbum() async {
    await _showConfirmationDialog(
      title: 'Leave Album',
      message: 'Are you sure you want to leave this album?',
      confirmText: 'Leave',
      isDestructive: true,
      onConfirm: _performLeaveAlbum,
    );
  }

  Future<void> _handleFlaggedImages() async {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlaggedImages(album: widget.album),
      ),
    );
  }

  Future<void> _handleQRCode() async {
    await _showQrCodeDialog();
  }

  // ==========================================================================
  // ROLE CHANGE HANDLER
  // ==========================================================================

  Future<void> _handleRoleChange(
      Map<String, dynamic> participant,
      String newRole,
      bool isDisabled,
      ) async {
    if (isDisabled) return;

    final oldRole = (participant['access_role'] as String).toLowerCase();
    final selectedRole = newRole.toLowerCase();

    if (selectedRole == oldRole) {
      SnackbarHelper.showInfoSnackbar(context, 'Role is already $newRole');
      return;
    }

    final sharedAlbumProvider = Provider.of<SharedAlbumProvider>(context, listen: false);
    final participantId = participant['user_id'];

    try {
      if (newRole == 'Remove') {
        await sharedAlbumProvider.removeUser(
          albumId: _currentAlbum.id,
          userId: participantId,
        );

        if (sharedAlbumProvider.error != null) {
          SnackbarHelper.showErrorSnackbar(context, sharedAlbumProvider.error!);
          return;
        }

        SnackbarHelper.showSuccessSnackbar(context, "User removed successfully");
      } else {
        final result = await sharedAlbumProvider.changeParticipantRole(
          albumId: _currentAlbum.id,
          userId: participantId,
          newRole: selectedRole,
        );

        if (sharedAlbumProvider.error != null) {
          SnackbarHelper.showErrorSnackbar(context, sharedAlbumProvider.error!);
          return;
        }

        SnackbarHelper.showSuccessSnackbar(context, "Role updated successfully");
      }
    } catch (e) {
      SnackbarHelper.showErrorSnackbar(context, "Error: ${e.toString()}");
    }
  }


  // ==========================================================================
  // ALBUM UPDATE METHODS
  // ==========================================================================

  void _showUpdateAlbumDialog() {
    final TextEditingController titleController = TextEditingController(text: _currentAlbum.albumTitle);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Update Album',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _buildCoverImageSelector(),
                  const SizedBox(height: 24),
                  _buildTitleTextField(titleController),
                  const SizedBox(height: 24),
                  _buildUpdateDialogActions(dialogContext, titleController),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverImageSelector() {
    return GestureDetector(
      onTap: _selectCoverImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: _avatarRadius,
            backgroundColor: Colors.grey[300],
            backgroundImage: _getCoverImageProvider(),
          ),
          Container(
            width: _editIconSize,
            height: _editIconSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54,
            ),
            child: const Icon(
              Icons.edit,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _getCoverImageProvider() {
    if (_selectedCoverImage != null) {
      return FileImage(_selectedCoverImage!);
    } else if (_currentAlbum.coverImageUrl.isNotEmpty) {
      return CachedNetworkImageProvider(_currentAlbum.coverImageUrl);
    } else {
      return const AssetImage('assets/placeholder.png');
    }
  }

  Widget _buildTitleTextField(TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Album Title',
        prefixIcon: const Icon(Icons.title),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildUpdateDialogActions(
      BuildContext dialogContext,
      TextEditingController titleController,
      ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _performAlbumUpdate(titleController.text);
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _selectCoverImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedCoverImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      SnackbarHelper.showErrorSnackbar(context, 'Failed to select image');
    }
  }

  Future<void> _performAlbumUpdate(String newTitle) async {
    if (!mounted) return;

    if (newTitle.trim().isEmpty) {
      FlushbarHelper.show(context, message:"Album title cannot be empty",backgroundColor: Colors.red,icon:Icons.warning_amber_sharp);
      return;
    }
    if(newTitle.length>15){
      FlushbarHelper.show(context, message:"Album title not be greater than 15 characters!",backgroundColor: Colors.red,icon:Icons.warning_amber_sharp);
      return;
    }


    _showLoadingDialog('Updating album...');

    try {
      final mimeType = lookupMimeType(_selectedCoverImage?.path ?? '');
      final albumProvider = Provider.of<AlbumProvider>(context, listen: false);

      final success = await albumProvider.updateAlbum(
        _currentAlbum.id,
        newTitle.trim(),
        coverFile: _selectedCoverImage,
        fileType: mimeType,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        setState(() {
          _currentAlbum = _currentAlbum.copyWith(
            albumTitle: newTitle.trim(),
            coverImageUrl: _selectedCoverImage != null
                ? _selectedCoverImage!.path
                : _currentAlbum.coverImageUrl,
          );
          _selectedCoverImage = null;
        });

        albumProvider.notifyListeners();
        await _showSuccessDialog('Album updated successfully');
      } else {
        setState(() {
          _selectedCoverImage = null;
        });
        await _showErrorDialog(
          title: 'Update Failed',
          message: albumProvider.error ?? 'Failed to update album',
        );
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop(); // Close loading dialog

      setState(() {
        _selectedCoverImage = null;
      });
      await _showErrorDialog(
        title: 'Update Failed',
        message: 'An error occurred: $e',
      );
    }
  }

  // ==========================================================================
  // ALBUM DELETION METHODS
  // ==========================================================================

  Future<void> _performAlbumDeletion() async {
    if (!mounted) return;

    _showLoadingDialog('Deleting album...');

    try {
      final albumProvider = Provider.of<AlbumProvider>(context, listen: false);
      await albumProvider.deleteAlbum(_currentAlbum.id);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (albumProvider.error == null) {
        await _showSuccessDialog('Album deleted successfully');
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        await _showErrorDialog(
          title: 'Deletion Failed',
          message: albumProvider.error!,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      await _showErrorDialog(
        title: 'Deletion Failed',
        message: 'An error occurred: $e',
      );
    }
  }

  // ==========================================================================
  // LEAVE ALBUM METHODS
  // ==========================================================================

  Future<void> _performLeaveAlbum() async {
    if (!mounted) return;

    _showLoadingDialog('Leaving album...');

    final sharedAlbumProvider = Provider.of<SharedAlbumProvider>(context, listen: false);
    try {
      final int userId = int.parse(_currentUserId!);
      await sharedAlbumProvider.removeUser(albumId: widget.album.id, userId: userId);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (sharedAlbumProvider.error != null) {
        await _showErrorDialog(
          title: 'Leave Failed',
          message: sharedAlbumProvider.error!,
        );
        return;
      }

      await _showSuccessDialog('Successfully left the album');
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      await _showErrorDialog(
        title: 'Leave Failed',
        message: 'An error occurred: $e',
      );
    }
  }



  // ==========================================================================
  // QR CODE METHODS
  // ==========================================================================

  Future<void> _showQrCodeDialog() async {
    try {
      final token = await _storage.read(key: 'jwt');
      if (token == null) {
        SnackbarHelper.showErrorSnackbar(context, 'Authentication required');
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiService().baseUrl}/shared/${widget.album.id}/qr-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final qrToken = responseData['token'];

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Center(child: Text('Scan to Join Album',style: TextStyle(fontSize: 20),)),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.75,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: QrImageView(
                        data: qrToken,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        qrToken,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _shareQrCode(qrToken);
                },
                child: const Text('Share'),
              ),
            ],
          ),
        );

      } else {
        SnackbarHelper.showErrorSnackbar(context, 'Failed to generate QR code');
      }
    } catch (e) {
      SnackbarHelper.showErrorSnackbar(context, 'Error: $e');
    }
  }

  Future<void> _shareQrCode(String token) async {
    try {
      final qrPainter = QrPainter(
        data: token,
        version: QrVersions.auto,
        gapless: false,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw white background
      final paintBackground = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, _qrCodeSize, _qrCodeSize), paintBackground);

      // Draw QR code
      qrPainter.paint(canvas, const Size(_qrCodeSize, _qrCodeSize));

      final picture = recorder.endRecording();
      final img = await picture.toImage(_qrCodeSize.toInt(), _qrCodeSize.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/album_qr_${_currentAlbum.id}.png');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Scan this QR code to join "${_currentAlbum.albumTitle}" album!',
      );
    } catch (e) {
      SnackbarHelper.showErrorSnackbar(context, 'Failed to share QR code: $e');
    }
  }

  // ==========================================================================
  // DIALOG HELPER METHODS
  // ==========================================================================

  void _showLoadingDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSuccessDialog(String message) async {
    if (!mounted) return;

    return showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    return showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title,style: TextStyle(fontSize: 17),),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) async {
    if (!mounted) return;

    return showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) {
                onConfirm();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : null,
              foregroundColor: isDestructive ? Colors.white : null,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}