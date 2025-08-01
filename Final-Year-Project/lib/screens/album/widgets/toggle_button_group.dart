import 'package:flutter/material.dart';
import 'toggle_button.dart';

class ToggleButtonGroup extends StatelessWidget {
  final bool isPhotosSelected;
  final ValueChanged<bool> onToggle;

  const ToggleButtonGroup({
    Key? key,
    required this.isPhotosSelected,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 326,
          height: 45,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 241, 240, 240),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ToggleButton(
                  label: 'Photos',
                  isSelected: isPhotosSelected,
                  onTap: () => onToggle(true),
                ),
                const SizedBox(width: 6),
                ToggleButton(
                  label: 'My Photos',
                  isSelected: !isPhotosSelected,
                  onTap: () => onToggle(false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
