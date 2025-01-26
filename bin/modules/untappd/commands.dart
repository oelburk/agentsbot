part of 'untapped_module.dart';

Future<void> _untappdCommand(InteractionChatContext ctx) async {
  final updateChannelId = await UntappdModule().updateChannelId;
  if (updateChannelId == null) {
    await ctx.respond(MessageBuilder(
        content: 'Whops, ask your admin to run setup first! :beers:'));
    return;
  }
  if (ctx.arguments.length != 1) {
    await ctx.respond(MessageBuilder(
        content: 'Are you drunk buddy? Your username is missing.'));
  }
  var discordUser = ctx.user.id;

  var untappdUsername = ctx.arguments.first as String;

  if (!await UntappdModule()._regUntappdUser(discordUser, untappdUsername)) {
    await ctx.respond(
        MessageBuilder(content: 'Whops, something went sideways! :beers:'));
  }
  await ctx.respond(MessageBuilder(
      content: 'From now on I will post your updates from untappd! :beers:'));
}

Future<void> _setupUntappdServiceCommand(InteractionChatContext ctx) async {
  var beerUpdateChannel = ctx.channel;

  UntappdModule().setUpdateChannelId(beerUpdateChannel.id);

  await ctx.respond(MessageBuilder(
      content:
          ' I will post untappd updates to this channel! Ask your users to register their username with /untappd followed by their untappd username.'));
}
