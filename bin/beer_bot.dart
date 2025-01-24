import 'dart:io';

import 'package:nyxx/nyxx.dart';

import 'commands.dart';
import 'modules/untappd/untapped_module.dart';

String BOT_TOKEN = Platform.environment['DISCORD_TOKEN'] ?? '';

// late final INyxxWebsocket bot;

void main(List<String> arguments) async {
  final bot =
      await Nyxx.connectGateway('<TOKEN>', GatewayIntents.allUnprivileged);

  Commands.getCommands().forEach((command) {
    //interactions.registerSlashCommand(command);
  });

  //interactions.syncOnReady();

  bot.onReady.listen((ReadyEvent e) {
    print('Agent Hops is ready!');
  });

  // Initialize bot modules
  UntappdModule().init(bot);
}
