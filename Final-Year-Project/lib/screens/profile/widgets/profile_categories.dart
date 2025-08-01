import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/AuthProvider.dart';

class ProfileCategories extends StatelessWidget {
  const ProfileCategories({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          CategoryList(),
        ],
      ),
    );
  }
}

class CategoryList extends StatelessWidget {
  const CategoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final usage = Provider.of<AuthProvider>(context).storageUsage;
    final imagesCount = usage?.totalImages ?? 0;
    final albumsCount = usage?.totalAlbums ?? 0;
    return Column(
      children: [
        CategoryItem(name: "Photos",count: imagesCount,asset: "assets/icons/picture.png",),
        CategoryItem(name: "Albums",count: albumsCount,asset: "assets/icons/book.png",),
      ],
    );
  }
}

class CategoryItem extends StatelessWidget {
  final String name;
  final int count;
  final String asset;
  const CategoryItem({super.key,required this.name,required this.count,required this.asset});

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              // color: const Color.fromRGBO(217, 217, 217, 56),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  asset,
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
           Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count files',
                style:const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(fontSize: 18, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
