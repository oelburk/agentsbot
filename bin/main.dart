import 'dart:io';

import 'package:sentry/sentry.dart';

import 'beer_bot.dart';

String BOT_TOKEN = Platform.environment['DISCORD_TOKEN'] ?? '';
String SENTRY_DSN = Platform.environment['SENTRY_DSN'] ?? '';

Future<void> main(List<String> arguments) async {
  await Sentry.init(
    (options) {
      options.dsn = SENTRY_DSN;
    },
    appRunner: () => BeerBot().init(BOT_TOKEN),
  );
}
