class BeerizerBeer {
  String name;
  String brewery;
  String price;
  String untappdRating;

  BeerizerBeer({
    required this.name,
    required this.brewery,
    required this.price,
    required this.untappdRating,
  });

  @override
  String toString() {
    return 'BeerizerBeer{name: $name, price: $price, untappdRating: $untappdRating}';
  }
}
