class ClassificationRecord {
  final int? id;
  final String imagePath;
  final String prediction;
  final double confidence;
  final DateTime timestamp;

  ClassificationRecord({
    this.id,
    required this.imagePath,
    required this.prediction,
    required this.confidence,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_path': imagePath,
      'prediction': prediction,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ClassificationRecord.fromMap(Map<String, dynamic> map) {
    return ClassificationRecord(
      id: map['id'] as int?,
      imagePath: map['image_path'] as String,
      prediction: map['prediction'] as String,
      confidence: map['confidence'] as double,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
