import 'package:flutter/material.dart';
import 'action_button.dart';

class ActionButtonsRow extends StatelessWidget {
  const ActionButtonsRow({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ActionButton(
          label: 'Download',
          onTap: () {
          },
        ),
        const SizedBox(width: 10),
        ActionButton(
          label: 'Share',
          onTap: () {
          },
        ),
      ],
    );
  }
}
