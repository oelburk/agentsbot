import 'beer.dart';

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
