import 'dart:async';

// import 'package:hive/hive.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:web_scraper/web_scraper.dart';

import '../../utils/error_monitor.dart';
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

  /// Maximum number of retry attempts for web scraping operations
  static const int _maxRetries = 3;

  /// Base delay between retries (will be exponentially increased)
  static const Duration _baseRetryDelay = Duration(seconds: 5);

  /// Rate limiting delay between requests to avoid being blocked
  static const Duration _rateLimitDelay = Duration(seconds: 10);

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

    // Add breadcrumb for module initialization
    ErrorMonitor().addBreadcrumb(
      message: 'Untappd module initialized',
      category: 'module',
      data: {
        'updateInterval': updateInterval.inMinutes,
        'persistData': persistData
      },
    );
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
      print('Untappd: Module not initialized!');
      return;
    }

    // Start performance transaction
    final transaction = startPerformanceTransaction(
      name: 'untappd_check',
      operation: 'web_scraping',
      description: 'Check for new Untappd checkins',
    );

    try {
      final listOfUsers = await _repository.getUserList();
      final latestCheckins = await _repository.getLatestCheckins();
      final updateChannelId = await _repository.getUpdateChannelId();

      if (updateChannelId == null) {
        print('Untappd: No channel available for updates!');
        return;
      }

      if (listOfUsers.isEmpty) {
        print('Untappd: No users available to scrape!');
        return;
      }

      print('Untappd: Starting check for ${listOfUsers.length} users');

      // Add breadcrumb for context
      ErrorMonitor().addBreadcrumb(
        message: 'Starting Untappd check',
        category: 'scraping',
        data: {'users_count': listOfUsers.length},
      );

      for (var entry in listOfUsers.entries) {
        var untappdUsername = entry.key;
        var userSnowflake = entry.value;
        var latestCheckinDisk = latestCheckins[untappdUsername];

        try {
          print('Untappd: Checking user $untappdUsername');
          var latestCheckinUntappd =
              await _getLatestCheckinWithRetry(untappdUsername);

          // If a new ID is available, post update!
          if (latestCheckinUntappd != null &&
              latestCheckinDisk != latestCheckinUntappd.id) {
            print('Untappd: New checkin found for $untappdUsername');

            // Update latest saved checkin
            latestCheckins[untappdUsername] = latestCheckinUntappd.id;
            await _repository.setLatestCheckins(latestCheckins);

            await _postCheckinUpdate(latestCheckinUntappd, untappdUsername,
                userSnowflake, updateChannelId);
          }

          // Rate limiting delay between users
          await Future.delayed(_rateLimitDelay);
        } catch (e) {
          e.recordError(
            source: 'Untappd',
            message: 'Error processing user $untappdUsername',
            severity: ErrorSeverity.medium,
            context: {
              'username': untappdUsername,
              'userSnowflake': userSnowflake
            },
            userId: userSnowflake.toString(),
          );
          // Continue with other users even if one fails
          continue;
        }
      }

      print('Untappd: Completed check for all users');

      // Add success breadcrumb
      ErrorMonitor().addBreadcrumb(
        message: 'Untappd check completed successfully',
        category: 'scraping',
        data: {'users_processed': listOfUsers.length},
      );
    } catch (e) {
      e.recordError(
        source: 'Untappd',
        message: 'Error in _checkUntappd',
        severity: ErrorSeverity.high,
      );
      print('Untappd: Error in _checkUntappd: $e');
    } finally {
      // Finish performance transaction
      transaction?.finish();
    }
  }

  /// Post checkin update to Discord channel
  Future<void> _postCheckinUpdate(UntappdCheckin checkin, String username,
      int userSnowflake, int updateChannelId) async {
    try {
      // Build update message with info from untappd checkin
      var user = await _bot.users.fetch(Snowflake(userSnowflake));
      var embedBuilder = EmbedBuilder();
      embedBuilder.title = '${user.username} is drinking beer!';
      embedBuilder.url = Uri.parse(_getCheckinUrl(checkin.id, username));
      embedBuilder.description = checkin.title;
      embedBuilder.fields = [];

      if (checkin.comment.isNotEmpty) {
        embedBuilder.fields?.add(EmbedFieldBuilder(
            name: 'Comment', value: checkin.comment, isInline: false));
      }

      if (checkin.rating.isNotEmpty && checkin.rating != '0') {
        try {
          final rating = double.parse(checkin.rating);
          embedBuilder.fields!.add(
            EmbedFieldBuilder(
              name: 'Rating',
              value: _buildRatingEmoji(rating),
              isInline: true,
            ),
          );
        } catch (e) {
          e.recordError(
            source: 'Untappd',
            message: 'Error parsing rating',
            severity: ErrorSeverity.low,
            context: {'rating': checkin.rating, 'username': username},
          );
          print('Untappd: Error parsing rating: $e');
        }
      }

      if (checkin.photoAddress != null) {
        embedBuilder.image =
            EmbedImageBuilder(url: Uri.parse(checkin.photoAddress!));
      }

      // Get channel used for untappd updates, previously set by discord admin.
      var updateChannel = await _bot.channels.fetch(Snowflake(updateChannelId))
          as PartialTextChannel;

      // Send update message
      await updateChannel.sendMessage(MessageBuilder(embeds: [embedBuilder]));

      print('Untappd: Posted update for $username');

      // Add breadcrumb for successful post
      ErrorMonitor().addBreadcrumb(
        message: 'Posted Untappd update',
        category: 'discord',
        data: {'username': username, 'checkinId': checkin.id},
      );
    } catch (e) {
      e.recordError(
        source: 'Untappd',
        message: 'Error posting update for $username',
        severity: ErrorSeverity.medium,
        context: {'username': username, 'checkinId': checkin.id},
        userId: userSnowflake.toString(),
      );
      print('Untappd: Error posting update for $username: $e');
    }
  }

  /// Get latest checkin with retry logic
  Future<UntappdCheckin?> _getLatestCheckinWithRetry(
      String untappdUsername) async {
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        print(
            'Untappd: Attempting to get latest checkin for $untappdUsername (attempt $attempt/$_maxRetries)');
        return await _getLatestCheckin(untappdUsername);
      } catch (e) {
        print('Untappd: Attempt $attempt failed for $untappdUsername: $e');

        e.recordError(
          source: 'Untappd',
          message: 'Get latest checkin attempt $attempt failed',
          severity: attempt == _maxRetries
              ? ErrorSeverity.high
              : ErrorSeverity.medium,
          context: {'username': untappdUsername, 'attempt': attempt},
        );

        if (attempt == _maxRetries) {
          print('Untappd: All retry attempts failed for $untappdUsername');
          return null;
        }

        // Exponential backoff
        var delay = Duration(
            milliseconds:
                _baseRetryDelay.inMilliseconds * (1 << (attempt - 1)));
        print('Untappd: Retrying in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }
    return null;
  }

  /// Check validity of the username provided with retry logic
  Future<bool> _isValidUsernameWithRetry(String untappdUsername) async {
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        print(
            'Untappd: Validating username $untappdUsername (attempt $attempt/$_maxRetries)');
        return await _isValidUsername(untappdUsername);
      } catch (e) {
        print(
            'Untappd: Username validation attempt $attempt failed for $untappdUsername: $e');

        e.recordError(
          source: 'Untappd',
          message: 'Username validation attempt $attempt failed',
          severity: attempt == _maxRetries
              ? ErrorSeverity.high
              : ErrorSeverity.medium,
          context: {'username': untappdUsername, 'attempt': attempt},
        );

        if (attempt == _maxRetries) {
          print('Untappd: All validation attempts failed for $untappdUsername');
          return false;
        }

        // Exponential backoff
        var delay = Duration(
            milliseconds:
                _baseRetryDelay.inMilliseconds * (1 << (attempt - 1)));
        await Future.delayed(delay);
      }
    }
    return false;
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
      if (!await _isValidUsernameWithRetry(untappdUsername)) {
        print(
            'Untappd: No checkins available for user $untappdUsername, ignoring add.');
        return false;
      }

      var currentList = await _repository.getUserList();
      currentList[untappdUsername] = userSnowflake.value;
      await _repository.setUserList(currentList);
      print('Untappd: Saved user $untappdUsername to repository!');

      // Add breadcrumb for successful registration
      ErrorMonitor().addBreadcrumb(
        message: 'User registered successfully',
        category: 'user',
        data: {'username': untappdUsername, 'userId': userSnowflake.value},
      );

      return true;
    } catch (e) {
      e.recordError(
        source: 'Untappd',
        message: 'Error registering user $untappdUsername',
        severity: ErrorSeverity.medium,
        context: {
          'username': untappdUsername,
          'userSnowflake': userSnowflake.value
        },
        userId: userSnowflake.value.toString(),
      );
      print('Untappd: Error registering user $untappdUsername: $e');
      return false;
    }
  }

  /// Check validity of the username provided
  ///
  /// Will return **true** if given username has at least one checkin on Untappd.
  Future<bool> _isValidUsername(String untappdUsername) async {
    try {
      final webScraper = WebScraper('https://untappd.com');
      var loadSuccess = await webScraper.loadWebPage('/user/$untappdUsername');

      if (!loadSuccess) {
        throw Exception(
            'Failed to load Untappd page for user $untappdUsername');
      }

      final checkins = webScraper.getElementAttribute(
          'div#main-stream > *', 'data-checkin-id');

      if (checkins.isEmpty) {
        print('Untappd: No checkins found for user $untappdUsername');
        return false;
      }

      print(
          'Untappd: Found ${checkins.length} checkins for user $untappdUsername');
      return true;
    } catch (e) {
      e.recordError(
        source: 'Untappd',
        message: 'Error validating username $untappdUsername',
        severity: ErrorSeverity.medium,
        context: {'username': untappdUsername},
      );
      print('Untappd: Error validating username $untappdUsername: $e');
      rethrow;
    }
  }

  /// Get latest checkin for given untapped username
  Future<UntappdCheckin?> _getLatestCheckin(String untappdUsername) async {
    try {
      final webScraper = WebScraper('https://untappd.com');

      var loadSuccess = await webScraper.loadWebPage('/user/$untappdUsername');

      if (!loadSuccess) {
        throw Exception(
            'Failed to load Untappd page for user $untappdUsername');
      }

      final checkins = webScraper.getElementAttribute(
          'div#main-stream > *', 'data-checkin-id');

      if (checkins.isEmpty) {
        print('Untappd: No checkins are available for $untappdUsername');
        return null;
      }

      var latestCheckin = checkins.first;
      if (latestCheckin == null) {
        print('Untappd: Latest checkin is null for $untappdUsername');
        return null;
      }

      var baseCheckinAddress = 'div#main-stream > #checkin_$latestCheckin';

      final checkinTitleElement = webScraper.getElementAttribute(
          '$baseCheckinAddress > div > div.checkin > div.top > a > img', 'alt');
      final checkinTitle =
          checkinTitleElement.isEmpty ? '' : checkinTitleElement.first;

      final checkinRatingElement = webScraper.getElement(
          '$baseCheckinAddress > div > div.checkin > div.top > div > div.rating-serving > div',
          ['data-rating']);
      final String checkinRating = checkinRatingElement.isEmpty
          ? '0'
          : checkinRatingElement.first['attributes']['data-rating'] ?? '0';

      final checkinCommentElement =
          webScraper.getElementTitle('#translate_$latestCheckin');
      final checkinComment = checkinCommentElement.isEmpty
          ? ''
          : checkinCommentElement.first.trim();

      final photo = webScraper.getElementAttribute(
          '$baseCheckinAddress > div > div.checkin > div.top > p.photo > a > img',
          'src');
      final checkinPhotoAddress = photo.isNotEmpty ? photo.first : null;

      return UntappdCheckin(
          id: latestCheckin,
          title: checkinTitle ?? '',
          rating: checkinRating,
          comment: checkinComment,
          photoAddress: checkinPhotoAddress);
    } catch (e) {
      e.recordError(
        source: 'Untappd',
        message: 'Error getting latest checkin for $untappdUsername',
        severity: ErrorSeverity.medium,
        context: {'username': untappdUsername},
      );
      print('Untappd: Error getting latest checkin for $untappdUsername: $e');
      rethrow;
    }
  }

  /// Get untappd detailed checkin URL
  String _getCheckinUrl(String checkinId, String username) =>
      'https://untappd.com/user/$username/checkin/$checkinId';

  void setUpdateChannelId(Snowflake id) {
    _repository.setUpdateChannelId(id.value);
  }
}
