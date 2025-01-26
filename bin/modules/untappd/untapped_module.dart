import 'dart:async';

import 'package:hive/hive.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:web_scraper/web_scraper.dart';

import '../bot_module.dart';
import 'hive_constants.dart';
import 'models/untappd_checkin.dart';

part 'commands.dart';

class UntappdModule extends BotModule {
  static final UntappdModule _singleton = UntappdModule._internal();

  bool _isInitialized = false;

  late NyxxGateway _bot;

  factory UntappdModule() {
    return _singleton;
  }
  UntappdModule._internal();

  /// Fetches and updates untappd checkins for all users
  void _checkUntappd() async {
    if (!_isInitialized) {
      print('Untappd module not initialized!');
      throw Exception('Untappd module not initialized!');
    }
    var box = Hive.box(HiveConstants.untappdBox);

    Map<int, String> listOfUsers =
        await box.get(HiveConstants.untappdUserList, defaultValue: {});
    var latestCheckins = await box
        .get(HiveConstants.untappdLatestUserCheckins, defaultValue: {});

    var updateChannelId = await box.get(HiveConstants.untappdUpdateChannelId);

    if (updateChannelId == null) {
      print('No channel available for updates!');
      return;
    }

    if (listOfUsers.isEmpty) print('No users available to scrape!');

    listOfUsers.forEach((userSnowflake, untappdUsername) async {
      var latestCheckinDisk = latestCheckins[untappdUsername];
      try {
        var latestCheckinUntappd = await _getLatestCheckin(untappdUsername);

        // If a new ID is available, post update!
        if (latestCheckinUntappd != null &&
            latestCheckinDisk != latestCheckinUntappd.id) {
          // Update latest saved checkin
          latestCheckins.addAll({untappdUsername: latestCheckinUntappd.id});
          await box.put(
              HiveConstants.untappdLatestUserCheckins, latestCheckins);

          // Build update message with info from untappd checkin
          var user = await _bot.users.fetch(Snowflake(userSnowflake));
          var embedBuilder = EmbedBuilder();
          embedBuilder.title = '${user.username} is drinking beer!';
          embedBuilder.url = Uri.dataFromString(
              _getCheckinUrl(latestCheckinUntappd.id, untappdUsername));
          embedBuilder.description = latestCheckinUntappd.title;
          if (latestCheckinUntappd.comment.isNotEmpty) {
            embedBuilder.fields?.add(EmbedFieldBuilder(
                name: 'Comment',
                value: latestCheckinUntappd.comment,
                isInline: false));
          }
          if (latestCheckinUntappd.rating.isNotEmpty) {
            embedBuilder.fields?.add(
              EmbedFieldBuilder(
                name: 'Rating',
                value: _buildRatingEmoji(
                  double.parse(latestCheckinUntappd.rating),
                ),
                isInline: false,
              ),
            );
          }
          if (latestCheckinUntappd.photoAddress != null) {
            embedBuilder.image?.url =
                Uri.dataFromString(latestCheckinUntappd.photoAddress!);
          }

          // Get channel used for untappd updates, previously set by discord admin.
          var updateChannel = await _bot.channels
              .fetch(Snowflake(updateChannelId)) as PartialTextChannel;

          // Send update message
          await updateChannel
              .sendMessage(MessageBuilder(embeds: [embedBuilder]));
        }
        // Sleep 5 seconds per user to avoid suspicious requests to untappd server
        await Future.delayed(Duration(seconds: 5));
      } catch (e) {
        print(e.toString());
      }
    });
  }

  /// Builds the rating emoji string
  String _buildRatingEmoji(double rating) {
    var ratingString = '';
    for (var i = 0; i < rating.toInt(); i++) {
      ratingString += ':beer: ';
    }
    return '$ratingString ($rating)';
  }

  /// Register untappd username for given user snowflake
  Future<bool> _regUntappdUser(
      Snowflake userSnowflake, String untappdUsername) async {
    try {
      var box = Hive.box(HiveConstants.untappdBox);

      if (!await _isValidUsername(untappdUsername)) {
        print('No checkins available for user, ignoring add.');
        return false;
      }

      var currentList =
          box.get(HiveConstants.untappdUserList, defaultValue: {});
      currentList.addAll({userSnowflake.toString(): untappdUsername});
      await box.put(HiveConstants.untappdUserList, currentList);
      print('Saved ${currentList.toString()} to Hive box!');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check validity of the username provided
  ///
  /// Will return **true** if given username has at least one checkin on Untappd.
  Future<bool> _isValidUsername(String untappdUsername) async {
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

  /// Get latest checkin for given untapped username
  Future<UntappdCheckin?> _getLatestCheckin(String untappdUsername) async {
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

      final checkinTitleElement =
          webScraper.getElementTitle('$baseCheckinAddress > p.text');
      final checkinTitle =
          checkinTitleElement.isEmpty ? '' : checkinTitleElement.first.trim();

      final checkinRatingElement = webScraper.getElement(
          '$baseCheckinAddress > div.checkin-comment > div.rating-serving > div.caps ',
          ['data-rating']);
      final String checkinRating = checkinRatingElement.isEmpty
          ? '0'
          : checkinRatingElement.first['attributes']['data-rating'];

      final checkinCommentElement = webScraper.getElementTitle(
          '$baseCheckinAddress > div.checkin-comment > p.comment-text');
      final checkinComment = checkinCommentElement.isEmpty
          ? ''
          : checkinCommentElement.first.trim();

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
  String _getCheckinUrl(String checkinId, String username) =>
      'https://untappd.com/user/$username/checkin/$checkinId';

  @override
  void init(NyxxGateway bot,
      {Duration updateInterval = const Duration(minutes: 12)}) {
    // Set up Hive for local data storage
    Hive.init('/data');
    Hive.openBox(HiveConstants.untappdBox);

    _bot = bot;

    // Start timer to check for untappd updates
    Timer.periodic(updateInterval, (timer) => _checkUntappd());

    // Set module as initialized
    _isInitialized = true;
  }

  @override
  List<ChatCommand> get commands => !_isInitialized
      ? throw Exception('Untappd module not initialized!')
      : [
          ChatCommand('untappd',
              'Let me know your untappd username so I can post automatic updates from your untappd account.',
              (ChatContext context) async {
            await _untappdCommand(context);
          }),
          ChatCommand(
            'untappd',
            'Let me know your untappd username so I can post automatic updates from your untappd account.',
            (
              ChatContext context, [
              @Description(
                  'e.g. cornholio (kontot måste minst ha 1 incheckning)')
              String? username,
            ]) async {
              if (username == null) {
                await context.respond(MessageBuilder(
                    content: 'Are you drunk buddy? Your username is missing.'));
                return;
              }
              await _untappdCommand(context);
            },
            options: CommandOptions(
              autoAcknowledgeInteractions: true,
              type: CommandType.slashOnly,
            ),
          ),
          ChatCommand(
            'setup',
            'Setup the bot to post untappd updates to the current channel.',
            (ChatContext context) async {
              context.member?.permissions?.isAdministrator ?? false
                  ? await _setupUntappdServiceCommand(context)
                  : await context.respond(MessageBuilder(
                      content: 'Only admins can issue this command!'));
            },
            options: CommandOptions(
              autoAcknowledgeInteractions: true,
              type: CommandType.slashOnly,
            ),
          ),
        ];

  @override
  MessageBuilder get helpMessage => !_isInitialized
      ? throw Exception('Untappd module not initialized!')
      : MessageBuilder(
          content: '**Untappd Module**\n\n'
              'This module allows you to post automatic updates from your untappd account.'
              '\n\n'
              '**Commands**\n'
              '/untappd\n'
              'Registers your untappd username so I can post automatic updates based on your untappd checkins.\n\n'
              '/setup\n'
              'Setup the bot to post untappd updates to the current channel. (Only admins can issue this command.)',
        );
}
