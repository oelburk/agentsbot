part of 'untapped_module.dart';

Future<void> _untappdCommand(ISlashCommandInteractionEvent ctx) async {
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

  if (!await UntappdModule()._regUntappdUser(discordUser, untappdUsername)) {
    await ctx.respond(MessageBuilder.content(
        ctx.interaction.userAuthor!.mention +
            ' Whops, something went sideways! :beers:'));
  }
  await ctx.respond(MessageBuilder.content(ctx.interaction.userAuthor!.mention +
      ' From now on I will post your updates from untappd! :beers:'));
}

Future<void> _setupUntappdServiceCommand(
    ISlashCommandInteractionEvent ctx) async {
  if (ctx.interaction.memberAuthorPermissions?.administrator ?? false) {
    var beerUpdateChannel = await ctx.interaction.channel.getOrDownload();

    var box = Hive.box(HiveConstants.untappdBox);
    await box.put(
        HiveConstants.untappdUpdateChannelId, beerUpdateChannel.id.toString());

    await beerUpdateChannel.sendMessage(MessageBuilder.content(
        ' I will post untappd updates to this channel! Ask your users to register their username with /untappd followed by their untappd username.'));
  }
}
