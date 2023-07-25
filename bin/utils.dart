import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:nyxx/nyxx.dart';

import 'constants/hive_constants.dart';
import 'modules/untappd/untapped_service.dart';

Future<Map<String, dynamic>> httpGetRequest(String getURL) async {
  final response = await http.get(Uri.parse(getURL));

  if (response.statusCode == 200) {
    Map<String, dynamic> res = json.decode(response.body);
    return res;
  } else {
    throw Exception('Error during GET request!');
  }
}

Future<bool> isUserUntappdRegistered(Snowflake userSnowflake) async {
  var box = Hive.box(HiveConstants.untappdBox);
  Map<String, String> userList =
      box.get(HiveConstants.untappdUserList, defaultValue: {});
  return userList.keys.contains(userSnowflake);
}

Future<bool> regUntappdUser(
    Snowflake userSnowflake, String untappdUsername) async {
  try {
    var box = Hive.box(HiveConstants.untappdBox);

    if (!await UntappdService.isValidUsername(untappdUsername)) {
      print('No checkins available for user, ignoring add.');
      return false;
    }

    var currentList = box.get(HiveConstants.untappdUserList, defaultValue: {});
    currentList.addAll({userSnowflake.toString(): untappdUsername});
    await box.put(HiveConstants.untappdUserList, currentList);
    print('Saved ${currentList.toString()} to Hive box!');
    return true;
  } catch (e) {
    return false;
  }
}
