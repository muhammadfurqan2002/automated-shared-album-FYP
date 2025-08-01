import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const ActionButton({
    Key? key,
    required this.label,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onTap == null;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isDisabled ? Colors.grey.shade200 : Colors.white,
          border: Border.all(
            color: isDisabled ? Colors.grey.shade300 : const Color.fromARGB(255, 216, 216, 216),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: isDisabled ? Colors.grey.shade500 : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
