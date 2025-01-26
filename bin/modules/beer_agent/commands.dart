part of 'beer_agent_module.dart';

Future<void> _regCommand(ChatContext ctx, NyxxGateway bot) async {
  var user = ctx.user.id;

  if (await BeerAgentModule()._isUserSubbed(user)) {
    await ctx.respond(
      MessageBuilder(content: 'You are already subscribed! :beers:'),
      level: ResponseLevel.private,
    );
  } else {
    final dmChannel = await bot.user.manager.createDm(user);
    await BeerAgentModule()._subUser(dmChannel.id);

    await ctx.respond(
      MessageBuilder(
          content: 'You are now subscribed to beer release reminders! :beers:'),
      level: ResponseLevel.private,
    );
  }
}

Future<void> _stopCommand(ChatContext ctx) async {
  var user = ctx.user.id;

  if (await BeerAgentModule()._isUserSubbed(user)) {
    await BeerAgentModule()._unsubUser(user);

    await ctx.respond(
        MessageBuilder(content: 'Sad, no more beer for you! :beers:'),
        level: ResponseLevel.private);
  } else {
    await ctx.respond(
        MessageBuilder(content: 'You are not subscribed! :beers:'),
        level: ResponseLevel.private);
  }
}

Future<void> _oelCommand(ChatContext ctx) async {
  //Updates current beer list if needed
  await BeerAgentModule()._updateBeerSales();

  //Build message
  var message = 'There are '
      '${BeerAgentModule().beerSales.length} current releases!\n\n';

  for (var beerSale in BeerAgentModule().beerSales) {
    var saleDate = beerSale.saleDate;
    var saleSize = beerSale.beerList.length;
    beerSale.beerList.shuffle();

    if (saleSize >= 3) {
      message = ':beer: $saleDate\n'
          'This release has $saleSize new beers!\n\n'
          'Some of them are:\n'
          '- ${beerSale.beerList[0].name}\n'
          '- ${beerSale.beerList[1].name}\n'
          '- ${beerSale.beerList[2].name}\n\n';
    } else if (saleSize == 2) {
      message = ':beer: $saleDate\n'
          'This release has $saleSize new beers!\n\n'
          'Some of them are:\n'
          '- ${beerSale.beerList[0].name}\n'
          '- ${beerSale.beerList[1].name}\n\n';
    } else if (saleSize == 1) {
      message = ':beer: $saleDate\n'
          'This release has $saleSize new beer!\n\n'
          '- ${beerSale.beerList[0].name}\n\n';
    }

    var oelMessage = MessageBuilder(
        content: '$message\n'
            '---\n'
            'For more information: https://systembevakningsagenten.se/\n'
            'Cheers! :beers:');

    //Send message
    await ctx.respond(oelMessage);
  }
}

Future<void> _releaseCommand(ChatContext ctx) async {
  var input = ctx.arguments;
  if (input.length == 1) {
    var parsedDate = DateTime.tryParse(input[0].value);

    if (parsedDate != null) {
      await BeerAgentModule()._updateBeerSales();
      for (var sale in BeerAgentModule().beerSales) {
        var saleDate = DateTime.parse(sale.saleDate);
        if (parsedDate == saleDate) {
          //Compile beer list to string and sort by name.
          var beerStr = '';
          sale.beerList.sort((a, b) => a.name.compareTo(b.name));
          sale.beerList.forEach((element) {
            beerStr += '- ' + element.name + '\n';
          });

          //Bulild reply
          var slappMessage = MessageBuilder(
              content:
                  ':beers: Ölsläpp för ${DateFormat('yyyy-MM-dd').format(parsedDate)}'
                  ' nya öl:'
                  '\n\n'
                  '$beerStr');

          final content = slappMessage.content;

          if (content!.length > 2000) {
            slappMessage.content = content.substring(
                    0, content.substring(0, 1999).lastIndexOf('- ') - 1) +
                '\n...';
          }
          await ctx.respond(slappMessage);
          return;
        }
      }
      await ctx.respond(MessageBuilder(
          content: 'Fanns inget ölsläpp för ' +
              DateFormat('yyyy-MM-dd').format(parsedDate)));
      return;
    }
  }

  await ctx.respond(MessageBuilder(
      content: 'Are you drunk buddy? I only accept ***/release YYYY-MM-dd***'));
}
