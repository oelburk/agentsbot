import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'commands.dart';
import 'modules/untappd/untapped_module.dart';

String BOT_TOKEN = Platform.environment['DISCORD_TOKEN'] ?? '';

// late final INyxxWebsocket bot;

void main(List<String> arguments) async {
  final commands = CommandsPlugin(prefix: mentionOr((_) => '!'));
  Commands.getCommands().forEach((command) {
    commands.addCommand(command);
  });

  final bot =
      await Nyxx.connectGateway('<TOKEN>', GatewayIntents.allUnprivileged,
          options: GatewayClientOptions(
            plugins: [commands],
          ));

  bot.onReady.listen((ReadyEvent e) {
    print('Agent Hops is ready!');
  });

  // Initialize bot modules
  UntappdModule().init(bot);
}
