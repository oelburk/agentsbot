import 'dart:io';

import 'beer_bot.dart';

String BOT_TOKEN = Platform.environment['DISCORD_TOKEN'] ?? '';

void main(List<String> arguments) async {
  // Initialize the bot
  BeerBot().init(BOT_TOKEN);
}
