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
          'oelhelp',
          'Information om boten',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _helpCommand(event);
          }),
        SlashCommandBuilder(
          'oel',
          'Visa de senaste ölreleaserna',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _oelCommand(event);
          }),
        SlashCommandBuilder(
          'regga',
          'Regga dig för automatiska påminnelser om ölsläpp',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _regCommand(event);
          }),
        SlashCommandBuilder(
          'stopp',
          'Sluta få påminnelser om ölsläpp',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _stopCommand(event);
          }),
        SlashCommandBuilder(
          'release',
          'Hämta info om specifik release. tex. /release 2022-07-15',
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
          'Låt mig dela dina incheckningar från untappd!',
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
          'Registrera untappd-uppdateringar till den här kanalen (Admin)',
          [],
        )..registerHandler((event) async {
            await event.acknowledge();
            await _setupUntappdServiceCommand(event);
          }),
      ];

  static Future<void> _helpCommand(ISlashCommandInteractionEvent ctx) async {
    var helpMessage = MessageBuilder()
      ..append(ctx.interaction.userAuthor!.mention)
      ..appendNewLine()
      ..append('Kul att du är sugen öl, det här kan jag göra för dig:')
      ..appendNewLine()
      ..appendNewLine()
      ..appendBold('!öl')
      ..appendNewLine()
      ..append('Listar alla akutella ölsläpp.')
      ..appendNewLine()
      ..appendNewLine()
      ..appendBold('!reg')
      ..appendNewLine()
      ..append(
          'Regsistrerar dig för påminnelser om ölsläpp. En dag innan varje släpp påminner jag dig om morgondagens släpp.')
      ..appendNewLine()
      ..appendNewLine()
      ..appendBold('!släpp YYYY-MM-dd')
      ..appendNewLine()
      ..append('Visar dig ölen som släpps på givet datum, om det finns. Tex. ')
      ..appendItalics('!släpp 1970-01-30')
      ..appendNewLine()
      ..appendNewLine()
      ..appendBold('!ölhelp')
      ..appendNewLine()
      ..append('Visar dig det här hjälpmeddelandet.');

    await ctx.respond(helpMessage);
  }

  static Future<void> _regCommand(ISlashCommandInteractionEvent ctx) async {
    var dmChan = await ctx.interaction.userAuthor!.dmChannel;

    if (await isUserSubbed(bot, dmChan.id)) {
      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' Du är redan registrerad! :beers:'));
    } else {
      await subUser(dmChan.id);

      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' Nu är du registrerad för öluppdateringar! :beers:'));
    }
  }

  static Future<void> _stopCommand(ISlashCommandInteractionEvent ctx) async {
    var dmChan = await ctx.interaction.userAuthor!.dmChannel;

    if (await isUserSubbed(bot, dmChan.id)) {
      await unsubUser(bot, dmChan.id);

      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' Tråkigt att du inte vill ha mer öl! :beers:'));
    } else {
      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' Du är inte registrerad! :beers:'));
    }
  }

  static Future<void> _oelCommand(ISlashCommandInteractionEvent ctx) async {
    //Updates current beer list if needed
    await requestBeer();

    //Build message
    var oelMessage = MessageBuilder()
      ..append(ctx.interaction.userAuthor!.mention)
      ..appendNewLine()
      ..append('Det finns ')
      ..appendBold(BEER_SALES.length.toString())
      ..append(' aktuella släpp!')
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
          ..append('Innehåller ')
          ..appendBold(saleSize)
          ..append(' nya öl!')
          ..appendNewLine()
          ..appendNewLine()
          ..append('Med bla. dessa öl:')
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
          ..append('Innehåller ')
          ..appendBold(saleSize)
          ..append(' nya öl!')
          ..appendNewLine()
          ..appendNewLine()
          ..append('Med bla. dessa öl:')
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
          ..append('Innehåller ')
          ..appendBold(saleSize)
          ..append(' ny öl!')
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
      ..append('För mer information: https://systembevakningsagenten.se/')
      ..appendNewLine()
      ..appendNewLine()
      ..append('Skål! :beers:');

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
            ' Är du lite full? Jag accepterar bara ***!släpp YYYY-MM-dd***'));
  }

  static Future<void> _untappdCommand(ISlashCommandInteractionEvent ctx) async {
    var box = await Hive.box(HiveConstants.untappdBox);
    if (box.get(HiveConstants.untappdUpdateChannelId) == null) {
      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' Hoppsan, be din admin köra setup först! :beers:'));
      return;
    }
    if (ctx.args.length != 1) {
      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' Är du lite full? Jag saknar ditt untappd username'));
    }
    var discordUser = await ctx.interaction.userAuthor!.id;
    var untappdUsername = ctx.args.first.value;

    if (!await regUntappdUser(discordUser, untappdUsername)) {
      await ctx.respond(MessageBuilder.content(
          ctx.interaction.userAuthor!.mention +
              ' Hoppsan, något gick fel! :beers:'));
    }
    await ctx.respond(MessageBuilder.content(ctx
            .interaction.userAuthor!.mention +
        ' Nu ser jag till att plocka dina incheckingar från untappd! :beers:'));
  }

  static Future<void> _setupUntappdServiceCommand(
      ISlashCommandInteractionEvent ctx) async {
    if (ctx.interaction.memberAuthorPermissions?.administrator ?? false) {
      var beerUpdateChannel = await ctx.interaction.channel.getOrDownload();

      var box = await Hive.box(HiveConstants.untappdBox);
      await box.put(HiveConstants.untappdUpdateChannelId,
          beerUpdateChannel.id.toString());

      await beerUpdateChannel.sendMessage(MessageBuilder.content(
          ' Jag kommer posta uppdateringar från untappd-konton här! Vill du synas, kör /untappd följt med ditt användarnamn på untappd'));
    }
  }
}
