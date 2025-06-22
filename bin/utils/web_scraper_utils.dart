import 'dart:async';

import 'package:web_scraper/web_scraper.dart';

/// Utility class for robust web scraping operations
class WebScraperUtils {
  /// Maximum number of retry attempts for web scraping operations
  static const int defaultMaxRetries = 3;

  /// Base delay between retries (will be exponentially increased)
  static const Duration defaultBaseRetryDelay = Duration(seconds: 2);

  /// Default rate limiting delay between requests
  static const Duration defaultRateLimitDelay = Duration(seconds: 5);

  /// Scrape a web page with retry logic and error handling
  static Future<WebScraper?> scrapePageWithRetry(
    String baseUrl,
    String path, {
    int maxRetries = defaultMaxRetries,
    Duration baseRetryDelay = defaultBaseRetryDelay,
    String? logPrefix,
  }) async {
    final prefix = logPrefix ?? 'WebScraper';

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
            '$prefix: Attempting to scrape $baseUrl$path (attempt $attempt/$maxRetries)');

        var webScraper = WebScraper(baseUrl);
        var loadSuccess = await webScraper.loadWebPage(path);

        if (!loadSuccess) {
          throw Exception('Failed to load URL: $baseUrl$path');
        }

        print('$prefix: Successfully loaded page');
        return webScraper;
      } catch (e) {
        print('$prefix: Attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          print('$prefix: All retry attempts failed for $baseUrl$path');
          return null;
        }

        // Exponential backoff
        var delay = Duration(
            milliseconds: baseRetryDelay.inMilliseconds * (1 << (attempt - 1)));
        print('$prefix: Retrying in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }

    return null;
  }

  /// Scrape a full URL with retry logic and error handling
  static Future<WebScraper?> scrapeFullUrlWithRetry(
    String url, {
    int maxRetries = defaultMaxRetries,
    Duration baseRetryDelay = defaultBaseRetryDelay,
    String? logPrefix,
  }) async {
    final prefix = logPrefix ?? 'WebScraper';

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
            '$prefix: Attempting to scrape $url (attempt $attempt/$maxRetries)');

        var webScraper = WebScraper();
        var loadSuccess = await webScraper.loadFullURL(url);

        if (!loadSuccess) {
          throw Exception('Failed to load URL: $url');
        }

        print('$prefix: Successfully loaded page');
        return webScraper;
      } catch (e) {
        print('$prefix: Attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          print('$prefix: All retry attempts failed for $url');
          return null;
        }

        // Exponential backoff
        var delay = Duration(
            milliseconds: baseRetryDelay.inMilliseconds * (1 << (attempt - 1)));
        print('$prefix: Retrying in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }

    return null;
  }

  /// Safely get element attribute with error handling
  static List<String?> getElementAttributeSafely(
    WebScraper webScraper,
    String selector,
    String attribute, {
    String? logPrefix,
  }) {
    try {
      final result = webScraper.getElementAttribute(selector, attribute);
      final prefix = logPrefix ?? 'WebScraper';
      print(
          '$prefix: Found ${result.length} elements with selector: $selector');
      return result;
    } catch (e) {
      print(
          '${logPrefix ?? 'WebScraper'}: Error getting element attribute: $e');
      return [];
    }
  }

  /// Safely get element title with error handling
  static List<String> getElementTitleSafely(
    WebScraper webScraper,
    String selector, {
    String? logPrefix,
  }) {
    try {
      final result = webScraper.getElementTitle(selector);
      final prefix = logPrefix ?? 'WebScraper';
      print('$prefix: Found ${result.length} titles with selector: $selector');
      return result;
    } catch (e) {
      print('${logPrefix ?? 'WebScraper'}: Error getting element title: $e');
      return [];
    }
  }

  /// Safely get element with error handling
  static List<Map<String, dynamic>> getElementSafely(
    WebScraper webScraper,
    String selector,
    List<String> attributes, {
    String? logPrefix,
  }) {
    try {
      final result = webScraper.getElement(selector, attributes);
      final prefix = logPrefix ?? 'WebScraper';
      print(
          '$prefix: Found ${result.length} elements with selector: $selector');
      return result;
    } catch (e) {
      print('${logPrefix ?? 'WebScraper'}: Error getting element: $e');
      return [];
    }
  }

  /// Rate limiting delay
  static Future<void> rateLimitDelay(Duration delay) async {
    print('WebScraper: Rate limiting for ${delay.inSeconds} seconds...');
    await Future.delayed(delay);
  }

  /// Validate that a list is not empty and contains valid data
  static bool isValidData(List<dynamic> data, {String? logPrefix}) {
    if (data.isEmpty) {
      print('${logPrefix ?? 'WebScraper'}: No data found');
      return false;
    }
    return true;
  }

  /// Clean up text data safely
  static String cleanTextSafely(String text, {String defaultValue = 'N/A'}) {
    try {
      final cleaned = text.trim();
      return cleaned.isEmpty ? defaultValue : cleaned;
    } catch (e) {
      print('WebScraper: Error cleaning text: $e');
      return defaultValue;
    }
  }

  /// Parse number safely
  static double parseNumberSafely(String text, {double defaultValue = 0.0}) {
    try {
      return double.parse(text);
    } catch (e) {
      print('WebScraper: Error parsing number "$text": $e');
      return defaultValue;
    }
  }
}
