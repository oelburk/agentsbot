import 'dart:async';
import 'package:nyxx/nyxx.dart';
import 'package:http/http.dart' as http;
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'dart:convert';
import 'dart:io';
import 'beer.dart';
import 'beerlist.dart';
import 'commands.dart';
import 'utils.dart';
import 'package:intl/intl.dart';

String BOT_TOKEN = Platform.environment['DISCORD_TOKEN'];
Stopwatch ELAPSED_SINCE_UPDATE;
List<BeerList> BEER_SALES = <BeerList>[];
int REFRESH_THRESHOLD = 14400000;
INyxxWebsocket bot;

void main(List<String> arguments) {
  bot =
      NyxxFactory.createNyxxWebsocket(BOT_TOKEN, GatewayIntents.allUnprivileged)
        ..registerPlugin(Logging())
        ..registerPlugin(CliIntegration())
        ..registerPlugin(IgnoreExceptions())
        ..connect();

  final interactions = IInteractions.create(WebsocketInteractionBackend(bot));

  // Register slash commands
  interactions.registerSlashCommand(Commands.oel);
  interactions.registerSlashCommand(Commands.help);
  interactions.registerSlashCommand(Commands.register);
  interactions.registerSlashCommand(Commands.stop);
  interactions.registerSlashCommand(Commands.release);
  interactions.syncOnReady();

  ELAPSED_SINCE_UPDATE = Stopwatch();

  bot.eventsWs.onReady.listen((e) {
    print('Agent S is ready!');
  });

  Timer.periodic(Duration(hours: 6), updateTimeout);
}

void updateTimeout(Timer timer) {
  updateSubscribers();
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
        ..append(':beers: Hej!')
        ..appendNewLine()
        ..append('Kom ihåg ölsläppet imorgon, ')
        ..appendBold(DateFormat('yyyy-MM-dd').format(saleDate))
        ..append('. Bolaget öppnar 10:00')
        ..appendNewLine()
        ..append('Det finns ')
        ..appendBold(beers.length.toString())
        ..append(' nya öl imorgon.')
        ..appendNewLine()
        ..append('Mer info hittar du på https://systembevakningsagenten.se/')
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
