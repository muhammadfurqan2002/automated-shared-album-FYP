import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/AuthProvider.dart';

class ProfileStorage extends StatelessWidget {
  const ProfileStorage({super.key});

  @override
  Widget build(BuildContext context) {
    final usage = Provider.of<AuthProvider>(context).storageUsage;
    const totalStorageMB = 5 * 1024; // 5GB in MB

    final usedMB = usage?.memoryUsedMB ?? 0.0;
    final freeMB = (totalStorageMB - usedMB).clamp(0, totalStorageMB);
    final usedGB = usedMB / 1024;
    final freeGB = freeMB / 1024;
    final percentUsed = (usedMB / totalStorageMB).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAEA),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: _buildStorageInfo(
                  usedGB: usedGB, freeGB: freeGB, totalGB: totalStorageMB / 1024)),
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 20, bottom: 20),
            child: _buildStorageCircle(percentUsed),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfo(
      {required double usedGB,
        required double freeGB,
        required double totalGB}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Storage',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${totalGB.toStringAsFixed(1)} GB',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 20),
        const Divider(thickness: 1, color: Colors.black, height: 1),
        const SizedBox(height: 30),
        Row(
          children: [
            _buildStorageIndicator(true, 'USED', '${usedGB.toStringAsFixed(2)} GB'),
            const SizedBox(width: 15),
            _buildStorageIndicator(false, 'FREE', '${freeGB.toStringAsFixed(2)} GB'),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageIndicator(bool isUsed, String label, String value) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isUsed ? Colors.black : Colors.white,
            shape: BoxShape.circle,
            border: isUsed ? null : Border.all(color: Colors.black),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageCircle(double percentUsed) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        SizedBox(
          width: 110,
          height: 110,
          child: CircularProgressIndicator(
            value: percentUsed,
            strokeWidth: 10,
            backgroundColor: const Color(0xFFD6D6D6),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
        Text('${(percentUsed * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
      ],
    );
  }
}
