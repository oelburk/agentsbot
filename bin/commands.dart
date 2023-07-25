import 'package:hive/hive.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'constants/hive_constants.dart';
import 'modules/beer_agent/beer_agent_module.dart';
import 'utils.dart';

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
        ...BeerAgentModule().commands,
        SlashCommandBuilder(
          'untappd',
          'Let me know your untappd username so I can post automatic updates from your untappd account.',
          [
            CommandOptionBuilder(CommandOptionType.string, 'username',
                'e.g. cornholio (kontot måste minst ha 1 incheckning)',
                required: true),
          ],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _untappdCommand(event);
          }),
        SlashCommandBuilder(
          'setup',
          'Setup the bot to post untappd updates to the current channel.',
          [],
          requiredPermissions: PermissionsConstants.administrator,
        )..registerHandler((event) async {
            await event.acknowledge();
            await _setupUntappdServiceCommand(event);
          }),
      ];

  static Future<void> _helpCommand(ISlashCommandInteractionEvent ctx) async {
    var helpMessage = MessageBuilder()
      ..append(ctx.interaction.userAuthor!.mention)
      ..appendNewLine()
      ..append('Did anyone say beer? This is what I can do for you:')
      ..appendNewLine()
      ..appendNewLine()
      ..append(BeerAgentModule().helpMessage)
      ..appendNewLine()
      ..appendNewLine()
      ..appendBold('/help')
      ..appendNewLine()
      ..append('Shows you this help message.')
      ..appendNewLine()
      ..appendNewLine()
      ..appendBold('/untappd untappd_username')
      ..appendNewLine()
      ..append(
          'Let me know your untappd username so I can post automatic updates from your untappd account. e.g ')
      ..appendItalics('/untappd cornholio')
      ..appendNewLine()
      ..appendNewLine()
      ..appendBold('/setup')
      ..appendNewLine()
      ..append(
          'Setup the bot to post untappd updates to the current channel. Only admins can issue this command. Also, this is needed before any untappd updates can occur.');

    await ctx.respond(helpMessage);
  }

  static Future<void> _untappdCommand(ISlashCommandInteractionEvent ctx) async {
    var box = Hive.box(HiveConstants.untappdBox);
    if (box.get(HiveConstants.untappdUpdateChannelId) == null) {
      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' Whops, ask your admin to run setup first! :beers:'));
      return;
    }
    if (ctx.args.length != 1) {
      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' Are you drunk buddy? Your username is missing.'));
    }
    var discordUser = ctx.interaction.userAuthor!.id;
    var untappdUsername = ctx.args.first.value;

    if (!await regUntappdUser(discordUser, untappdUsername)) {
      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' Whops, something went sideways! :beers:'));
    }
    await ctx.respond(MessageBuilder.content(
        ctx.interaction.userAuthor!.mention +
            ' From now on I will post your updates from untappd! :beers:'));
  }

  static Future<void> _setupUntappdServiceCommand(
      ISlashCommandInteractionEvent ctx) async {
    if (ctx.interaction.memberAuthorPermissions?.administrator ?? false) {
      var beerUpdateChannel = await ctx.interaction.channel.getOrDownload();

      var box = Hive.box(HiveConstants.untappdBox);
      await box.put(HiveConstants.untappdUpdateChannelId,
          beerUpdateChannel.id.toString());

      await beerUpdateChannel.sendMessage(MessageBuilder.content(
          ' I will post untappd updates to this channel! Ask your users to register their username with /untappd followed by their untappd username.'));
    }
  }
}
