import 'dart:async';

import 'package:web_scraper/web_scraper.dart';

import '../../utils/error_monitor.dart';
import 'models/beerizer_beer.dart';

class BeerizerService {
  static final BeerizerService _singleton = BeerizerService._internal();
  factory BeerizerService() {
    return _singleton;
  }
  BeerizerService._internal();

  bool get isInitialized => _isInitialized;

  final bool _isInitialized = false;

  List<BeerizerBeer> _beers = [];

  /// List of latest beers scraped from Beerizer
  List<BeerizerBeer> get beers => _beers;

  /// Maximum number of retry attempts for web scraping operations
  static const int _maxRetries = 3;

  /// Base delay between retries (will be exponentially increased)
  static const Duration _baseRetryDelay = Duration(seconds: 2);

  /// Scrape beers with retry logic and error handling
  Future<List<BeerizerBeer>> _scrape(DateTime date) async {
    var formattedDate = date.toIso8601String().substring(0, 10);
    var url = 'https://beerizer.com/shop/systembolaget/$formattedDate';

    // Start performance transaction
    final transaction = startPerformanceTransaction(
      name: 'beerizer_scrape',
      operation: 'web_scraping',
      description: 'Scrape beers from Beerizer for date $formattedDate',
      data: {'date': formattedDate, 'url': url},
    );

    try {
      // Add breadcrumb for context
      ErrorMonitor().addBreadcrumb(
        message: 'Starting Beerizer scrape',
        category: 'scraping',
        data: {'date': formattedDate, 'url': url},
      );

      for (var attempt = 1; attempt <= _maxRetries; attempt++) {
        try {
          print(
              'Beerizer: Attempting to scrape $url (attempt $attempt/$_maxRetries)');

          var webScraper = WebScraper();
          var loadSuccess = await webScraper.loadFullURL(url);

          if (!loadSuccess) {
            throw Exception('Failed to load URL: $url');
          }

          final checkins = webScraper.getElementAttribute(
              'div.beers > div.beer-table > *', 'data-id');

          print('Beerizer: Found ${checkins.length} checkins');

          if (checkins.isEmpty) {
            print('Beerizer: No beers found for date $formattedDate');
            return [];
          }

          var beers = <BeerizerBeer>[];

          for (var latestCheckin in checkins) {
            try {
              if (latestCheckin == null) continue;
              var beer = await _scrapeBeerDetails(webScraper, latestCheckin);
              if (beer != null) {
                beers.add(beer);
              }
            } catch (e) {
              e.recordError(
                source: 'Beerizer',
                message: 'Error scraping beer $latestCheckin',
                severity: ErrorSeverity.medium,
                context: {
                  'checkinId': latestCheckin,
                  'url': url,
                  'attempt': attempt
                },
              );
              // Continue with other beers even if one fails
              continue;
            }
          }

          print(
              'Beerizer: Successfully scraped ${beers.length} beers from Beerizer');

          // Add success breadcrumb
          ErrorMonitor().addBreadcrumb(
            message: 'Beerizer scrape completed successfully',
            category: 'scraping',
            data: {'beers_count': beers.length, 'date': formattedDate},
          );

          return beers;
        } catch (e) {
          print('Beerizer: Attempt $attempt failed: $e');

          e.recordError(
            source: 'Beerizer',
            message: 'Scraping attempt $attempt failed',
            severity: attempt == _maxRetries
                ? ErrorSeverity.high
                : ErrorSeverity.medium,
            context: {'attempt': attempt, 'url': url, 'date': formattedDate},
          );

          if (attempt == _maxRetries) {
            print(
                'Beerizer: All retry attempts failed for date $formattedDate');
            return [];
          }

          // Exponential backoff
          var delay = Duration(
              milliseconds:
                  _baseRetryDelay.inMilliseconds * (1 << (attempt - 1)));
          print('Beerizer: Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }

      return [];
    } finally {
      // Finish performance transaction
      await transaction?.finish();
    }
  }

  /// Scrape individual beer details with error handling
  Future<BeerizerBeer?> _scrapeBeerDetails(
      WebScraper webScraper, String checkinId) async {
    try {
      // Get the name of the beer
      var beerTitleAddress =
          'div.beers > div.beer-table > div#beer-$checkinId > div.beer-inner-top > div.left-col > div.left-col-inner > div.left-col-topper > div.left-top > div.beer-name > a.beer-title > span.title';

      final scrapedName = webScraper.getElementTitle(beerTitleAddress);
      if (scrapedName.isEmpty) {
        print('Beerizer: Could not find beer name for checkin $checkinId');
        return null;
      }
      final beerName = _cleanUpName(scrapedName.first);

      // Get the brewery of the beer
      var beerBreweryAddress =
          'div.beers > div.beer-table > div#beer-$checkinId > div.beer-inner-top > div.left-col > div.left-col-inner > div.left-col-topper > div.left-top > div.beer-name > a.beer-title > span.brewery-title';
      final scrapedBrewery = webScraper.getElementTitle(beerBreweryAddress);
      final beerBrewery = scrapedBrewery.isEmpty
          ? 'Unknown Brewery'
          : _cleanUpName(scrapedBrewery.first);

      // Get the price of the beer
      var beerPriceAdress =
          'div.beers > div.beer-table > div#beer-$checkinId > div.beer-inner-top > div.left-col > div.left-col-inner > div.mid-col > div.mid-price-col';
      final scrapedTitle = webScraper.getElementTitle(beerPriceAdress);
      final beerPrice =
          scrapedTitle.isEmpty ? 'N/A' : _cleanUpPrice(scrapedTitle.first);

      // Get Untappd rating
      var untappdRatingAddress =
          'div.beers > div.beer-table > div#beer-$checkinId > div.beer-inner-top > div.right-col';
      final scrapedUntappdRating =
          webScraper.getElementTitle(untappdRatingAddress);
      final untappdRating = scrapedUntappdRating.isEmpty
          ? 'N/A'
          : _cleanUpUntappdRating(scrapedUntappdRating.first);

      // Get style of the beer
      var beerStyleAddress =
          'div.beers > div.beer-table > div#beer-$checkinId > div.beer-inner-top > div.right-col';
      final scrapedStyle = webScraper.getElementTitle(beerStyleAddress);
      final beerStyle = scrapedStyle.isEmpty
          ? 'Unknown Style'
          : _cleanUpStyle(scrapedStyle.first);

      return BeerizerBeer(
        name: beerName,
        brewery: beerBrewery,
        price: beerPrice,
        untappdRating: untappdRating,
        style: beerStyle,
      );
    } catch (e) {
      e.recordError(
        source: 'Beerizer',
        message: 'Error scraping beer details for $checkinId',
        severity: ErrorSeverity.medium,
        context: {'checkinId': checkinId},
      );
      return null;
    }
  }

  /// Scrape the given date's beers from Beerizer
  Future<void> scrapeBeer(DateTime date) async {
    try {
      _beers = await _scrape(date);
    } catch (e) {
      e.recordError(
        source: 'Beerizer',
        message: 'Error in scrapeBeer',
        severity: ErrorSeverity.high,
        context: {'date': date.toIso8601String()},
      );
      print('Beerizer: Error in scrapeBeer: $e');
      _beers = [];
    }
  }

  Future<List<BeerizerBeer>> quickScrape(String date) async {
    try {
      return await _scrape(DateTime.parse(date));
    } catch (e) {
      e.recordError(
        source: 'Beerizer',
        message: 'Error in quickScrape',
        severity: ErrorSeverity.high,
        context: {'date': date},
      );
      print('Beerizer: Error in quickScrape: $e');
      return [];
    }
  }

  String _cleanUpStyle(String style) {
    try {
      var onlyStyle = style.trim();
      final stringlist = onlyStyle.split('\n');

      if (stringlist.length > 17) {
        onlyStyle = stringlist[17].trimLeft();
      } else if (stringlist.length > 14) {
        onlyStyle = stringlist[14].trimLeft();
      } else {
        onlyStyle = 'Unknown Style';
      }

      return onlyStyle.isEmpty ? 'Unknown Style' : onlyStyle;
    } catch (e) {
      e.recordError(
        source: 'Beerizer',
        message: 'Error cleaning up style',
        severity: ErrorSeverity.low,
        context: {'style': style},
      );
      print('Beerizer: Error cleaning up style: $e');
      return 'Unknown Style';
    }
  }

  String _cleanUpName(String name) {
    try {
      var onlyPrice = name.trim();
      onlyPrice = onlyPrice.replaceAll('\n', '').trim();

      final firstWhitespace = onlyPrice.indexOf('  ');
      if (firstWhitespace != -1) {
        onlyPrice = onlyPrice.substring(0, firstWhitespace + 1) +
            onlyPrice.substring(firstWhitespace + 1).replaceAll(' ', '');
      }

      return onlyPrice.isEmpty ? 'Unknown Beer' : onlyPrice;
    } catch (e) {
      e.recordError(
        source: 'Beerizer',
        message: 'Error cleaning up name',
        severity: ErrorSeverity.low,
        context: {'name': name},
      );
      print('Beerizer: Error cleaning up name: $e');
      return 'Unknown Beer';
    }
  }

  String _cleanUpPrice(String price) {
    try {
      if (price.length < 3) return 'N/A';
      final onlyPrice = price.trim().substring(3);
      final firstWhitespace = onlyPrice.indexOf(' ');

      if (firstWhitespace == -1) return onlyPrice.trim();
      return onlyPrice.substring(0, firstWhitespace - 1).trim();
    } catch (e) {
      e.recordError(
        source: 'Beerizer',
        message: 'Error cleaning up price',
        severity: ErrorSeverity.low,
        context: {'price': price},
      );
      print('Beerizer: Error cleaning up price: $e');
      return 'N/A';
    }
  }

  String _cleanUpUntappdRating(String rating) {
    try {
      if (rating.length < 5) return 'N/A';
      return rating.trim().substring(0, 5).trim();
    } catch (e) {
      e.recordError(
        source: 'Beerizer',
        message: 'Error cleaning up Untappd rating',
        severity: ErrorSeverity.low,
        context: {'rating': rating},
      );
      print('Beerizer: Error cleaning up Untappd rating: $e');
      return 'N/A';
    }
  }
}
