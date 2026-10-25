class CaDao {
  final int id;
  final String content;
  final String meaning;
  final String type;
  final String category;

  CaDao({
    required this.id,
    required this.content,
    required this.meaning,
    required this.type,
    required this.category,
  });

  factory CaDao.fromJson(Map<String, dynamic> json) {
    return CaDao(
      id: int.tryParse(json['id'].toString()) ?? 0,
      content: json['content']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? 'Chưa có giải nghĩa.',
      type: json['type']?.toString() ?? 'Ca dao',
      category: json['category']?.toString() ?? 'Văn hóa',
    );
  }
}