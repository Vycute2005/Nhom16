class Phrase {
  final String id;
  final String vietnamese;
  final String pronunciation;
  final String english;
  final String explanation;

  Phrase({
    required this.id,
    required this.vietnamese,
    required this.pronunciation,
    required this.english,
    required this.explanation,
  });

  factory Phrase.fromJson(Map<String, dynamic> json) {
    return Phrase(
      id: json['id'].toString(),
      vietnamese: json['vietnamese']?.toString() ?? '',
      pronunciation: json['pronunciation']?.toString() ?? '',
      english: json['english']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}