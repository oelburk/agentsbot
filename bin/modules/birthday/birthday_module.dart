import 'dart:async';

import 'package:cron/cron.dart';
import 'package:hive/hive.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../bot_module.dart';
import 'hive_constants.dart';

part 'commands.dart';

class BirthdayModule extends BotModule {
  static final BirthdayModule _singleton = BirthdayModule._internal();

  bool _isInitialized = false;

  late INyxxWebsocket _bot;

  final Cron _birthdayCron = Cron();

  factory BirthdayModule() {
    return _singleton;
  }
  BirthdayModule._internal();

  @override
  void init(INyxxWebsocket bot) {
    _bot = bot;

    // Set up Hive for local data storage
    Hive.init('/data');
    Hive.openBox(HiveConstants.birthdayBox);

    _birthdayCron.schedule(Schedule.parse('0 9 * * *'), () {
      _checkBirthdays();
    });

    _isInitialized = true;
  }

  void _checkBirthdays() {
    if (!_isInitialized) {
      print('Birthday module not initialized!');
      throw Exception('Birthday module not initialized!');
    }
    var box = Hive.box(HiveConstants.birthdayBox);

    Map<dynamic, dynamic> listOfUsers =
        box.get(HiveConstants.birthdayUserList, defaultValue: {});

    var updateChannelId = box.get(HiveConstants.birthdayChannelId);

    if (updateChannelId == null) {
      print('No channel available for updates!');
      return;
    }

    if (listOfUsers.isEmpty) print('No users available to scrape!');

    listOfUsers.forEach((userSnowflake, birthday) async {
      var birthdayDate = DateTime.parse(birthday);
      var birthdayUser = await _bot.fetchUser(Snowflake(userSnowflake));

      // If a user has birthday today, post update to main update channel!
      if (birthdayDate.day == DateTime.now().day &&
          birthdayDate.month == DateTime.now().month) {
        var channel =
            await _bot.fetchChannel(Snowflake(updateChannelId)) as ITextChannel;

        await channel.sendMessage(MessageBuilder.content(
            'Happy birthday ${birthdayUser.mention}! 🎉🎉🎉'));
      }

      // If a user has birthday tomorrow, post update as DM to other users!
      if (birthdayDate.day == DateTime.now().add(Duration(days: 1)).day &&
          birthdayDate.month == DateTime.now().add(Duration(days: 1)).month) {
        // Check if the birthday user is a member of any of the bot guilds
        _bot.guilds.forEach((key, value) {
          final userIsMember = value.members.entries
              .any((member) => member.value.id == Snowflake(userSnowflake));

          // If the user is a member of the guild,
          // send a reminder as DM to all other members in that guild
          if (userIsMember) {
            value.members.forEach((key, value) {
              if (value.id != Snowflake(userSnowflake)) {
                _bot.fetchUser(value.id).then((otherUser) {
                  final dmChannel = otherUser.dmChannel as IDMChannel;
                  dmChannel.sendMessage(MessageBuilder.content(
                      'Get ready! Tomorrow is ${birthdayUser.mention}\'s birthday! 🎉🎉🎉'));
                });
              }
            });
          }
        });
      }
    });
  }

  @override
  List<SlashCommandBuilder> get commands => [
        SlashCommandBuilder(
          'birthday',
          'Set your birthday',
          [
            CommandOptionBuilder(
                CommandOptionType.string, 'birthday', 'e.g. 1980-12-21',
                required: true),
          ],
        )..registerHandler(_setBirthday),
        SlashCommandBuilder(
          'setupBirthday',
          'Register a channel for birthday updates',
          [],
          canBeUsedInDm: false,
        )..registerHandler(_setupBirthdayCommand),
      ];

  @override
  MessageBuilder get helpMessage => !_isInitialized
      ? throw Exception('Untappd module not initialized!')
      : MessageBuilder()
    ..appendBold('/birthday <birthday>')
    ..appendNewLine()
    ..append(
        'Set your birthday. The bot will post a nice birthday wish when it\'s your birthday.')
    ..appendNewLine()
    ..appendNewLine()
    ..appendBold('/setupBirthday')
    ..appendNewLine()
    ..append(
        'Register a channel for birthday updates. The bot will post a message in this channel when it\'s someone\'s birthday. This command can only be used by server admins.');
}
