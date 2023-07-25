import 'dart:convert';

import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> httpGetRequest(String getURL) async {
  final response = await http.get(Uri.parse(getURL));

  if (response.statusCode == 200) {
    Map<String, dynamic> res = json.decode(response.body);
    return res;
  } else {
    throw Exception('Error during GET request!');
  }
}
