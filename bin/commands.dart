import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'modules/beerizer/beerizer_module.dart';
import 'modules/untappd/untapped_module.dart';

class Commands {
  /// Get all commands available for the bot
  static List<ChatCommand> getCommands() => [
        ChatCommand(
          'help',
          'List commands available',
          (InteractionChatContext ctx) async {
            await _helpCommand(ctx);
          },
          options: CommandOptions(
            autoAcknowledgeInteractions: true,
            type: CommandType.slashOnly,
          ),
        ),
        // Add all commands from the modules here
        ...UntappdModule().commands,
        ...BeerizerModule().commands,
      ];

  static Future<void> _helpCommand(InteractionChatContext ctx) async {
    var helpMessage = MessageBuilder(
        content: '$_mainHelpMessage\n\n'
            '${BeerizerModule().helpMessage}\n\n'
            '${UntappdModule().helpMessage}');
    UntappdModule().helpMessage;

    await ctx.respond(helpMessage);
  }

  static String get _mainHelpMessage =>
      'Did anyone say beer? This is what I can do for you: \n\n'
      '`/help` - '
      'Shows you this help message.';
}
