import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../bot_module.dart';
import 'models/beer.dart';

part 'commands.dart';

class BeerAgentModule extends BotModule {
  late final Stopwatch _elapsedSinceUpdate;
  final List<BeerList> _beerSales = <BeerList>[];
  final int _refreshThreshold = 14400000;

  bool _isInitialized = false;

  late INyxxWebsocket _bot;

  static final BeerAgentModule _singleton = BeerAgentModule._internal();
  factory BeerAgentModule() {
    return _singleton;
  }
  BeerAgentModule._internal();

  /// Updates the list of beer sales and informs subscribers about upcoming sales.
  Future<void> _updateSubscribers() async {
    await _updateBeerSales();

    var myFile = File('sub.dat');
    var shouldInform = false;
    var beers = <Beer>[];
    var saleDate;

    if (!await myFile.exists()) return;

    for (var sale in _beerSales) {
      saleDate = DateTime.parse(sale.saleDate);
      var currentDate = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
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
      for (var dmchannel in await _getSubChannels(_bot)) {
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

  /// Fetches a list of all beer sales from online API.
  Future<Map<String, dynamic>> _fetchBeerList() async {
    final response = await http.get(Uri.parse(
        'https://systembevakningsagenten.se/api/json/2.0/newProducts.json'));

    if (response.statusCode == 200) {
      Map<String, dynamic> res = json.decode(response.body);
      return res;
    } else {
      throw Exception('Error fetching beer information');
    }
  }

  /// Returns a list of all channels (users) that are subscribed to beer updates.
  Future<List<IDMChannel>> _getSubChannels(INyxxWebsocket bot) async {
    var myFile = File('sub.dat');
    var channelList = <IDMChannel>[];

    var fileExists = await myFile.exists();
    if (!fileExists) await myFile.create();

    await myFile.readAsLines().then((value) async {
      for (var line in value) {
        var chan = await bot
            .fetchChannel(Snowflake(line))
            .then((value) => (value as IDMChannel));

        channelList.add(chan);
      }
    });
    return channelList;
  }

  /// Updates the list of beer sales.
  Future _updateBeerSales() async {
    if (!_isInitialized) {
      print('Beer agent service not initialized!');
      throw Exception('Beer agent service not initialized!');
    }

    //Only update list if older than 4 hours or empty
    if (_elapsedSinceUpdate.elapsedMilliseconds > _refreshThreshold ||
        _beerSales.isEmpty) {
      _elapsedSinceUpdate.stop();
      print('Updating beer releases and beers...');
      final list = await _fetchBeerList();
      _beerSales.clear();
      for (var item in list['release']) {
        _beerSales.add(BeerList.fromJson(item));
      }
      _elapsedSinceUpdate.reset();
      _elapsedSinceUpdate.start();
    } else {
      print('No update needed, requires update in ' +
          (((_refreshThreshold - _elapsedSinceUpdate.elapsedMilliseconds) /
                      1000) ~/
                  60)
              .toString() +
          ' minutes.');
    }
  }

  /// Checks if a user is subscribed to beer updates.
  Future<bool> _isUserSubbed(Snowflake userSnowflake) async {
    if (!_isInitialized) {
      print('Beer agent service not initialized!');
      throw Exception('Beer agent service not initialized!');
    }

    var subs = await _getSubChannels(_bot);

    if (subs.asSnowflakes().contains(userSnowflake)) {
      return true;
    } else {
      return false;
    }
  }

  /// Unsubscribes a user from beer updates.
  Future<void> _unsubUser(Snowflake userSnowflake) async {
    if (!_isInitialized) {
      print('Beer agent service not initialized!');
      throw Exception('Beer agent service not initialized!');
    }

    var currentSubs = await _getSubChannels(_bot);

    currentSubs.removeWhere((element) => element.id == userSnowflake);
    var tempFile = File('temp.dat');
    var subFile = File('sub.dat');

    await tempFile.create();

    currentSubs.forEach((element) async {
      await tempFile.writeAsString(element.id.toString(),
          mode: FileMode.append);
    });

    await subFile.writeAsBytes(await tempFile.readAsBytes());

    await tempFile.delete();
  }

  /// Subscribes a user to beer updates.
  Future<void> _subUser(Snowflake userSnowflake) async {
    if (!_isInitialized) {
      print('Beer agent service not initialized!');
      throw Exception('Beer agent service not initialized!');
    }
    var myFile = File('sub.dat');
    await myFile.writeAsString(userSnowflake.toString(), mode: FileMode.append);
  }

  /// Initializes the beer agent service.
  @override
  void init(INyxxWebsocket bot) {
    _bot = bot;
    _elapsedSinceUpdate = Stopwatch();
    _elapsedSinceUpdate.start();

    Timer.periodic(Duration(minutes: 5), (timer) => _updateSubscribers());

    _isInitialized = true;
  }

  /// Returns a list of all slash commands for the beer agent module.
  @override
  List<SlashCommandBuilder> get commands => [
        SlashCommandBuilder(
          'oel',
          'Show the latest beer releases.',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _oelCommand(event);
          }),
        SlashCommandBuilder(
          'subscribe',
          'Subscribe to beer release reminders.',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _regCommand(event);
          }),
        SlashCommandBuilder(
          'stop',
          'Unsubscribe to beer release reminders.',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _stopCommand(event);
          }),
        SlashCommandBuilder(
          'release',
          'Detailed info about a specific beer release e.g. /release 2022-07-15',
          [
            CommandOptionBuilder(
                CommandOptionType.string, 'datum', 'YYYY-MM-dd',
                required: true),
          ],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _releaseCommand(event);
          }),
      ];

  /// Returns a help message for the beer agent module.
  @override
  MessageBuilder get helpMessage => MessageBuilder()
    ..appendBold('/oel')
    ..appendNewLine()
    ..append('Lists all known beer releases.')
    ..appendNewLine()
    ..appendNewLine()
    ..appendBold('/subscribe')
    ..appendNewLine()
    ..append(
        'Subscribe to automatic beer release reminders. Reminders will be posted 3 times during the day before release.')
    ..appendNewLine()
    ..appendNewLine()
    ..appendBold('/release YYYY-MM-dd')
    ..appendNewLine()
    ..append(
        'Posts the beer release for given date in the format YYYY-MM-dd. e.g ')
    ..appendItalics('/release 1970-01-30');

  /// Returns a list of all current beer sales.
  List<BeerList> get beerSales => _beerSales;
}
