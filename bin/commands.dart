import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'modules/untappd/untapped_module.dart';

class Commands {
  static List<ChatCommand> getCommands() => [
        ChatCommand(
          'help',
          'List commands available',
          (ChatContext ctx) async {
            await _helpCommand(ctx);
          },
        ),
        ...UntappdModule().commands,
      ];

  static Future<void> _helpCommand(ChatContext ctx) async {
    var helpMessage = MessageBuilder(
        content: '$_mainHelpMessage\n\n'
            '${UntappdModule().helpMessage}');

    await ctx.respond(helpMessage);
  }

  static MessageBuilder get _mainHelpMessage => MessageBuilder(
        content: 'Did anyone say beer? This is what I can do for you: \n\n'
            '/help\n'
            'Shows you this help message.',
      );
}
