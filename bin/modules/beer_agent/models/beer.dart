import 'dart:math';

import 'package:nyxx/nyxx.dart';

class Beer {
  final int id;
  final int sysid;
  final String name;
  final String alcohol_vol;
  final String price;
  final String producer;
  final String country;
  final int latest;
  final int yesterday;
  final String trend;
  final int score;

  Beer(
      this.id,
      this.sysid,
      this.name,
      this.alcohol_vol,
      this.price,
      this.producer,
      this.country,
      this.latest,
      this.yesterday,
      this.trend,
      this.score);
  Beer.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        sysid = json['sysid'],
        name = json['name'],
        alcohol_vol = json['alcohol_vol'],
        price = json['price'],
        producer = json['producer'],
        country = json['country'],
        latest = json['latest'],
        yesterday = json['yesterday'],
        trend = json['trend'],
        score = Random().nextInt(100);

  String buildBeerMessage() {
    var title = MessageDecoration.underline.format(
        MessageDecoration.bold.format(name + ' ' + alcohol_vol + '%\n'));
    return title;
  }
}

class BeerList {
  final String saleDate;
  final List<Beer> beerList;

  BeerList(this.saleDate, this.beerList);
  BeerList.fromJson(Map<String, dynamic> json)
      : saleDate = json['first_sale'],
        beerList = createListFromMap(json['items']);

  static List<Beer> createListFromMap(List<dynamic> json) {
    var toReturn = <Beer>[];
    for (var item in json) {
      toReturn.add(Beer.fromJson(item));
    }
    return toReturn;
  }
}
