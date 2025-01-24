part of 'beer_agent_module.dart';

Future<void> _regCommand(ISlashCommandInteractionEvent ctx) async {
  var dmChan = await ctx.interaction.userAuthor!.dmChannel;

  if (await BeerAgentModule()._isUserSubbed(dmChan.id)) {
    await ctx.respond(MessageBuilder.content(
        ctx.interaction.userAuthor!.mention +
            ' You are already subscribed! :beers:'));
  } else {
    await BeerAgentModule()._subUser(dmChan.id);

    await ctx.respond(MessageBuilder.content(
        ctx.interaction.userAuthor!.mention +
            ' You are now subscribed to beer release reminders! :beers:'));
  }
}

Future<void> _stopCommand(ISlashCommandInteractionEvent ctx) async {
  var dmChan = await ctx.interaction.userAuthor!.dmChannel;

  if (await BeerAgentModule()._isUserSubbed(dmChan.id)) {
    await BeerAgentModule()._unsubUser(dmChan.id);

    await ctx.respond(MessageBuilder.content(
        ctx.interaction.userAuthor!.mention +
            ' Sad, no more beer for you! :beers:'));
  } else {
    await ctx.respond(MessageBuilder.content(
        ctx.interaction.userAuthor!.mention +
            ' You are not subscribed! :beers:'));
  }
}

Future<void> _oelCommand(ISlashCommandInteractionEvent ctx) async {
  //Updates current beer list if needed
  await BeerAgentModule()._updateBeerSales();

  //Build message
  var oelMessage = MessageBuilder()
    ..append(ctx.interaction.userAuthor!.mention)
    ..appendNewLine()
    ..append('There are ')
    ..appendBold(BeerAgentModule().beerSales.length.toString())
    ..append(' current releases!')
    ..appendNewLine()
    ..appendNewLine();

  for (var beerSale in BeerAgentModule().beerSales) {
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

Future<void> _releaseCommand(ISlashCommandInteractionEvent ctx) async {
  var input = ctx.args;
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
                    slappMessage.content.substring(0, 1999).lastIndexOf('- ') -
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

  await ctx.respond(MessageBuilder.content(ctx.interaction.userAuthor!.mention +
      ' Are you drunk buddy? I only accept ***/release YYYY-MM-dd***'));
}
