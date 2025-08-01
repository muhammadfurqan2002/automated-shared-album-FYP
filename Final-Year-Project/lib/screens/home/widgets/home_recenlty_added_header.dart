import 'package:flutter/material.dart';

// Header widget with functional icons
class RecentlyAddedHeader extends StatelessWidget {
  final bool isExpanded;
  final int crossAxisCount;
  final VoidCallback onToggleVisibility;
  final VoidCallback onToggleGridLayout;

  const RecentlyAddedHeader({
    Key? key,
    required this.isExpanded,
    required this.crossAxisCount,
    required this.onToggleVisibility,
    required this.onToggleGridLayout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onToggleVisibility,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Recently Added',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_sharp
                      : Icons.keyboard_arrow_down_sharp,
                  color: Colors.black87,
                  size: 25,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onToggleGridLayout,
            child: Icon(
              crossAxisCount == 1
                  ? Icons.view_list
                  : crossAxisCount == 2
                  ? Icons.apps
                  : Icons.grid_view,
              color: Colors.blue,
              size: 25,
            ),
          ),
        ],
      ),
    );
  }
}
