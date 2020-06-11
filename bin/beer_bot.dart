import 'dart:async';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx.commander/commander.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'beer.dart';
import 'beerlist.dart';
import 'utils.dart';
import 'package:intl/intl.dart';

Pattern CMD_PREFIX = '!';
String BOT_TOKEN = Platform.environment['DISCORD_TOKEN'];
Stopwatch ELAPSED_SINCE_UPDATE;
List<BeerList> BEER_SALES = <BeerList>[];
int REFRESH_THRESHOLD = 14400000;
Nyxx bot;

void main(List<String> arguments) {
  print('Hello world!');

  bot = Nyxx(BOT_TOKEN);

  Commander(bot, prefix: CMD_PREFIX)
    ..registerCommand('ölhelp', helpCommand)
    ..registerCommand('reg', regCommand)
    ..registerCommand('öl', oelCommand)
    ..registerCommand('släpp', slappCommand);

  ELAPSED_SINCE_UPDATE = Stopwatch();

  bot.onReady.listen((e) {
    print('Ready!');
    bot.setPresence(
      game: Activity.of('!ölhelp', type: ActivityType.listening),
    );
  });

  Timer.periodic(Duration(hours: 6), updateTimeout);
}

void updateTimeout(Timer timer) {
  updateSubscribers();
}

Future<void> updateSubscribers() async {
  await requestBeer();

  var myFile = File('sub.dat');
  var shouldInform = false;
  var beers = <Beer>[];
  var saleDate;

  if (!await myFile.exists()) return;

  for (var sale in BEER_SALES) {
    saleDate = DateTime.parse(sale.saleDate);
    var currentDate =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (saleDate.difference(currentDate).inDays == 1) {
      //Inform subscribing users about upcoming sale...
      shouldInform = true;
      print('Sale is going down!');
      beers = sale.beerList;
      break;
    }
    //No sale is closer than 1 day -> do nothing...
  }

  if (shouldInform) {
    for (var dmchannel in await getSubChannels(bot)) {
      var beersStr = '';
      beers.forEach((element) {
        beersStr += '- ' + element.name + '\n';
      });

      var updateMessage = MessageBuilder()
        ..append(':beers: Hej!')
        ..appendNewLine()
        ..append('Kom ihåg ölsläppet imorgon, ')
        ..appendBold(DateFormat('yyyy-MM-dd').format(saleDate))
        ..append('. Bolaget öppnar 10:00')
        ..appendNewLine()
        ..append('Det finns ')
        ..appendBold(beers.length.toString())
        ..append(' nya öl imorgon.')
        ..appendNewLine()
        ..append('Mer info hittar du på https://systembevakningsagenten.se/')
        ..appendNewLine()
        ..appendNewLine()
        ..append(beersStr);

      //To avoid hitting maximum characters for a message, limit output to 2000.
      if (updateMessage.toString().length > 2000) {
        updateMessage.content =
            updateMessage.content.substring(0, 1992) + '...\n\n';
      }
      await dmchannel.send(builder: updateMessage);
    }
  } else {
    print('No sale, boring...');
  }
}

Future requestBeer() async {
  //Only update list if older than 4 hours or empty
  if (ELAPSED_SINCE_UPDATE.elapsedMilliseconds > REFRESH_THRESHOLD ||
      BEER_SALES.isEmpty) {
    ELAPSED_SINCE_UPDATE.stop();
    print('Updating beer releases and beers...');
    final list = await fetchBeerList();
    for (var item in list['release']) {
      BEER_SALES.add(BeerList.fromJson(item));
    }
    ELAPSED_SINCE_UPDATE.reset();
    ELAPSED_SINCE_UPDATE.start();
  } else {
    print('No update needed, requires update in ' +
        (((REFRESH_THRESHOLD - ELAPSED_SINCE_UPDATE.elapsedMilliseconds) /
                    1000) ~/
                60)
            .toString() +
        ' minutes.');
  }
}

Future<Map<String, dynamic>> fetchBeerList() async {
  final response = await http
      .get('https://systembevakningsagenten.se/api/json/2.0/newProducts.json');

  if (response.statusCode == 200) {
    Map<String, dynamic> res = json.decode(response.body);
    return res;
  } else {
    throw Exception('Error fetching beer information');
  }
}

//Commands
Future<void> helpCommand(CommandContext ctx, String content) async {
  var helpMessage = MessageBuilder()
    ..append(ctx.member.mention)
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

  await ctx.reply(builder: helpMessage);
}

Future<void> regCommand(CommandContext ctx, String content) async {
  var dmChan = await ctx.member.dmChannel;
  if (await isUserSubbed(bot, dmChan.id.toString())) {
    await ctx.reply(
        content: ctx.member.mention + ' Du är redan registrerad! :beers:');
  } else {
    var myFile = File('sub.dat');
    await myFile.writeAsString(dmChan.id.toString(), mode: FileMode.append);
    await ctx.reply(
        content: ctx.member.mention +
            ' Nu är du registrerad för öluppdateringar! :beers:');
  }
}

Future<void> oelCommand(CommandContext ctx, String content) async {
  //Updates current beer list if needed
  await requestBeer();

  //Build message
  var oelMessage = MessageBuilder()
    ..append(ctx.member.mention)
    ..appendNewLine()
    ..append('Det finns ')
    ..appendBold(BEER_SALES.length.toString())
    ..append(' aktuella släpp!')
    ..appendNewLine()
    ..appendNewLine();

  for (var beerSale in BEER_SALES) {
    var saleDate = beerSale.saleDate;
    var saleSize = beerSale.beerList.length.toString();
    beerSale.beerList.shuffle();

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
  }

  oelMessage
    ..append('---')
    ..appendNewLine()
    ..append('För mer information: https://systembevakningsagenten.se/')
    ..appendNewLine()
    ..appendNewLine()
    ..append('Skål! :beers:');

  //Send message
  await ctx.reply(builder: oelMessage);
}

Future<void> slappCommand(CommandContext ctx, String content) async {
  var input = content.split(' ');
  if (input.length == 2) {
    var parsedDate = DateTime.tryParse(input[1]);

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
            ..append(ctx.member.mention)
            ..appendNewLine()
            ..append(' :beers: ')
            ..appendBold(input[1])
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
                    slappMessage.content.substring(0, 1999).lastIndexOf('- ') -
                        1) +
                '\n...';
          }
          await ctx.reply(builder: slappMessage);
          return;
        }
      }
      await ctx.reply(
          content: ctx.member.mention +
              ' Fanns inget ölsläpp för ' +
              DateFormat('yyyy-MM-dd').format(parsedDate));
      return;
    }
  }

  await ctx.reply(
      content: ctx.member.mention +
          ' Är du lite full? Jag accepterar bara ***!släpp YYYY-MM-dd***');
}

//Not used
Future<void> dmmeCommand(CommandContext ctx, String content) async {
  var locmember;
  var myFile = File('sub.dat');

  await myFile.readAsLines().then((value) {
    for (var line in value) {
      locmember = Snowflake(line);
    }
  });

  print(locmember.toString());

  var user = await ctx.member.dmChannel;

  await (user)
      .send(content: 'Nu är du registrerad för öluppdateringar! :beers:');
}

Future<void> oelemCommand(CommandContext ctx, String content) async {
  var embed = EmbedBuilder();
  var author = EmbedAuthorBuilder();
  var footer = EmbedFooterBuilder();

  author.name = 'Ölrapport';

  footer.text = 'SKÅL!';

  embed.color = DiscordColor.cyan;
  embed.url = 'https://example.com';

  embed.author = author;
  //embed.footer = footer;

  //Updates current beer list if needed
  await requestBeer();

  //Build message
  var title = 'Det finns ' +
      MessageDecoration.bold.format(BEER_SALES.length.toString()) +
      ' kommande släpp! \n';
  title +=
      'För mer info besök [Systembevakningsagenten](https://systembevakningsagenten.se/) :beers:\n';

  for (var beerSale in BEER_SALES) {
    var message = '';

    var dateString =
        '\n:beer: - ' + MessageDecoration.bold.format(beerSale.saleDate) + '\n';

    message += 'Innehåller ' +
        MessageDecoration.bold.format(beerSale.beerList.length.toString()) +
        ' nya öl! \n\r';

    beerSale.beerList.sort((b, a) => a.score.compareTo(b.score));
    message += 'Med bla. dessa megaöl:\n';

    for (var i = 0; i < beerSale.beerList.length; i++) {
      if (i >= 3) break;
      var currentBeer = beerSale.beerList[i];

      message += (i + 1).toString() +
          '. ' +
          MessageDecoration.bold
              .format(MessageDecoration.italics.format(currentBeer.name)) +
          ' med ' +
          MessageDecoration.bold.format(currentBeer.score.toString()) +
          ' på RateBeer\n';
    }

    var field = EmbedFieldBuilder();
    field.content = message + '\n\r';
    field.name = dateString;
    embed.description = title;

    embed.addField(field: field);
  }

  await ctx.reply(content: ctx.member.mention, embed: embed);
}
