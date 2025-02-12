import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:rice_disease_classifier/services/disease_info_service.dart';

/// Service to handle ML model operations including initialization and image classification
class MLService {
  static const String modelPath = 'assets/models/rice_model.tflite';
  final _logger = Logger();

  late final Interpreter _interpreter;
  late final List<String> _labels;
  bool _isInitialized = false;

  // Normalization parameters
  static const double _inputMean = 127.5;
  static const double _inputStd = 128.0;

  // Class weights to balance predictions
  final Map<String, double> _classWeights = {
    'bacterial_leaf_blight': 1.2,
    'bacterial_leaf_streak': 1.2,
    'bacterial_panicle_blight': 1.2,
    'blast': 1.2,
    'brown_spot': 1.2,
    'dead_heart': 1.2,
    'downy_mildew': 1.2,
    'hispa': 0.6,
    'normal': 1.4,
    'tungro': 1.2,
  };

  // Define the fixed order of labels that matches the model's output
  static const List<String> _modelLabels = [
    'bacterial_leaf_blight',
    'bacterial_leaf_streak',
    'bacterial_panicle_blight',
    'blast',
    'brown_spot',
    'dead_heart',
    'downy_mildew',
    'hispa',
    'normal',
    'tungro',
  ];

  // Prediction smoothing parameters
  static const int _smoothingWindowSize = 3;
  final List<List<double>> _recentPredictions = [];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load model with optimized settings
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(modelPath, options: options);

      // Get input and output shapes for verification
      final inputShape = _interpreter.getInputTensor(0).shape;
      final outputShape = _interpreter.getOutputTensor(0).shape;
      _logger.i(
          'Model loaded - Input shape: $inputShape, Output shape: $outputShape');

      // Verify output shape matches our label count
      if (outputShape[1] != _modelLabels.length) {
        throw Exception(
            'Model output shape ${outputShape[1]} does not match label count ${_modelLabels.length}');
      }

      // Use the fixed order labels
      _labels = _modelLabels;
      _logger.i('Using ${_labels.length} labels in fixed order: $_labels');

      _isInitialized = true;
    } catch (e) {
      _logger.e('Failed to initialize TFLite interpreter', error: e);
      throw Exception('Failed to initialize TFLite interpreter: $e');
    }
  }

  Future<(String, double)> classifyImage(String imagePath) async {
    if (!_isInitialized) {
      throw Exception('ML Service not initialized');
    }

    try {
      _logger.i('Processing image: $imagePath');

      // Load and decode image
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) throw Exception('Failed to decode image');

      _logger.i('Original image size: ${image.width}x${image.height}');

      // Resize and preprocess image
      final resizedImage = img.copyResize(
        image,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      // Convert to float32 values with adjusted normalization
      final inputBuffer = Float32List(1 * 224 * 224 * 3);
      var index = 0;

      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          // Normalize RGB values using mean and std
          inputBuffer[index++] = (pixel.r - _inputMean) / _inputStd;
          inputBuffer[index++] = (pixel.g - _inputMean) / _inputStd;
          inputBuffer[index++] = (pixel.b - _inputMean) / _inputStd;
        }
      }

      // Prepare output buffer
      final outputBuffer = Float32List(_labels.length);

      // Run inference
      _interpreter.run(inputBuffer.buffer, outputBuffer.buffer);

      // Process results with improved confidence threshold
      final results = outputBuffer.toList();
      _logger.i('Raw prediction scores: $results');

      // Apply class weights
      final weightedResults = List<double>.from(results);
      for (var i = 0; i < weightedResults.length; i++) {
        final label = _labels[i];
        final weight = _classWeights[label] ?? 1.0;
        weightedResults[i] *= weight;
      }

      // Add to recent predictions for smoothing
      _recentPredictions.add(weightedResults);
      if (_recentPredictions.length > _smoothingWindowSize) {
        _recentPredictions.removeAt(0);
      }

      // Apply smoothing by averaging recent predictions
      final smoothedResults = List<double>.filled(weightedResults.length, 0.0);
      for (var i = 0; i < weightedResults.length; i++) {
        var sum = 0.0;
        for (final prediction in _recentPredictions) {
          sum += prediction[i];
        }
        smoothedResults[i] = sum / _recentPredictions.length;
      }

      // Apply softmax to get probabilities
      final probabilities = _applySoftmax(smoothedResults);

      // Find prediction with highest confidence
      var maxScore = double.negativeInfinity;
      var predictionIndex = 0;

      _logger.i('Analyzing predictions:');
      for (var i = 0; i < probabilities.length; i++) {
        final score = probabilities[i];
        final label = _labels[i];
        final info = DiseaseInfoService.getInfo(label);
        final percentage = (score * 100).toStringAsFixed(2);
        _logger.i('${info?.name ?? label}: $percentage%');

        if (score > maxScore) {
          maxScore = score;
          predictionIndex = i;
        }
      }

      // Only return prediction if confidence is above threshold
      const minConfidence = 0.5; // Increase minimum confidence threshold to 50%
      if (maxScore < minConfidence) {
        _logger.w(
            'Low confidence prediction (${(maxScore * 100).toStringAsFixed(2)}%), defaulting to normal');
        return ('normal', maxScore);
      }

      final prediction = _labels[predictionIndex];
      _logger.i(
          'Final prediction: $prediction (${(maxScore * 100).toStringAsFixed(2)}%)');
      return (prediction, maxScore);
    } catch (e) {
      _logger.e('Error classifying image', error: e);
      throw Exception('Error classifying image: $e');
    }
  }

  // Apply softmax to convert logits to probabilities
  List<double> _applySoftmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) => _exp(x - maxLogit)).toList();
    final sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map((x) => x / sumExp).toList();
  }

  // Safe exponential function
  double _exp(double x) {
    if (x > 88.0) return double.maxFinite;
    if (x < -88.0) return 0.0;
    return math.exp(x);
  }

  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
      _isInitialized = false;
    }
  }
}
