import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'commands.dart';
import 'modules/beer_agent/beer_agent_module.dart';
import 'modules/untappd/untapped_module.dart';

String BOT_TOKEN = Platform.environment['DISCORD_TOKEN'] ?? '';

late final INyxxWebsocket bot;

void main(List<String> arguments) {
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
  UntappdModule().init(bot);
}
