// Create a module which extends BotModule and implement the abstract methods:
import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../bot_module.dart';
import 'beerizer_service.dart';

class BeerizerModule extends BotModule {
  // it should be a singleton
  static final BeerizerModule _singleton = BeerizerModule._internal();
  factory BeerizerModule() {
    return _singleton;
  }
  BeerizerModule._internal();

  bool get isInitialized => _isInitialized;

  bool _isInitialized = false;

  @override
  void init(NyxxGateway bot) {
    Timer.periodic(Duration(hours: 12), (timer) {
      _scrapeBeer(DateTime.now());
    });

    _isInitialized = true;
  }

  void _scrapeBeer(DateTime date) {
    BeerizerService().scrapeBeer(date);
  }

  @override
  List<Command> get commands {
    // Return the list of commands for the module
    return [];
  }

  @override
  MessageBuilder get helpMessage {
    // Return the help message for the module
    return MessageBuilder();
  }
}
