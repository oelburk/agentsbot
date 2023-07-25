import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

abstract class BotModule {
  void init(INyxxWebsocket bot);
  List<SlashCommandBuilder> get commands;
  MessageBuilder get helpMessage;
}
