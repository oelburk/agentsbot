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

  Future<List<BeerizerBeer>> scrapeBeer(DateTime date) async {
    var formattedDate = date.toIso8601String().substring(0, 10);
    var webScraper = WebScraper();
    await webScraper
        .loadFullURL('https://beerizer.com/shop/systembolaget/$formattedDate');

    final checkins = webScraper.getElementAttribute(
        'div.beers > div.beer-table > *', 'data-id');

    print(checkins);

    if (checkins.isEmpty) {
      throw 'No beers are available for today';
    }

    var beers = <BeerizerBeer>[];

    for (var latestCheckin in checkins) {
      // Get the name of the beer
      var beerTitleAddress =
          'div.beers > div.beer-table > div#beer-$latestCheckin > div.beer-inner-top > div.left-col > div.left-col-inner > div.left-col-topper > div.left-top > div.beer-name > a.beer-title > span.title';

      final scrapedName = webScraper.getElementTitle(beerTitleAddress);
      final beerName = _cleanUpName(scrapedName.first);

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

      var value = BeerizerBeer(
        name: beerName,
        price: beerPrice,
        untappdRating: double.parse(untappdRating),
      );
      beers.add(value);
    }
    return beers;
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
