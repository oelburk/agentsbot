import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'beer_bot.dart';
import 'constants/hive_constants.dart';
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
        SlashCommandBuilder(
          'oel',
          'Show the latest beer releases.',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _oelCommand(event);
          }),
        SlashCommandBuilder(
          'subscribe',
          'Subscribe to beer release reminders.',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _regCommand(event);
          }),
        SlashCommandBuilder(
          'stop',
          'Unsubscribe to beer release reminders.',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _stopCommand(event);
          }),
        SlashCommandBuilder(
          'release',
          'Detailed info about a specific beer release e.g. /release 2022-07-15',
          [
            CommandOptionBuilder(
                CommandOptionType.string, 'datum', 'YYYY-MM-dd',
                required: true),
          ],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _releaseCommand(event);
          }),
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
      ..appendBold('/oel')
      ..appendNewLine()
      ..append('Lists all known beer releases.')
      ..appendNewLine()
      ..appendNewLine()
      ..appendBold('/subscribe')
      ..appendNewLine()
      ..append(
          'Subscribe to automatic beer release reminders. Reminders will be posted 3 times during the day before release.')
      ..appendNewLine()
      ..appendNewLine()
      ..appendBold('/release YYYY-MM-dd')
      ..appendNewLine()
      ..append(
          'Posts the beer release for given date in the format YYYY-MM-dd. e.g ')
      ..appendItalics('/release 1970-01-30')
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

  static Future<void> _regCommand(ISlashCommandInteractionEvent ctx) async {
    var dmChan = await ctx.interaction.userAuthor!.dmChannel;

    if (await isUserSubbed(bot, dmChan.id)) {
      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' You are already subscribed! :beers:'));
    } else {
      await subUser(dmChan.id);

      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' You are now subscribed to beer release reminders! :beers:'));
    }
  }

  static Future<void> _stopCommand(ISlashCommandInteractionEvent ctx) async {
    var dmChan = await ctx.interaction.userAuthor!.dmChannel;

    if (await isUserSubbed(bot, dmChan.id)) {
      await unsubUser(bot, dmChan.id);

      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' Sad, no more beer for you! :beers:'));
    } else {
      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' You are not subscribed! :beers:'));
    }
  }

  static Future<void> _oelCommand(ISlashCommandInteractionEvent ctx) async {
    //Updates current beer list if needed
    await requestBeer();

    //Build message
    var oelMessage = MessageBuilder()
      ..append(ctx.interaction.userAuthor!.mention)
      ..appendNewLine()
      ..append('There are ')
      ..appendBold(BEER_SALES.length.toString())
      ..append(' current releases!')
      ..appendNewLine()
      ..appendNewLine();

    for (var beerSale in BEER_SALES) {
      var saleDate = beerSale.saleDate;
      var saleSize = beerSale.beerList.length;
      beerSale.beerList.shuffle();

      if (saleSize >= 3) {
        oelMessage
          ..append(':beer: ')
          ..appendBold(saleDate)
          ..appendNewLine()
          ..append('This release has ')
          ..appendBold(saleSize)
          ..append(' new beers!')
          ..appendNewLine()
          ..appendNewLine()
          ..append('Some of them are:')
          ..appendNewLine()
          ..append('- ')
          ..appendBold(beerSale.beerList[0].name)
          ..appendNewLine()
          ..append('- ')
          ..appendBold(beerSale.beerList[1].name)
          ..appendNewLine()
          ..append('- ')
          ..appendBold(beerSale.beerList[2].name)
          ..appendNewLine()
          ..appendNewLine();
      } else if (saleSize == 2) {
        oelMessage
          ..append(':beer: ')
          ..appendBold(saleDate)
          ..appendNewLine()
          ..append('This release has ')
          ..appendBold(saleSize)
          ..append(' new beers!')
          ..appendNewLine()
          ..appendNewLine()
          ..append('Some of them are:')
          ..appendNewLine()
          ..append('- ')
          ..appendBold(beerSale.beerList[0].name)
          ..appendNewLine()
          ..append('- ')
          ..appendBold(beerSale.beerList[1].name)
          ..appendNewLine()
          ..appendNewLine();
      } else if (saleSize == 1) {
        oelMessage
          ..append(':beer: ')
          ..appendBold(saleDate)
          ..appendNewLine()
          ..append('This release has ')
          ..appendBold(saleSize)
          ..append(' new beer!')
          ..appendNewLine()
          ..appendNewLine()
          ..append('- ')
          ..appendBold(beerSale.beerList[0].name)
          ..appendNewLine()
          ..appendNewLine();
      }
    }

    oelMessage
      ..append('---')
      ..appendNewLine()
      ..append('For more information: https://systembevakningsagenten.se/')
      ..appendNewLine()
      ..appendNewLine()
      ..append('Cheers! :beers:');

    //Send message
    await ctx.respond(oelMessage);
  }

  static Future<void> _releaseCommand(ISlashCommandInteractionEvent ctx) async {
    var input = ctx.args;
    if (input.length == 1) {
      var parsedDate = DateTime.tryParse(input[0].value);

      if (parsedDate != null) {
        await requestBeer();
        for (var sale in BEER_SALES) {
          var saleDate = DateTime.parse(sale.saleDate);
          if (parsedDate == saleDate) {
            //Compile beer list to string and sort by name.
            var beerStr = '';
            sale.beerList.sort((a, b) => a.name.compareTo(b.name));
            sale.beerList.forEach((element) {
              beerStr += '- ' + element.name + '\n';
            });

            //Bulild reply
            var slappMessage = MessageBuilder()
              ..append(ctx.interaction.userAuthor!.mention)
              ..appendNewLine()
              ..append(' :beers: ')
              ..appendBold(input[0].value)
              ..appendNewLine()
              ..append('Innehåller ')
              ..appendBold(sale.beerList.length)
              ..append(' nya öl:')
              ..appendNewLine()
              ..appendNewLine()
              ..append(beerStr);

            if (slappMessage.content.length > 2000) {
              slappMessage.content = slappMessage.content.substring(
                      0,
                      slappMessage.content
                              .substring(0, 1999)
                              .lastIndexOf('- ') -
                          1) +
                  '\n...';
            }
            await ctx.respond(slappMessage);
            return;
          }
        }
        await ctx.respond(MessageBuilder.content(
            ctx.interaction.userAuthor!.mention +
                ' Fanns inget ölsläpp för ' +
                DateFormat('yyyy-MM-dd').format(parsedDate)));
        return;
      }
    }

    await ctx.respond(MessageBuilder.content(
        ctx.interaction.userAuthor!.mention +
            ' Are you drunk buddy? I only accept ***/release YYYY-MM-dd***'));
  }

  static Future<void> _untappdCommand(ISlashCommandInteractionEvent ctx) async {
    var box = await Hive.box(HiveConstants.untappdBox);
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
    var discordUser = await ctx.interaction.userAuthor!.id;
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

      var box = await Hive.box(HiveConstants.untappdBox);
      await box.put(HiveConstants.untappdUpdateChannelId,
          beerUpdateChannel.id.toString());

      await beerUpdateChannel.sendMessage(MessageBuilder.content(
          ' I will post untappd updates to this channel! Ask your users to register their username with /untappd followed by their untappd username.'));
    }
  }
}
