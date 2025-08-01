import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VerificationInputField extends StatelessWidget {
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  final TextEditingController controller;

  const VerificationInputField({
    Key? key,
    required this.keyboardType,
    required this.onChanged,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double fieldWidth = MediaQuery.of(context).size.width * 0.12;
    return SizedBox(
      width: fieldWidth,
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        maxLength: 1,
        textAlign: TextAlign.center,
        decoration: _buildInputDecoration(),
        style: const TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.bold,
        ),
        keyboardType: keyboardType,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }

  InputDecoration _buildInputDecoration() {
    return InputDecoration(
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 2.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Colors.grey, width: 1.0),
      ),
    );
  }
}
