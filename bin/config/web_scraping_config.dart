/// Configuration for web scraping operations
class WebScrapingConfig {
  /// Maximum number of retry attempts for web scraping operations
  static const int maxRetries = 3;

  /// Base delay between retries (will be exponentially increased)
  static const Duration baseRetryDelay = Duration(seconds: 2);

  /// Rate limiting delay between requests to avoid being blocked
  static const Duration rateLimitDelay = Duration(seconds: 10);

  /// Timeout for web scraping operations
  static const Duration timeout = Duration(seconds: 30);

  /// User agent string to use for requests - looks like a regular browser
  static const String userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Maximum number of concurrent scraping operations
  static const int maxConcurrentOperations = 2;

  /// Whether to enable detailed logging
  static const bool enableDetailedLogging = true;

  /// Retry delays for different types of failures
  static const Map<String, Duration> retryDelays = {
    'network': Duration(seconds: 5),
    'rate_limit': Duration(seconds: 30),
    'server_error': Duration(seconds: 10),
    'timeout': Duration(seconds: 15),
  };

  /// URLs that should be treated as rate-limited
  static const List<String> rateLimitedDomains = [
    'untappd.com',
    'beerizer.com',
  ];

  /// Custom delays for specific domains
  static const Map<String, Duration> domainDelays = {
    'untappd.com': Duration(seconds: 15),
    'beerizer.com': Duration(seconds: 10),
  };

  /// Get delay for a specific domain
  static Duration getDelayForDomain(String domain) {
    return domainDelays[domain] ?? rateLimitDelay;
  }

  /// Check if a domain should be rate-limited
  static bool isRateLimitedDomain(String domain) {
    return rateLimitedDomains.contains(domain);
  }
}
