import 'dart:async';
import 'dart:math';
import 'package:nyxx/Vm.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx/commands.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Pattern CMD_PREFIX = '!';
String BOT_TOKEN =
    'NzE1MjQyNzgzNTEzNzcyMDcy.Xs6Z1g.IxbUPVkorbkrmu2wDi4LTtaQe0M';
Stopwatch ELAPSED_SINCE_UPDATE;
List<BeerList> BEER_SALES = <BeerList>[];
int FOUR_HOURS = 14400000;

void main(List<String> arguments) {
  print('Hello world!');

  configureNyxxForVM();

  var bot = Nyxx(BOT_TOKEN);

  var cmdFrame = CommandsFramework(bot);
  cmdFrame.prefix = '!';
  cmdFrame.discoverCommands();

  ELAPSED_SINCE_UPDATE = Stopwatch();

  bot.onReady.listen((e) {
    print('Ready!');
    bot.self.setPresence(status: 'Lyssnar på !ölhelp');
  });
}

@Command('ölhelp')
Future<void> help(CommandContext ctx) async =>
    await ctx.reply(content: "I'll show you help!");

@Command('reg')
Future<void> reg(CommandContext ctx) async => await ctx.reply(
    content: ctx.member.mention +
        ' Nu är du registrerad för öluppdateringar! :beers:');

@Command('ölem')
Future<void> oelem(CommandContext ctx) async {
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
      MessageDecoration.bold.create(BEER_SALES.length.toString()) +
      ' kommande släpp! \n';
  title +=
      'För mer info besök [Systembevakningsagenten](https://systembevakningsagenten.se/) :beers:\n';

  for (var beerSale in BEER_SALES) {
    var message = '';

    var dateString =
        '\n:beer: - ' + MessageDecoration.bold.create(beerSale.saleDate) + '\n';

    message += 'Innehåller ' +
        MessageDecoration.bold.create(beerSale.beerList.length.toString()) +
        ' nya öl! \n\r';

    beerSale.beerList.sort((b, a) => a.score.compareTo(b.score));
    message += 'Med bla. dessa megaöl:\n';

    for (var i = 0; i < beerSale.beerList.length; i++) {
      if (i >= 3) break;
      var currentBeer = beerSale.beerList[i];

      message += (i + 1).toString() +
          '. ' +
          MessageDecoration.bold
              .create(MessageDecoration.italics.create(currentBeer.name)) +
          ' med ' +
          MessageDecoration.bold.create(currentBeer.score.toString()) +
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

@Command('öl')
Future<void> oel(CommandContext ctx) async {
  //Updates current beer list if needed
  await requestBeer();

  //Build message
  var message = 'Det finns ' +
      MessageDecoration.bold.create(BEER_SALES.length.toString()) +
      ' kommande släpp! \n';

  for (var beerSale in BEER_SALES) {
    message += '\n' + MessageDecoration.bold.create(beerSale.saleDate) + '\n';
    message += 'Innehåller ' +
        MessageDecoration.bold.create(beerSale.beerList.length.toString()) +
        ' nya öl! \n\r';

    beerSale.beerList.sort((b, a) => a.score.compareTo(b.score));
    message += 'Med bla. dessa megaöl:\n';

    for (var i = 0; i < beerSale.beerList.length; i++) {
      if (i >= 3) break;
      var currentBeer = beerSale.beerList[i];

      message += (i + 1).toString() +
          '. ' +
          MessageDecoration.bold
              .create(MessageDecoration.italics.create(currentBeer.name)) +
          ' med ' +
          MessageDecoration.bold.create(currentBeer.score.toString()) +
          ' på RateBeer\n';
    }
  }

  //Send message
  await ctx.reply(
      content: (message.length < 2000 ? message : message.substring(0, 500)) +
          '\nFör mer information: ' +
          'https://systembevakningsagenten.se/ \n' +
          '\n Skål! :beers:');
}

Future requestBeer() async {
  //Only update list if older than 4 hours or empty
  if (ELAPSED_SINCE_UPDATE.elapsedMilliseconds > FOUR_HOURS ||
      BEER_SALES.isEmpty) {
    print('Updating beer releases and beers...');
    final list = await fetchBeerList();
    for (var item in list['release']) {
      BEER_SALES.add(BeerList.fromJson(item));
    }
    ELAPSED_SINCE_UPDATE.reset();
  }
}

Future<Map<String, dynamic>> fetchBeerList() async {
  final response = await http
      .get('https://systembevakningsagenten.se/api/json/2.0/newProducts.json');

  if (response.statusCode == 200) {
    Map<String, dynamic> res = json.decode(response.body);
    return res;
  } else {
    throw Exception('Error fetching album');
  }
}

class BeerList {
  final String saleDate;
  final List<Beer> beerList;

  BeerList(this.saleDate, this.beerList);
  BeerList.fromJson(Map<String, dynamic> json)
      : saleDate = json['first_sale'],
        beerList = createListFromMap(json['items']);

  static List<Beer> createListFromMap(List<dynamic> json) {
    var toReturn = <Beer>[];
    for (var item in json) {
      toReturn.add(Beer.fromJson(item));
    }
    return toReturn;
  }
}

class Beer {
  final int id;
  final int sysid;
  final String name;
  final String alcohol_vol;
  final String price;
  final String producer;
  final String country;
  final int latest;
  final int yesterday;
  final String trend;
  final int score;

  Beer(
      this.id,
      this.sysid,
      this.name,
      this.alcohol_vol,
      this.price,
      this.producer,
      this.country,
      this.latest,
      this.yesterday,
      this.trend,
      this.score);
  Beer.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        sysid = json['sysid'],
        name = json['name'],
        alcohol_vol = json['alcohol_vol'],
        price = json['price'],
        producer = json['producer'],
        country = json['country'],
        latest = json['latest'],
        yesterday = json['yesterday'],
        trend = json['trend'],
        score = Random().nextInt(100);

  String buildBeerMessage() {
    var message;
    var title = MessageDecoration.underline.create(
        MessageDecoration.bold.create(name + ' ' + alcohol_vol + '%\n'));
    return title;
  }
}
