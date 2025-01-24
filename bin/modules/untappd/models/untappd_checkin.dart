class UntappdCheckin {
  const UntappdCheckin({
    required this.id,
    required this.title,
    required this.rating,
    required this.comment,
    this.photoAddress,
  });
  final String id;
  final String title;
  final String rating;
  final String comment;
  final String? photoAddress;

  @override
  String toString() {
    return 'title: $title\nrating: $rating\ncomment: $comment\nphoto url: $photoAddress\n';
  }
}
