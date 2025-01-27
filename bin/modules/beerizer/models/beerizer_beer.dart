class BeerizerBeer {
  String name;
  String brewery;
  String price;
  String untappdRating;
  String style;

  BeerizerBeer({
    required this.name,
    required this.brewery,
    required this.price,
    required this.untappdRating,
    required this.style,
  });

  @override
  String toString() {
    return 'BeerizerBeer{name: $name, price: $price, untappdRating: $untappdRating}, style: $style';
  }
}
