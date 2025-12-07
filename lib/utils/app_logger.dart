import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void log(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    // Only log in debug mode to avoid performance hit in production
    // unless it's an error which might be useful to capture if we had a remote logging service
    if (kDebugMode) {
      if (error != null) {
        _logger.e(message, error: error, stackTrace: stackTrace);
      } else {
        _logger.i(message);
      }
    }
  }

  static void info(dynamic message) {
    if (kDebugMode) {
      _logger.i(message);
    }
  }

  static void warning(dynamic message) {
    if (kDebugMode) {
      _logger.w(message);
    }
  }

  static void error(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }
}
