class BeerizerBeer {
  String name;
  String price;
  double untappdRating;

  BeerizerBeer({
    required this.name,
    required this.price,
    required this.untappdRating,
  });

  @override
  String toString() {
    return 'BeerizerBeer{name: $name, price: $price, untappdRating: $untappdRating}';
  }
}
