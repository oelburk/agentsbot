import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:nyxx/nyxx.dart';
import 'dart:io';

Future<Map<String, dynamic>> httpGetRequest(String getURL) async {
  final response = await http.get(getURL);

  if (response.statusCode == 200) {
    Map<String, dynamic> res = json.decode(response.body);
    return res;
  } else {
    throw Exception('Error during GET request!');
  }
}

Future<List<DMChannel>> getSubChannels(Nyxx bot) async {
  var myFile = File('sub.dat');
  var channelList = <DMChannel>[];

  var fileExists = await myFile.exists();
  if (!fileExists) await myFile.create();

  await myFile.readAsLines().then((value) async {
    for (var line in value) {
      var chan = await bot
          .getChannel(Snowflake(line))
          .then((value) => (value as DMChannel));

      channelList.add(chan);
    }
  });
  return channelList;
}

Future<bool> isUserSubbed(Nyxx bot, String userSnowflake) async {
  var subs = await getSubChannels(bot);

  if (subs.contains(userSnowflake)) {
    return true;
  } else {
    return false;
  }
}
