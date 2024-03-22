import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'modules/untappd/untapped_module.dart';

class Commands {
  static List<SlashCommandBuilder> getCommands() => [
        SlashCommandBuilder(
          'help',
          'List commands available',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _helpCommand(event);
          }),
        ...UntappdModule().commands,
      ];

  static Future<void> _helpCommand(ISlashCommandInteractionEvent ctx) async {
    var helpMessage = MessageBuilder()
      ..append(ctx.interaction.userAuthor!.mention)
      ..appendNewLine()
      ..append(_mainHelpMessage)
      ..appendNewLine()
      ..appendNewLine()
      ..append(UntappdModule().helpMessage);

    await ctx.respond(helpMessage);
  }

  static MessageBuilder get _mainHelpMessage => MessageBuilder()
    ..append('Did anyone say beer? This is what I can do for you:')
    ..appendNewLine()
    ..appendNewLine()
    ..appendBold('/help')
    ..appendNewLine()
    ..append('Shows you this help message.');
}
