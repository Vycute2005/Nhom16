class Phrase {
  final String category;
  final String meaning;
  final String northWord;
  final String centralWord;
  final String southWord;

  Phrase({
    required this.category,
    required this.meaning,
    required this.northWord,
    required this.centralWord,
    required this.southWord,
  });

  factory Phrase.fromJson(Map<String, dynamic> json) {
    return Phrase(
      category: json['category']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? '',
      northWord: json['north_word']?.toString() ?? '',
      centralWord: json['central_word']?.toString() ?? '',
      southWord: json['south_word']?.toString() ?? '',
    );
  }
}