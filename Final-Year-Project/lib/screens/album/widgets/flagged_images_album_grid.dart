import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';

import '../../../models/image_model.dart';

class FlaggedAlbumGrid extends StatelessWidget {
  final List<ImageModel> images;
  final bool isSelecting;
  final List<ImageModel> selectedImages;
  final Function(ImageModel)? onSelect;
  final bool isLoading;
  final bool tab;
  final Function(int index) onImageTap;

  const FlaggedAlbumGrid({
    Key? key,
    required this.images,
    required this.tab,
    this.isSelecting = false,
    this.selectedImages = const [],
    this.onSelect,
    this.isLoading = false,
    required this.onImageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return MasonryGridView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(10),
        mainAxisSpacing: 5.0,
        crossAxisSpacing: 10.0,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
        const SliverSimpleGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              margin: const EdgeInsets.only(bottom: 5),
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
            ),
          );
        },
      );
    }

    if (images.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30.0),
          child: Text(
            "No images available in this album yet.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return MasonryGridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(10),
      mainAxisSpacing: 5.0,
      crossAxisSpacing: 10.0,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
      const SliverSimpleGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final ImageModel image = images[index];
        final bool isSelected = selectedImages.contains(image);

        return GestureDetector(
          onTap: isSelecting && onSelect != null
              ? () => onSelect!(image)
              : () {
            onImageTap(index);
          },
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: image.s3Url,
                  width: double.infinity,
                  height: index.isEven ? 150 : 200,
                  fit: BoxFit.cover,
                  // Show a Shimmer placeholder while loading
                  placeholder: (context, url) =>
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          width: double.infinity,
                          height: index.isEven ? 150 : 200,
                          color: Colors.white,
                        ),
                      ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
              // Selection indicator
              if (isSelecting)
                Positioned(
                  top: 5,
                  right: 10,
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: Colors.blue,
                  ),
                ),
              if(image.duplicate || image.status == 'blur')
                Positioned(
                  top: 8,
                  left:5,
                  child: Container(
                    decoration: BoxDecoration(
                        color: image.duplicate && tab==true
                            ? Colors.red.withOpacity(0.5)
                            : Colors.blue.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20)
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 1, horizontal: 8),
                      child: Text(image.duplicate && tab==true ? 'Duplicate' : 'Blur',
                        style:const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),),
                    ),
                  ),
                ),

            ],
          ),
        );
      },
    );
  }
}