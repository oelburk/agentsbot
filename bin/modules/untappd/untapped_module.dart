import 'dart:async';

// import 'package:hive/hive.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:web_scraper/web_scraper.dart';

import '../bot_module.dart';
import 'models/untappd_checkin.dart';
import 'repository/data_repository.dart';
import 'repository/hive_data_repository.dart';
import 'repository/in_memory_data_repository.dart';

part 'commands.dart';

class UntappdModule extends BotModule {
  static final UntappdModule _singleton = UntappdModule._internal();

  bool _isInitialized = false;

  late NyxxGateway _bot;
  late final DataRepository _repository;

  bool persistData = true;

  factory UntappdModule() {
    return _singleton;
  }
  UntappdModule._internal();

  @override
  void init(NyxxGateway bot,
      {Duration updateInterval = const Duration(minutes: 12),
      bool shouldPersistData = true}) async {
    persistData = shouldPersistData;

    _repository = persistData ? HiveDataRepository() : InMemoryDataRepository();
    await _repository.init();

    _bot = bot;

    // Start timer to check for untappd updates
    Timer.periodic(updateInterval, (timer) => _checkUntappd());

    // Set module as initialized
    _isInitialized = true;
  }

  @override
  List<ChatCommand> get commands => [
        ChatCommand(
          'untappd',
          'Let me know your untappd username so I can post automatic updates from your untappd account.',
          (
            InteractionChatContext context, [
            @Description('e.g. cornholio (kontot måste minst ha 1 incheckning)')
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
          (InteractionChatContext context) async {
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
  String get helpMessage => '**Untappd Module**\n'
      'This module allows you to post automatic updates from your untappd account.'
      '\n\n'
      'Commands:\n'
      '`/untappd` - '
      'Registers your untappd username so I can post automatic updates based on your untappd checkins.\n'
      '`/setup` - '
      'Setup the bot to post untappd updates to the current channel. (Only admins can issue this command.)';

  Future<int?> get updateChannelId async =>
      await _repository.getUpdateChannelId();

  /// Fetches and updates untappd checkins for all users
  void _checkUntappd() async {
    if (!_isInitialized) {
      print('Untappd module not initialized!');
      throw Exception('Untappd module not initialized!');
    }

    final listOfUsers = await _repository.getUserList();
    final latestCheckins = await _repository.getLatestCheckins();
    final updateChannelId = await _repository.getUpdateChannelId();

    if (updateChannelId == null) {
      print('No channel available for updates!');
      return;
    }

    if (listOfUsers.isEmpty) {
      print('No users available to scrape!');
      return;
    }

    listOfUsers.forEach((untappdUsername, userSnowflake) async {
      var latestCheckinDisk = latestCheckins[untappdUsername];
      try {
        var latestCheckinUntappd = await _getLatestCheckin(untappdUsername);

        // If a new ID is available, post update!
        if (latestCheckinUntappd != null &&
            latestCheckinDisk != latestCheckinUntappd.id) {
          // Update latest saved checkin
          latestCheckins[untappdUsername] = latestCheckinUntappd.id;
          await _repository.setLatestCheckins(latestCheckins);

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
      if (!await _isValidUsername(untappdUsername)) {
        print('No checkins available for user, ignoring add.');
        return false;
      }

      var currentList = await _repository.getUserList();
      currentList[untappdUsername] = userSnowflake.value;
      await _repository.setUserList(currentList);
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

  void setUpdateChannelId(Snowflake id) {
    _repository.setUpdateChannelId(id.value);
  }
}
