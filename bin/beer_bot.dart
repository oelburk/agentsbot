import 'dart:async';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'commands.dart';
import 'constants/hive_constants.dart';
import 'modules/beer_agent/beer_agent_module.dart';
import 'modules/untappd/untapped_service.dart';

String BOT_TOKEN = Platform.environment['DISCORD_TOKEN'] ?? '';

late final INyxxWebsocket bot;

void main(List<String> arguments) {
  Hive.init('/data');
  Hive.openBox(HiveConstants.untappdBox);

  bot =
      NyxxFactory.createNyxxWebsocket(BOT_TOKEN, GatewayIntents.allUnprivileged)
        ..registerPlugin(Logging())
        ..registerPlugin(CliIntegration())
        ..registerPlugin(IgnoreExceptions())
        ..connect();

  final interactions = IInteractions.create(WebsocketInteractionBackend(bot));

  Commands.getCommands().forEach((command) {
    interactions.registerSlashCommand(command);
  });

  interactions.syncOnReady();

  bot.eventsWs.onReady.listen((e) {
    print('Agent Hops is ready!');
  });

  // Initialize bot modules
  BeerAgentModule().init(bot);

  Timer.periodic(Duration(minutes: 12), (timer) => checkUntappd());
}

void checkUntappd() async {
  var box = Hive.box(HiveConstants.untappdBox);

  Map<dynamic, dynamic> listOfUsers =
      await box.get(HiveConstants.untappdUserList, defaultValue: {});
  var latestCheckins =
      await box.get(HiveConstants.untappdLatestUserCheckins, defaultValue: {});

  var updateChannelId = await box.get(HiveConstants.untappdUpdateChannelId);

  if (updateChannelId == null) {
    print('No channel available for updates!');
    return;
  }

  if (listOfUsers.isEmpty) print('No users available to scrape!');

  listOfUsers.forEach((userSnowflake, untappdUsername) async {
    var latestCheckinDisk = latestCheckins[untappdUsername];
    try {
      var latestCheckinUntappd =
          await UntappdService.getLatestCheckin(untappdUsername);

      // If a new ID is available, post update!
      if (latestCheckinUntappd != null &&
          latestCheckinDisk != latestCheckinUntappd.id) {
        // Update latest saved checkin
        latestCheckins.addAll({untappdUsername: latestCheckinUntappd.id});
        await box.put(HiveConstants.untappdLatestUserCheckins, latestCheckins);

        // Build update message with info from untappd checkin
        var user = await bot.fetchUser(Snowflake(userSnowflake));
        var embedBuilder = EmbedBuilder();
        embedBuilder.title = '${user.username} is drinking beer!';
        embedBuilder.url = UntappdService.getCheckinUrl(
            latestCheckinUntappd.id, untappdUsername);
        embedBuilder.description = latestCheckinUntappd.title;
        if (latestCheckinUntappd.comment.isNotEmpty) {
          embedBuilder.addField(
              field:
                  EmbedFieldBuilder('Comment', latestCheckinUntappd.comment));
        }
        if (latestCheckinUntappd.rating.isNotEmpty) {
          embedBuilder.addField(
              field: EmbedFieldBuilder(
                  'Rating',
                  _buildRatingEmoji(
                      double.parse(latestCheckinUntappd.rating))));
        }
        if (latestCheckinUntappd.photoAddress != null) {
          embedBuilder.imageUrl = latestCheckinUntappd.photoAddress;
        }

        // Get channel used for untappd updates, previously set by discord admin.
        var updateChannel = await bot
            .fetchChannel(Snowflake(updateChannelId))
            .then((value) => (value as ITextChannel));

        // Send update message
        await updateChannel.sendMessage(MessageBuilder.embed(embedBuilder));
      }
      // Sleep 5 seconds per user to avoid suspicious requests to untappd server
      await Future.delayed(Duration(seconds: 5));
    } catch (e) {
      print(e.toString());
    }
  });
}

String _buildRatingEmoji(double rating) {
  var ratingString = '';
  for (var i = 0; i < rating.toInt(); i++) {
    ratingString += ':beer: ';
  }
  return '$ratingString ($rating)';
}
