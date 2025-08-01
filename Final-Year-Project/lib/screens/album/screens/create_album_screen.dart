import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fyp/utils/flashbar_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mime/mime.dart';

import '../../../providers/album_provider.dart';
import '../../home/home_navigation.dart';

// Import your SnackbarHelper
import 'package:fyp/utils/snackbar_helper.dart'; // adjust the import path as needed

class CreateAlbumScreen extends StatefulWidget {
  const CreateAlbumScreen({super.key});

  @override
  _CreateAlbumScreenState createState() => _CreateAlbumScreenState();
}

class _CreateAlbumScreenState extends State<CreateAlbumScreen> {
  final TextEditingController _titleController = TextEditingController();
  XFile? _coverImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _coverImage = pickedFile;
      });
    }
  }

  void _createAlbum() async {
    if (_titleController.text.isEmpty || _coverImage == null) {
      FlushbarHelper.show(context, message:"Please provide an album title and cover image.",backgroundColor: Colors.red,icon:Icons.warning_amber_sharp);
      return;
    }
    if(_titleController.text.length>15){
      FlushbarHelper.show(context, message:"Album title not be greater than 15 characters!",backgroundColor: Colors.red,icon:Icons.warning_amber_sharp);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String? mimeType = lookupMimeType(_coverImage!.path);
      final String fileType = mimeType ?? 'image/jpeg';

      await Provider.of<AlbumProvider>(context, listen: false).createAlbum(
        _titleController.text,
        File(_coverImage!.path),
        fileType,
      );

      if (!mounted) return;
      SnackbarHelper.showSuccessSnackbar(context, "Album created successfully!");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const NavigationHome()),
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showErrorSnackbar(
        context,
        "Error creating album,try again!",
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create New Album",style: TextStyle(fontWeight: FontWeight.bold),),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                      gradient: const LinearGradient(
                        colors: [Colors.purpleAccent, Colors.blueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      image: _coverImage != null
                          ? DecorationImage(
                        image: FileImage(File(_coverImage!.path)),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    child: _coverImage == null
                        ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 60, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            "Tap to choose cover image",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: "Album Title",
                    border: const OutlineInputBorder(),
                    prefixIcon:
                    const Icon(Icons.title, color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 20),
                if (_coverImage != null) ...[
                  const Text(
                    "Preview",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              File(_coverImage!.path),
                              height: 150,
                              width: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _titleController.text,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                ElevatedButton(
                  onPressed: _isLoading ? null : _createAlbum,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    backgroundColor: Colors.blueAccent,
                    shadowColor: Colors.black26,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "Create Album",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
