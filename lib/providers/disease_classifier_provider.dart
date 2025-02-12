import 'package:flutter/foundation.dart';
import 'package:rice_disease_classifier/models/classification_record.dart';
import 'package:rice_disease_classifier/services/database_helper.dart';
import 'package:rice_disease_classifier/services/disease_info_service.dart';
import 'package:rice_disease_classifier/services/image_processing_service.dart';
import 'package:rice_disease_classifier/services/ml_service.dart';

class DiseaseClassifierProvider with ChangeNotifier {
  final ImageProcessingService _imageProcessingService =
      ImageProcessingService();
  final MLService _mlService = MLService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isInitialized = false;

  bool _isProcessing = false;
  String? _result;
  double? _confidence;
  String? _processedImagePath;
  List<ClassificationRecord> _history = [];
  DiseaseInfo? _currentDiseaseInfo;

  bool get isProcessing => _isProcessing;
  String? get result => _result;
  double? get confidence => _confidence;
  String? get processedImagePath => _processedImagePath;
  List<ClassificationRecord> get history => _history;
  DiseaseInfo? get currentDiseaseInfo => _currentDiseaseInfo;

  Future<void> initialize() async {
    if (!_isInitialized) {
      await _mlService.initialize();
      await loadHistory();
      _isInitialized = true;
    }
  }

  Future<void> loadHistory() async {
    try {
      _history = await _databaseHelper.getRecords();
      notifyListeners();
    } catch (e) {
      _history = [];
      notifyListeners();
      throw Exception('Failed to load history: $e');
    }
  }

  Future<void> classifyImage(String imagePath) async {
    try {
      _isProcessing = true;
      _result = null;
      _confidence = null;
      _currentDiseaseInfo = null;
      notifyListeners();

      if (!_isInitialized) {
        await initialize();
      }

      _processedImagePath =
          await _imageProcessingService.preprocessImage(imagePath);
      final (prediction, confidence) =
          await _mlService.classifyImage(_processedImagePath!);

      _result = prediction;
      _confidence = confidence;
      _currentDiseaseInfo = DiseaseInfoService.getInfo(prediction);

      await _databaseHelper.insertClassification(
        imagePath: _processedImagePath!,
        disease: prediction,
        confidence: confidence,
      );
      await loadHistory();

      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _isProcessing = false;
      _result = 'Error: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  Future<List<ClassificationRecord>> getHistory() async {
    return await _databaseHelper.getRecords();
  }

  Future<void> deleteRecords(List<int> ids) async {
    for (final id in ids) {
      await _databaseHelper.deleteRecord(id);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _mlService.dispose();
    super.dispose();
  }
}
