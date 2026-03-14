class VerseDataModel {
  final int id;
  final String english;
  final String englishReference;
  final String telugu;
  final String teluguReference;
  final String? backgroundImage;

  const VerseDataModel({
    required this.id,
    required this.english,
    required this.englishReference,
    required this.telugu,
    required this.teluguReference,
    this.backgroundImage,
  });

  factory VerseDataModel.fromJson(Map<String, dynamic> json) {
    return VerseDataModel(
      id: json['id'] as int,
      english: json['english'] as String,
      englishReference: json['englishReference'] as String,
      telugu: json['telugu'] as String,
      teluguReference: json['teluguReference'] as String,
      backgroundImage: json['backgroundImage'] as String?,
    );
  }
}
