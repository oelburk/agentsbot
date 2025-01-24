part of 'untapped_module.dart';

Future<void> _untappdCommand(ChatContext ctx) async {
  var box = Hive.box(HiveConstants.untappdBox);
  if (box.get(HiveConstants.untappdUpdateChannelId) == null) {
    await ctx.respond(MessageBuilder(
        content: 'Whops, ask your admin to run setup first! :beers:'));
    return;
  }
  if (ctx.arguments.length != 1) {
    await ctx.respond(MessageBuilder(
        content: 'Are you drunk buddy? Your username is missing.'));
  }
  var discordUser = ctx.user.id;
  var untappdUsername = ctx.arguments.first.value;

  if (!await UntappdModule()._regUntappdUser(discordUser, untappdUsername)) {
    await ctx.respond(
        MessageBuilder(content: 'Whops, something went sideways! :beers:'));
  }
  await ctx.respond(MessageBuilder(
      content: 'From now on I will post your updates from untappd! :beers:'));
}

Future<void> _setupUntappdServiceCommand(ChatContext ctx) async {
  if (ctx.member?.permissions?.isAdministrator ?? false) {
    var beerUpdateChannel = ctx.channel;

    var box = Hive.box(HiveConstants.untappdBox);
    await box.put(
        HiveConstants.untappdUpdateChannelId, beerUpdateChannel.id.toString());

    await beerUpdateChannel.sendMessage(MessageBuilder(
        content:
            ' I will post untappd updates to this channel! Ask your users to register their username with /untappd followed by their untappd username.'));
  }
}
