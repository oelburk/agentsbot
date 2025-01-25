import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

abstract class BotModule {
  /// Initializes the module
  void init(NyxxGateway bot);

  /// Returns the list of commands for the module
  List<ChatCommand> get commands;

  /// Returns the help message for the module
  MessageBuilder get helpMessage;
}
