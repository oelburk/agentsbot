// Create a module which extends BotModule and implement the abstract methods:
import 'dart:async';
import 'dart:math';

import 'package:cron/cron.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../bot_module.dart';
import 'beerizer_service.dart';

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

  void _startScraping() async {
    await BeerizerService().scrapeBeer(DateTime.now());
    _cron = Cron();
    _cron.schedule(Schedule.parse('0 8 * * *'), () {
      Timer(Duration(minutes: Random().nextInt(90)), () async {
        await BeerizerService().scrapeBeer(DateTime.now());
        if (_channel != null) {
          _postLatestBeersToChannel(_channel!);
        }
      });
    });
  }

  void _stopScraping() {
    _cron.close();
  }

  void _postLatestBeersToChannel(TextChannel channel) async {
    var latestBeerList = BeerizerService().beers;
    if (latestBeerList.isEmpty) {
      return;
    }
    var beerString = 'Woho! New beers are releasing today! :beers:\n\n';
    for (var beer in latestBeerList) {
      beerString += '**${beer.name}**\n'
          '${beer.brewery}\n'
          ':untappd: ${beer.untappdRating} :star:\n'
          '\n\n';
    }
    await channel.sendMessage(MessageBuilder(content: beerString));
  }

  @override
  List<ChatCommand> get commands => [
        _buildCommand(
          'start',
          'Start checking for beer.',
          (ChatContext context) async {
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
          (ChatContext context) async {
            _stopScraping();
            await context.respond(
              MessageBuilder(content: 'Stopped checking for beer releases.'),
            );
          },
        ),
        _buildCommand(
          'check',
          'Check the latest beer.',
          (ChatContext context) async {
            var latestBeerList = BeerizerService().beers;
            if (latestBeerList.isEmpty) {
              await context.respond(MessageBuilder(
                  content:
                      'Sadly no beers are releasing for today, I\'ll keep checking.'));
              return;
            }
            _postLatestBeersToChannel(context.channel);
          },
        ),
      ];

  @override
  MessageBuilder get helpMessage {
    // Return the help message for the module
    return MessageBuilder(
        content: '**Beerizer module**\n\n'
            'Commands:\n\n'
            'start - Start checking for beer releases\n'
            'stop - Stop checking for beer releases\n'
            'check - Check the latest beer releases');
  }
}
