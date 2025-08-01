import 'dart:ui';

import 'package:flutter/material.dart';

class RoleButton extends StatelessWidget {
  final String currentRole;
  final ValueChanged<String> onRoleSelected;
  final bool isDisabled; // ✅ Add this

  const RoleButton({
    Key? key,
    required this.currentRole,
    required this.onRoleSelected,
    this.isDisabled = false, // ✅ Set default
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : () => _showRoleSelectionSheet(context), // ✅ Disable tap
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDisabled
                ? Colors.grey.shade200 // ✅ Dim color when disabled
                : (currentRole == 'Admin' ? Colors.blue : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            border: isDisabled ? Border.all(color: Colors.grey.shade400) : null,
          ),
          child: Text(
            currentRole,
            style: TextStyle(
              fontSize: 14,
              color: isDisabled
                  ? Colors.grey
                  : (currentRole == 'Admin' ? Colors.white : Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  void _showRoleSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        String selectedRole = currentRole;

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Change Role',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  _buildRadioTile(context, 'Admin', selectedRole, (value) {
                    Navigator.pop(context);
                    onRoleSelected(value);
                  }),
                  _buildRadioTile(context, 'Viewer', selectedRole, (value) {
                    Navigator.pop(context);
                    onRoleSelected(value);
                  }),
                  _buildRadioTile(context, 'Remove', selectedRole, (value) {
                    Navigator.pop(context);
                    onRoleSelected(value);
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRadioTile(
      BuildContext context, String role, String selectedRole, ValueChanged<String> onChanged) {
    return RadioListTile<String>(
      title: Text(
        role,
        style: TextStyle(
          color: role == 'Remove' ? Colors.red : Colors.black,
        ),
      ),
      value: role,
      groupValue: selectedRole,
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
      activeColor: Colors.blue,
    );
  }
}
