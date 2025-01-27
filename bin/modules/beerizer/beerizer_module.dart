// Create a module which extends BotModule and implement the abstract methods:
import 'dart:async';
import 'dart:math';

import 'package:cron/cron.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../bot_module.dart';
import 'beerizer_service.dart';
import 'models/beerizer_beer.dart';

part 'commands.dart';

class BeerizerModule extends BotModule {
  // it should be a singleton
  static final BeerizerModule _singleton = BeerizerModule._internal();
  factory BeerizerModule() {
    return _singleton;
  }
  BeerizerModule._internal();

  bool get isInitialized => _isInitialized;

  bool _isInitialized = false;

  late Cron _cron;

  TextChannel? _channel;

  @override
  void init(NyxxGateway bot) {
    _isInitialized = true;
  }

  void _scrapeDate(String date, InteractionChatContext context) async {
    final beers = await BeerizerService().quickScrape(date);
    if (beers.isEmpty) {}
    _postBeerListToChannel(context, null, beers, DateTime.parse(date));
  }

  void _startScraping() async {
    await BeerizerService().scrapeBeer(DateTime.now());
    _cron = Cron();
    _cron.schedule(Schedule.parse('0 8 * * *'), () {
      Timer(Duration(minutes: Random().nextInt(90)), () async {
        await BeerizerService().scrapeBeer(DateTime.now());
        if (_channel != null) {
          _postLatestBeersToChannel(null, _channel!);
        }
      });
    });
  }

  void _stopScraping() {
    _cron.close();
  }

  void _postBeerListToChannel(InteractionChatContext? context,
      TextChannel? channel, List<BeerizerBeer> beers, DateTime date) async {
    var beerString =
        'Beers releasing ${date.toIso8601String().substring(0, 10)} :beers:\n\n';
    if (DateTime.now().isAtSameMomentAs(date)) {
      beerString = 'Woho! New beers are releasing today! :beers:\n\n';
    }
    for (var beer in beers) {
      beerString += '**${beer.name}**\n'
          '${beer.brewery}\n'
          '<:untappd:1333124979386220604> ${beer.untappdRating} :star:\n'
          '*${beer.style}*\n'
          '\n';
    }
    if (channel != null) {
      await channel.sendMessage(MessageBuilder(content: beerString));
    } else {
      await context!.respond(MessageBuilder(content: beerString));
    }
  }

  void _postLatestBeersToChannel(
      InteractionChatContext? context, TextChannel? channel) async {
    var latestBeerList = BeerizerService().beers;
    if (latestBeerList.isEmpty) {
      return;
    }
    _postBeerListToChannel(context, channel, latestBeerList, DateTime.now());
  }

  @override
  List<ChatCommand> get commands => [
        _buildCommand(
          'start',
          'Start checking for beer.',
          (InteractionChatContext context) async {
            _startScraping();
            await context.respond(MessageBuilder(
                content:
                    'Started checking for beer releases. Updates will be posted here daily between 08:00-9:30.'));

            var latestBeerList = BeerizerService().beers;
            if (latestBeerList.isEmpty) {
              await context.respond(MessageBuilder(
                  content:
                      'Sadly no beers are releasing for today, I\'ll keep checking.'));
              return;
            }
            _channel = context.channel;
          },
        ),
        _buildCommand(
          'stop',
          'Stop checking for beer.',
          (InteractionChatContext context) async {
            _stopScraping();
            await context.respond(
              MessageBuilder(content: 'Stopped checking for beer releases.'),
            );
          },
        ),
        _buildCommand(
          'check',
          'Check the latest beer.',
          (InteractionChatContext context) async {
            var latestBeerList = BeerizerService().beers;
            if (latestBeerList.isEmpty) {
              await context.respond(MessageBuilder(
                  content:
                      'Sadly no beers are releasing for today, I\'ll keep checking.'));
              return;
            }
            _postLatestBeersToChannel(context, null);
          },
        ),
        _buildCommand(
            'check-date', 'Check if there are any beer releases on given date.',
            (InteractionChatContext context,
                [@Name('date')
                @Description('Date to check, provide as YYYY-MM-dd')
                String? date]) async {
          if (date == null) {
            await context.respond(MessageBuilder(
                content: 'Please provide a date in the format YYYY-MM-dd'));
            return;
          }
          _scrapeDate(date, context);
          await context.acknowledge();
        }),
      ];

  @override
  String get helpMessage {
    // Return the help message for the module
    return '**Beerizer module**\n'
        'This module allows you to automatically check the latest beer releases from Beerizer.\n\n'
        'Commands:\n'
        '`/start` - Begin tracking beer releases and automatically share updates in the channel where the command was used.\n'
        '`/stop` - Stop the automatic tracking of beer releases.\n'
        '`/check` - Check the latest beer releases\n'
        '`/quick` - Check if there are any beer releases on given date.';
  }
}
