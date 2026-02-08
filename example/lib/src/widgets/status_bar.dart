import 'package:flutter/material.dart';

/// Status bar showing encryption state and statistics
class StatusBar extends StatelessWidget {
  final bool isInitialized;
  final String? currentKey;
  final int rotationCount;
  final int successCount;
  final int failureCount;

  const StatusBar({
    super.key,
    required this.isInitialized,
    required this.currentKey,
    required this.rotationCount,
    required this.successCount,
    required this.failureCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isInitialized ? Colors.green.shade900 : Colors.grey.shade800,
      child: Row(
        children: [
          Icon(
            isInitialized ? Icons.lock : Icons.lock_open,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isInitialized ? 'Encryption Active' : 'Not Initialized',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (currentKey != null)
                  Text(
                    'Key: ${currentKey!.substring(0, 8)}...',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
              ],
            ),
          ),
          _StatChip(icon: Icons.sync, value: '$rotationCount', color: Colors.blue),
          const SizedBox(width: 8),
          _StatChip(icon: Icons.check, value: '$successCount', color: Colors.green),
          const SizedBox(width: 8),
          _StatChip(icon: Icons.error_outline, value: '$failureCount', color: Colors.red),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
