class LiveChannel {
  const LiveChannel({
    required this.id,
    required this.name,
    required this.category,
    required this.country,
    required this.countryCode,
    required this.thumbnailUrl,
    required this.streamUrl,
  });

  final String id;
  final String name;
  final String category;
  final String country;
  final String countryCode;
  final String thumbnailUrl;
  final String streamUrl;
}

class MovieItem {
  const MovieItem({
    required this.id,
    required this.title,
    required this.genre,
    required this.year,
    required this.posterUrl,
    required this.videoUrl,
    required this.description,
  });

  final String id;
  final String title;
  final String genre;
  final String year;
  final String posterUrl;
  final String videoUrl;
  final String description;
}
