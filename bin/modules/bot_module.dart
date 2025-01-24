import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

abstract class BotModule {
  /// Initializes the module
  void init(INyxxWebsocket bot);

  /// Returns the list of commands for the module
  List<SlashCommandBuilder> get commands;

  /// Returns the help message for the module
  MessageBuilder get helpMessage;
}
