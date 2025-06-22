import 'dart:async';

import 'package:sentry/sentry.dart';

/// Error severity levels
enum ErrorSeverity { low, medium, high, critical }

/// Error monitoring and tracking system with Sentry integration
class ErrorMonitor {
  static final ErrorMonitor _instance = ErrorMonitor._internal();
  factory ErrorMonitor() => _instance;
  ErrorMonitor._internal();

  /// Track errors by type and source
  final Map<String, List<ErrorRecord>> _errorHistory = {};

  /// Maximum number of errors to keep in history
  static const int maxErrorHistory = 100;

  /// Whether Sentry is available
  bool get isSentryAvailable => Sentry.isEnabled;

  /// Record an error with Sentry integration
  void recordError({
    required String source,
    required String message,
    required dynamic error,
    ErrorSeverity severity = ErrorSeverity.medium,
    Map<String, dynamic>? context,
    String? userId,
    String? transactionName,
  }) {
    final record = ErrorRecord(
      timestamp: DateTime.now(),
      source: source,
      message: message,
      error: error,
      severity: severity,
      context: context ?? {},
    );

    // Store in local history
    _storeErrorRecord(record);

    // Send to Sentry if available
    _sendToSentry(record, userId: userId, transactionName: transactionName);

    // Log locally
    _logError(record);
  }

  /// Store error record in local history
  void _storeErrorRecord(ErrorRecord record) {
    if (!_errorHistory.containsKey(record.source)) {
      _errorHistory[record.source] = [];
    }

    _errorHistory[record.source]!.add(record);

    // Keep only the latest errors
    if (_errorHistory[record.source]!.length > maxErrorHistory) {
      _errorHistory[record.source]!.removeAt(0);
    }
  }

  /// Send error to Sentry
  void _sendToSentry(ErrorRecord record,
      {String? userId, String? transactionName}) {
    if (!isSentryAvailable) {
      print('Sentry: Not available, skipping Sentry reporting');
      return;
    }

    try {
      // Create Sentry event
      final event = SentryEvent(
        message: SentryMessage(record.message),
        level: _mapSeverityToSentryLevel(record.severity),
        tags: {
          'source': record.source,
          'severity': record.severity.name,
        },
        timestamp: record.timestamp,
        // ignore: deprecated_member_use
        extra: {
          'context': record.context,
        },
        user: userId != null ? SentryUser(id: userId) : null,
      );

      // Add breadcrumb for better context
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Error in ${record.source}',
          category: 'error',
          level: _mapSeverityToSentryLevel(record.severity),
          data: {
            'message': record.message,
            'context': record.context,
          },
        ),
      );

      // Capture the event
      Sentry.captureEvent(event);

      print('Sentry: Error sent to Sentry successfully');
    } catch (e) {
      print('Sentry: Failed to send error to Sentry: $e');
    }
  }

  /// Map internal severity to Sentry level
  SentryLevel _mapSeverityToSentryLevel(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return SentryLevel.info;
      case ErrorSeverity.medium:
        return SentryLevel.warning;
      case ErrorSeverity.high:
        return SentryLevel.error;
      case ErrorSeverity.critical:
        return SentryLevel.fatal;
    }
  }

  /// Start a performance transaction
  ISentrySpan? startTransaction({
    required String name,
    required String operation,
    String? description,
    Map<String, dynamic>? data,
  }) {
    if (!isSentryAvailable) {
      print('Sentry: Not available, skipping transaction');
      return null;
    }

    try {
      final transaction = Sentry.startTransaction(
        name,
        operation,
        description: description,
        bindToScope: true,
      );

      if (data != null) {
        transaction.setData('custom_data', data);
      }

      print('Sentry: Started transaction: $name');
      return transaction;
    } catch (e) {
      print('Sentry: Failed to start transaction: $e');
      return null;
    }
  }

  /// Add breadcrumb for better context
  void addBreadcrumb({
    required String message,
    required String category,
    ErrorSeverity severity = ErrorSeverity.low,
    Map<String, dynamic>? data,
  }) {
    if (!isSentryAvailable) return;

    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: message,
          category: category,
          level: _mapSeverityToSentryLevel(severity),
          data: data,
        ),
      );
    } catch (e) {
      print('Sentry: Failed to add breadcrumb: $e');
    }
  }

  /// Set user context for better error tracking
  void setUserContext(String userId, {String? username, String? email}) {
    if (!isSentryAvailable) return;

    try {
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(
          id: userId,
          username: username,
          email: email,
        ));
      });
      print('Sentry: User context set for $userId');
    } catch (e) {
      print('Sentry: Failed to set user context: $e');
    }
  }

  /// Set tag for filtering and grouping
  void setTag(String key, String value) {
    if (!isSentryAvailable) return;

    try {
      Sentry.configureScope((scope) {
        scope.setTag(key, value);
      });
    } catch (e) {
      print('Sentry: Failed to set tag: $e');
    }
  }

  /// Set extra data for additional context
  void setExtra(String key, dynamic value) {
    if (!isSentryAvailable) return;

    try {
      Sentry.configureScope((scope) {
        // ignore: deprecated_member_use
        scope.setExtra(key, value);
      });
    } catch (e) {
      print('Sentry: Failed to set extra data: $e');
    }
  }

  /// Log error with appropriate formatting
  void _logError(ErrorRecord record) {
    final severityEmoji = _getSeverityEmoji(record.severity);
    final timestamp = record.timestamp.toIso8601String();

    print('$severityEmoji [${record.source}] $timestamp: ${record.message}');

    if (record.error != null) {
      print('  Error: ${record.error}');
    }

    if (record.context.isNotEmpty) {
      print('  Context: ${record.context}');
    }
  }

  /// Get emoji for severity level
  String _getSeverityEmoji(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return 'ℹ️';
      case ErrorSeverity.medium:
        return '⚠️';
      case ErrorSeverity.high:
        return '🚨';
      case ErrorSeverity.critical:
        return '💥';
    }
  }

  /// Get error statistics for a source
  Map<String, dynamic> getErrorStats(String source) {
    final errors = _errorHistory[source] ?? [];

    if (errors.isEmpty) {
      return {
        'total_errors': 0,
        'recent_errors': 0,
        'severity_breakdown': {},
        'most_common_errors': [],
        'sentry_enabled': isSentryAvailable,
      };
    }

    final now = DateTime.now();
    final recentErrors =
        errors.where((e) => now.difference(e.timestamp).inHours < 24).length;

    final severityBreakdown = <String, int>{};
    final errorMessages = <String, int>{};

    for (final error in errors) {
      severityBreakdown[error.severity.name] =
          (severityBreakdown[error.severity.name] ?? 0) + 1;

      errorMessages[error.message] = (errorMessages[error.message] ?? 0) + 1;
    }

    final mostCommonErrors = errorMessages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'total_errors': errors.length,
      'recent_errors': recentErrors,
      'severity_breakdown': severityBreakdown,
      'most_common_errors': mostCommonErrors
          .take(5)
          .map((e) => {
                'message': e.key,
                'count': e.value,
              })
          .toList(),
      'sentry_enabled': isSentryAvailable,
    };
  }

  /// Get all error statistics
  Map<String, Map<String, dynamic>> getAllErrorStats() {
    final stats = <String, Map<String, dynamic>>{};

    for (final source in _errorHistory.keys) {
      stats[source] = getErrorStats(source);
    }

    return stats;
  }

  /// Clear error history for a source
  void clearErrorHistory(String source) {
    _errorHistory.remove(source);
  }

  /// Clear all error history
  void clearAllErrorHistory() {
    _errorHistory.clear();
  }

  /// Check if a source has too many recent errors
  bool hasTooManyRecentErrors(
    String source, {
    int threshold = 10,
    Duration window = const Duration(hours: 1),
  }) {
    final errors = _errorHistory[source] ?? [];
    final now = DateTime.now();

    final recentErrors =
        errors.where((e) => now.difference(e.timestamp) < window).length;

    return recentErrors >= threshold;
  }

  /// Get recommendations based on error patterns
  List<String> getRecommendations(String source) {
    final stats = getErrorStats(source);
    final recommendations = <String>[];

    if (stats['recent_errors'] > 5) {
      recommendations.add(
          'High error rate detected. Consider implementing circuit breaker pattern.');
    }

    final severityBreakdown =
        stats['severity_breakdown'] as Map<String, dynamic>;
    if ((severityBreakdown['critical'] ?? 0) > 0) {
      recommendations
          .add('Critical errors detected. Immediate attention required.');
    }

    if ((severityBreakdown['high'] ?? 0) > 3) {
      recommendations.add(
          'Multiple high-severity errors. Review error handling and retry logic.');
    }

    if (!stats['sentry_enabled']) {
      recommendations.add(
          'Sentry is not enabled. Consider enabling for better error tracking.');
    }

    return recommendations;
  }

  /// Print error summary
  void printErrorSummary() {
    print('\n=== Error Summary ===');
    print('Sentry Status: ${isSentryAvailable ? "✅ Enabled" : "❌ Disabled"}');

    for (final entry in _errorHistory.entries) {
      final source = entry.key;
      final stats = getErrorStats(source);
      final recommendations = getRecommendations(source);

      print('\n📊 $source:');
      print('  Total errors: ${stats['total_errors']}');
      print('  Recent errors (24h): ${stats['recent_errors']}');

      if (recommendations.isNotEmpty) {
        print('  💡 Recommendations:');
        for (final rec in recommendations) {
          print('    - $rec');
        }
      }
    }

    print('\n===================\n');
  }

  /// Flush Sentry events (useful before shutdown)
  Future<void> flush() async {
    if (!isSentryAvailable) return;

    try {
      await Sentry.close();
      print('Sentry: Events flushed successfully');
    } catch (e) {
      print('Sentry: Failed to flush events: $e');
    }
  }
}

/// Error record for tracking
class ErrorRecord {
  final DateTime timestamp;
  final String source;
  final String message;
  final dynamic error;
  final ErrorSeverity severity;
  final Map<String, dynamic> context;

  ErrorRecord({
    required this.timestamp,
    required this.source,
    required this.message,
    required this.error,
    required this.severity,
    required this.context,
  });
}

/// Extension to easily record errors with Sentry
extension ErrorRecording on Object {
  void recordError({
    required String source,
    required String message,
    ErrorSeverity severity = ErrorSeverity.medium,
    Map<String, dynamic>? context,
    String? userId,
    String? transactionName,
  }) {
    ErrorMonitor().recordError(
      source: source,
      message: message,
      error: this,
      severity: severity,
      context: context,
      userId: userId,
      transactionName: transactionName,
    );
  }
}

/// Extension for performance monitoring
extension PerformanceMonitoring on Object {
  ISentrySpan? startPerformanceTransaction({
    required String name,
    required String operation,
    String? description,
    Map<String, dynamic>? data,
  }) {
    return ErrorMonitor().startTransaction(
      name: name,
      operation: operation,
      description: description,
      data: data,
    );
  }
}
