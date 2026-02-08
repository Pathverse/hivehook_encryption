import 'package:flutter/material.dart';

/// Log levels for the demo output
enum LogLevel { info, data, success, warning, error, header }

extension LogLevelColor on LogLevel {
  Color get color => switch (this) {
        LogLevel.info => Colors.white70,
        LogLevel.data => Colors.cyan,
        LogLevel.success => Colors.greenAccent,
        LogLevel.warning => Colors.orange,
        LogLevel.error => Colors.redAccent,
        LogLevel.header => Colors.white,
      };
}

/// A single log entry with timestamp
class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime time;

  LogEntry(this.message, this.level) : time = DateTime.now();

  String get formattedTime =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';
}
