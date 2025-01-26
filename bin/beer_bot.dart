import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'commands.dart';
import 'modules/beerizer/beerizer_module.dart';
import 'modules/untappd/untapped_module.dart';

class BeerBot {
  static final BeerBot _singleton = BeerBot._internal();

  factory BeerBot() {
    return _singleton;
  }

  BeerBot._internal();

  void init(String apiToken) async {
    final commands = CommandsPlugin(prefix: mentionOr((_) => '!'));

    Commands.getCommands().forEach((command) {
      commands.addCommand(command);
    });

    final bot =
        await Nyxx.connectGateway(apiToken, GatewayIntents.allUnprivileged,
            options: GatewayClientOptions(
              plugins: [commands],
            ));

    bot.onReady.listen((ReadyEvent e) {
      print('Agent Hops is ready!');
    });

    // Initialize bot modules
    UntappdModule().init(bot, shouldPersistData: false);
    BeerizerModule().init(bot);
  }
}
