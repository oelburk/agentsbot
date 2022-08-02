import 'package:web_scraper/web_scraper.dart';

class UntappdService {
  /// Check validity of the username provided
  ///
  /// Will return true if given username has at least one checkin on Untappd.
  static Future<bool> isValidUsername(String untappdUsername) async {
    final webScraper = WebScraper('https://untappd.com');
    if (await webScraper.loadWebPage('/user/$untappdUsername')) {
      final checkins = webScraper.getElementAttribute(
          'div#main-stream > *', 'data-checkin-id');

      if (checkins.isEmpty) {
        return false;
      }
      return true;
    } else {
      throw 'Error during fetching of Untappd data';
    }
  }

  /// Get latest checkin for given username
  static Future<UntappdCheckin?> getLatestCheckin(
      String untappdUsername) async {
    final webScraper = WebScraper('https://untappd.com');
    if (await webScraper.loadWebPage('/user/$untappdUsername')) {
      final checkins = webScraper.getElementAttribute(
          'div#main-stream > *', 'data-checkin-id');

      if (checkins.isEmpty) {
        throw 'No checkins are available for $untappdUsername';
      }

      var latestCheckin = checkins.first!;

      var baseCheckinAddress =
          'div#main-stream > #checkin_$latestCheckin > div.checkin > div.top';

      final checkinTitle = webScraper
          .getElementTitle('$baseCheckinAddress > p.text')
          .first
          .trim();

      final String checkinRating = webScraper.getElement(
          '$baseCheckinAddress > div.checkin-comment > div.rating-serving > div.caps ',
          ['data-rating']).first['attributes']['data-rating'];

      final checkinComment = webScraper
          .getElementTitle(
              '$baseCheckinAddress > div.checkin-comment > p.comment-text')
          .first
          .trim();

      final photo = webScraper.getElementAttribute(
          '$baseCheckinAddress > p.photo > a > img', 'data-original');
      final checkinPhotoAddress = photo.isNotEmpty ? photo.first : null;

      return UntappdCheckin(
          id: latestCheckin,
          title: checkinTitle,
          rating: checkinRating,
          comment: checkinComment,
          photoAddress: checkinPhotoAddress);
    }
    return null;
  }

  /// Get untappd detailed checkin URL
  static String getCheckinUrl(String checkinId, String username) {
    return 'https://untappd.com/user/$username/checkin/$checkinId';
  }
}

class UntappdCheckin {
  const UntappdCheckin({
    required this.id,
    required this.title,
    required this.rating,
    required this.comment,
    this.photoAddress,
  });
  final String id;
  final String title;
  final String rating;
  final String comment;
  final String? photoAddress;

  @override
  String toString() {
    return 'title: $title\nrating: $rating\ncomment: $comment\nphoto url: $photoAddress\n';
  }
}
