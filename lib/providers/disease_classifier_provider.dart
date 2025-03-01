import 'package:flutter/foundation.dart';
import 'package:rice_disease_classifier/models/classification_record.dart';
import 'package:rice_disease_classifier/services/database_helper.dart';
import 'package:rice_disease_classifier/services/disease_info_service.dart';
import 'package:rice_disease_classifier/services/image_processing_service.dart';
import 'package:rice_disease_classifier/services/ml_service.dart';
import 'dart:io';

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
      // Reset state for new classification
      _isProcessing = true;
      _result = null;
      _confidence = null;
      _currentDiseaseInfo = null;
      _processedImagePath = null;
      notifyListeners();

      if (!_isInitialized) {
        await initialize();
      }

      // Process the image
      _processedImagePath =
          await _imageProcessingService.preprocessImage(imagePath);

      // Ensure the processed image exists
      if (_processedImagePath == null ||
          !await File(_processedImagePath!).exists()) {
        throw Exception('Failed to process image');
      }

      // Perform classification
      final (prediction, confidence) =
          await _mlService.classifyImage(_processedImagePath!);

      // Update state with results
      _result = prediction;
      _confidence = confidence;
      _currentDiseaseInfo = DiseaseInfoService.getInfo(prediction);

      // Save to history (including uncertain predictions)
      if (_processedImagePath != null) {
        await _databaseHelper.insertClassification(
          imagePath: _processedImagePath!,
          disease: prediction,
          confidence: confidence,
        );
      }

      // Reload history
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
    return _history;
  }

  Future<void> deleteRecords(List<int> ids) async {
    try {
      // Delete records from database
      for (final id in ids) {
        await _databaseHelper.deleteRecord(id);
      }

      // Update the local history by removing deleted records
      _history.removeWhere((record) => ids.contains(record.id));

      // Notify listeners of the change
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete records: $e');
    }
  }

  @override
  void dispose() {
    _mlService.dispose();
    super.dispose();
  }
}
