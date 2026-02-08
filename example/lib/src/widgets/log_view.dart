import 'package:flutter/material.dart';

import '../log_entry.dart';

/// Scrollable log view with timestamps
class LogView extends StatelessWidget {
  final List<LogEntry> logs;
  final ScrollController controller;

  const LogView({
    super.key,
    required this.logs,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.all(12),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log.formattedTime} ',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                Expanded(
                  child: Text(
                    log.message,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: log.level.color,
                      fontWeight: log.level == LogLevel.header
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
