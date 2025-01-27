import 'package:web_scraper/web_scraper.dart';

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

  Future<List<BeerizerBeer>> _scrape(DateTime date) async {
    var formattedDate = date.toIso8601String().substring(0, 10);
    var webScraper = WebScraper();
    await webScraper
        .loadFullURL('https://beerizer.com/shop/systembolaget/$formattedDate');

    final checkins = webScraper.getElementAttribute(
        'div.beers > div.beer-table > *', 'data-id');

    print(checkins);

    if (checkins.isEmpty) {
      return [];
    }

    var beers = <BeerizerBeer>[];

    for (var latestCheckin in checkins) {
      // Get the name of the beer
      var beerTitleAddress =
          'div.beers > div.beer-table > div#beer-$latestCheckin > div.beer-inner-top > div.left-col > div.left-col-inner > div.left-col-topper > div.left-top > div.beer-name > a.beer-title > span.title';

      final scrapedName = webScraper.getElementTitle(beerTitleAddress);
      final beerName = _cleanUpName(scrapedName.first);

      // Get the brewery of the beer
      var beerBreweryAddress =
          'div.beers > div.beer-table > div#beer-$latestCheckin > div.beer-inner-top > div.left-col > div.left-col-inner > div.left-col-topper > div.left-top > div.beer-name > a.beer-title > span.brewery-title';
      final scrapedBrewery = webScraper.getElementTitle(beerBreweryAddress);
      print(scrapedBrewery);
      final beerBrewery = _cleanUpName(scrapedBrewery.first);

      // Get the price of the beer
      var beerPriceAdress =
          'div.beers > div.beer-table > div#beer-$latestCheckin > div.beer-inner-top > div.left-col > div.left-col-inner > div.mid-col > div.mid-price-col';
      final scrapedTitle = webScraper.getElementTitle(beerPriceAdress);
      final beerPrice = _cleanUpPrice(scrapedTitle.first);

      // Get Untappd rating
      var untappdRatingAddress =
          'div.beers > div.beer-table > div#beer-$latestCheckin > div.beer-inner-top > div.right-col';
      final scrapedUntappdRating =
          webScraper.getElementTitle(untappdRatingAddress);
      final untappdRating = _cleanUpUntappdRating(scrapedUntappdRating.first);

      // Get style of the beer
      var beerStyleAddress =
          'div.beers > div.beer-table > div#beer-$latestCheckin > div.beer-inner-top > div.right-col';
      final scrapedStyle = webScraper.getElementTitle(beerStyleAddress);
      final beerStyle = _cleanUpStyle(scrapedStyle.first);

      var value = BeerizerBeer(
        name: beerName,
        brewery: beerBrewery,
        price: beerPrice,
        untappdRating: untappdRating,
        style: beerStyle,
      );
      beers.add(value);
    }
    return beers;
  }

  /// Scrape the given date's beers from Beerizer
  Future<void> scrapeBeer(DateTime date) async {
    _beers = await _scrape(date);
  }

  Future<List<BeerizerBeer>> quickScrape(String date) async {
    return await _scrape(DateTime.parse(date));
  }

  String _cleanUpStyle(String style) {
    var onlyStyle = style.trim();
    final stringlist = onlyStyle.split('\n');

    onlyStyle = stringlist[17].trimLeft();
    if (onlyStyle.isEmpty) {
      onlyStyle = stringlist[14].trimLeft();
    }

    return onlyStyle;
  }

  String _cleanUpName(String name) {
    var onlyPrice = name.trim();
    onlyPrice = onlyPrice.replaceAll('\n', '').trim();

    final firstWhitespace = onlyPrice.indexOf('  ');
    if (firstWhitespace != -1) {
      onlyPrice = onlyPrice.substring(0, firstWhitespace + 1) +
          onlyPrice.substring(firstWhitespace + 1).replaceAll(' ', '');
    }

    return onlyPrice;
  }

  String _cleanUpPrice(String price) {
    final onlyPrice = price.trim().substring(3);
    final firstWhitespace = onlyPrice.indexOf(' ');

    return onlyPrice.substring(0, firstWhitespace - 1).trim();
  }

  String _cleanUpUntappdRating(String rating) {
    return rating.trim().substring(0, 5).trim();
  }
}
