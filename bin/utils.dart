import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:nyxx/nyxx.dart';
import 'dart:io';

import 'untapped_service.dart';

Future<Map<String, dynamic>> httpGetRequest(String getURL) async {
  final response = await http.get(Uri.parse(getURL));

  if (response.statusCode == 200) {
    Map<String, dynamic> res = json.decode(response.body);
    return res;
  } else {
    throw Exception('Error during GET request!');
  }
}

Future<List<IDMChannel>> getSubChannels(INyxxWebsocket bot) async {
  var myFile = File('sub.dat');
  var channelList = <IDMChannel>[];

  var fileExists = await myFile.exists();
  if (!fileExists) await myFile.create();

  await myFile.readAsLines().then((value) async {
    for (var line in value) {
      var chan = await bot
          .fetchChannel(Snowflake(line))
          .then((value) => (value as IDMChannel));

      channelList.add(chan);
    }
  });
  return channelList;
}

Future<bool> isUserSubbed(INyxxWebsocket bot, Snowflake userSnowflake) async {
  var subs = await getSubChannels(bot);

  if (subs.asSnowflakes().contains(userSnowflake)) {
    return true;
  } else {
    return false;
  }
}

Future<void> unsubUser(INyxxWebsocket bot, Snowflake userSnowflake) async {
  var currentSubs = await getSubChannels(bot);

  currentSubs.removeWhere((element) => element.id == userSnowflake);
  var tempFile = File('temp.dat');
  var subFile = File('sub.dat');

  await tempFile.create();

  currentSubs.forEach((element) async {
    await tempFile.writeAsString(element.id.toString(), mode: FileMode.append);
  });

  await subFile.writeAsBytes(await tempFile.readAsBytes());

  await tempFile.delete();
}

Future<void> subUser(Snowflake userSnowflake) async {
  var myFile = File('sub.dat');
  await myFile.writeAsString(userSnowflake.toString(), mode: FileMode.append);
}

Future<bool> isUserUntappdRegistered(
    Snowflake userSnowflake, String username) async {
  var myFile = File('untappd.dat');

  var fileExists = await myFile.exists();
  if (!fileExists) await myFile.create();

  return false;
}

Future<bool> regUntappdUser(
    Snowflake userSnowflake, String untappdUsername) async {
  try {
    if (!await UntappdService.isValidUsername(untappdUsername)) {
      return false;
    }
    var untappdFile = File('untappd.dat');
    await untappdFile.writeAsString(
        '${userSnowflake.toString()};$untappdUsername',
        mode: FileMode.append);
    return true;
  } catch (e) {
    return false;
  }
}
