class Food {
  final String id;
  final String name;
  final String description;
  final String imageUrl;

  Food({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }
}
