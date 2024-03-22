part of 'birthday_module.dart';

/// Sets the birthday of the user
Future<void> _setBirthday(ISlashCommandInteractionEvent ctx) async {
  final datePattern =
      RegExp(r'^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1])$');

  if (ctx.args.isEmpty ||
      !datePattern.hasMatch(ctx.args.first.value as String)) {
    await ctx.respond(
        MessageBuilder.content(
            'Please provide your birthday in the format YYYY-MM-DD'),
        hidden: true);
    return;
  }

  final birthday = ctx.args.first.value as String;

  final birthdayDate = DateTime.parse(birthday);

  await ctx.respond(
      MessageBuilder.content(
          'I will remember that your birthday is on ${birthdayDate.day}/${birthdayDate.month}.'),
      hidden: true);
}

Future<void> _setupBirthdayCommand(ISlashCommandInteractionEvent ctx) async {
  if (ctx.interaction.memberAuthorPermissions?.administrator ?? false) {
    var birthdayUpdateChannel = await ctx.interaction.channel.getOrDownload();

    var box = Hive.box(HiveConstants.birthdayBox);
    await box.put(
        HiveConstants.birthdayChannelId, birthdayUpdateChannel.id.toString());

    await birthdayUpdateChannel.sendMessage(MessageBuilder.content(
        'I will post birthday wishes to this channel! 🎉🎉🎉 Register your birthday with the /birthday command followed by your birthday (eg. 1972-12-31)'));
  }
}
