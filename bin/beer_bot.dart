import 'dart:async';
import 'package:hive/hive.dart';
import 'package:nyxx/nyxx.dart';
import 'package:http/http.dart' as http;
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'dart:convert';
import 'dart:io';
import 'beer.dart';
import 'beerlist.dart';
import 'commands.dart';
import 'constants/hive_constants.dart';
import 'untapped_service.dart';
import 'utils.dart';
import 'package:intl/intl.dart';

String BOT_TOKEN = Platform.environment['DISCORD_TOKEN'] ?? '';
late final Stopwatch ELAPSED_SINCE_UPDATE;
List<BeerList> BEER_SALES = <BeerList>[];
int REFRESH_THRESHOLD = 14400000;
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

  ELAPSED_SINCE_UPDATE = Stopwatch();

  bot.eventsWs.onReady.listen((e) {
    print('Agent Hops is ready!');
  });

  Timer.periodic(Duration(hours: 6), (timer) => updateSubscribers());

  Timer.periodic(Duration(minutes: 12), (timer) => checkUntappd());
}

void checkUntappd() async {
  var box = await Hive.box(HiveConstants.untappdBox);

  var listOfUsers =
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
        embedBuilder.addField(
            field: EmbedFieldBuilder('Comment', latestCheckinUntappd.comment));
        embedBuilder.addField(
            field: EmbedFieldBuilder('Rating',
                _buildRatingEmoji(int.parse(latestCheckinUntappd.rating))));
        if (latestCheckinUntappd.photoAddress != null) {
          embedBuilder.imageUrl = latestCheckinUntappd.photoAddress;
        }

        // Get channel used for untappd updates, previously set by discord admin.
        var updateChannel = await bot
            .fetchChannel(Snowflake(updateChannelId))
            .then((value) => (value as ITextChannel));

        // Send update message
        await updateChannel.sendMessage(MessageBuilder.embed(embedBuilder));

        // Sleep 5 seconds per user to avoid suspicious requests to untappd server
        sleep(Duration(seconds: 5));
      }
    } catch (e) {
      print(e.toString());
    }
  });
}

String _buildRatingEmoji(int rating) {
  var ratingString = '';
  for (var i = 0; i < rating; i++) {
    ratingString += ':beer: ';
  }
  return ratingString;
}

Future<void> updateSubscribers() async {
  await requestBeer();

  var myFile = File('sub.dat');
  var shouldInform = false;
  var beers = <Beer>[];
  var saleDate;

  if (!await myFile.exists()) return;

  for (var sale in BEER_SALES) {
    saleDate = DateTime.parse(sale.saleDate);
    var currentDate =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (saleDate.difference(currentDate).inDays == 1) {
      //Inform subscribing users about upcoming sale...
      shouldInform = true;
      print('Sale is going down!');
      beers = sale.beerList;
      break;
    }
    //No sale is closer than 1 day -> do nothing...
  }

  if (shouldInform) {
    for (var dmchannel in await getSubChannels(bot)) {
      var beersStr = '';
      beers.forEach((element) {
        beersStr += '- ' + element.name + '\n';
      });

      var updateMessage = MessageBuilder()
        ..append(':beers: Hey!')
        ..appendNewLine()
        ..append('There is a fresh beer release tomorrow, ')
        ..appendBold(DateFormat('yyyy-MM-dd').format(saleDate))
        ..append('. Bolaget opens 10:00')
        ..appendNewLine()
        ..append('There are ')
        ..appendBold(beers.length.toString())
        ..append(' new beers tomorrow.')
        ..appendNewLine()
        ..append('For more info, visit https://systembevakningsagenten.se/')
        ..appendNewLine()
        ..appendNewLine()
        ..append(beersStr);

      //To avoid hitting maximum characters for a message, limit output to 2000.
      if (updateMessage.toString().length > 2000) {
        updateMessage.content =
            updateMessage.content.substring(0, 1992) + '...\n\n';
      }
      await dmchannel.sendMessage(updateMessage);
    }
  } else {
    print('No sale, boring...');
  }
}

Future requestBeer() async {
  //Only update list if older than 4 hours or empty
  if (ELAPSED_SINCE_UPDATE.elapsedMilliseconds > REFRESH_THRESHOLD ||
      BEER_SALES.isEmpty) {
    ELAPSED_SINCE_UPDATE.stop();
    print('Updating beer releases and beers...');
    final list = await fetchBeerList();
    BEER_SALES.clear();
    for (var item in list['release']) {
      BEER_SALES.add(BeerList.fromJson(item));
    }
    ELAPSED_SINCE_UPDATE.reset();
    ELAPSED_SINCE_UPDATE.start();
  } else {
    print('No update needed, requires update in ' +
        (((REFRESH_THRESHOLD - ELAPSED_SINCE_UPDATE.elapsedMilliseconds) /
                    1000) ~/
                60)
            .toString() +
        ' minutes.');
  }
}

Future<Map<String, dynamic>> fetchBeerList() async {
  final response = await http.get(Uri.parse(
      'https://systembevakningsagenten.se/api/json/2.0/newProducts.json'));

  if (response.statusCode == 200) {
    Map<String, dynamic> res = json.decode(response.body);
    return res;
  } else {
    throw Exception('Error fetching beer information');
  }
}
