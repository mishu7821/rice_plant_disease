import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';

/// Service to handle ML model operations including initialization and image classification
class MLService {
  static const String modelPath = 'assets/models/rice_model.tflite';
  final _logger = Logger();

  late final Interpreter _interpreter;
  late final List<String> _labels;
  bool _isInitialized = false;

  // Normalization parameters for [-1, 1] range
  static const double _inputMean = 0.0;
  static const double _inputStd = 255.0;

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

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize with optimized settings
      final options = InterpreterOptions()
        ..threads = 4 // Use multiple threads for CPU operations
        ..useNnApiForAndroid = true; // Enable Android Neural Networks API

      try {
        // Try to use GPU acceleration
        final gpuDelegate = GpuDelegate();
        options.addDelegate(gpuDelegate);
        _logger.i('GPU delegate enabled for faster inference');
      } catch (e) {
        _logger.w('GPU acceleration not available, using CPU: $e');
        // Keep NNAPI enabled as fallback
      }
      _interpreter = await Interpreter.fromAsset(modelPath, options: options);

      final inputTensor = _interpreter.getInputTensor(0);
      final outputTensor = _interpreter.getOutputTensor(0);

      _logger.i('Model loaded:');
      _logger.i('Input shape: ${inputTensor.shape}');
      _logger.i('Input type: ${inputTensor.type}');
      _logger.i('Output shape: ${outputTensor.shape}');
      _logger.i('Output type: ${outputTensor.type}');

      if (outputTensor.shape[1] != _modelLabels.length) {
        throw Exception(
            'Model output shape ${outputTensor.shape[1]} does not match label count ${_modelLabels.length}');
      }

      // Log tensor information
      _logger.i('Input tensor type: ${inputTensor.type}');
      _logger.i('Using normalization range: [-1, 1]');

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
      _logger.i('Starting new classification for image: $imagePath');

      // Verify image exists
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist: $imagePath');
      }

      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) throw Exception('Failed to decode image');

      _logger.i('Original image size: ${image.width}x${image.height}');

      // Enhanced image preprocessing with better quality
      var processedImage = img.copyResize(
        image,
        width: 224,
        height: 224,
        interpolation: img
            .Interpolation.cubic, // Use cubic interpolation for better quality
      );

      // Apply moderate image enhancement
      processedImage = img.adjustColor(
        processedImage,
        contrast: 1.2, // Moderate contrast increase
        brightness: 1.0, // Keep original brightness
        saturation: 1.1, // Slight saturation boost
      );

      // Convert to float array and normalize to [-1, 1]
      final inputBuffer = Float32List(1 * 224 * 224 * 3);
      var index = 0;
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = processedImage.getPixel(x, y);
          // Simple normalization to [-1, 1] range
          inputBuffer[index++] = (pixel.r / _inputStd) * 2 - 1;
          inputBuffer[index++] = (pixel.g / _inputStd) * 2 - 1;
          inputBuffer[index++] = (pixel.b / _inputStd) * 2 - 1;
        }
      }

      // Run inference with raw output
      final outputBuffer = Float32List(_labels.length);
      _interpreter.run(inputBuffer.buffer, outputBuffer.buffer);

      final rawPredictions = outputBuffer.toList();

      // Apply softmax to get probabilities
      final probabilities = _applySoftmax(rawPredictions);

      // Log all predictions with their probabilities
      for (var i = 0; i < _labels.length; i++) {
        _logger.i(
            '${_labels[i]}: ${(probabilities[i] * 100).toStringAsFixed(2)}%');
      }

      // Sort predictions by confidence
      final predictions = List<MapEntry<String, double>>.generate(
        _labels.length,
        (i) => MapEntry(_labels[i], probabilities[i]),
      )..sort((a, b) => b.value.compareTo(a.value));

      // Log all predictions sorted by confidence
      _logger.i('Sorted predictions:');
      for (var pred in predictions) {
        _logger.i('${pred.key}: ${(pred.value * 100).toStringAsFixed(2)}%');
      }

      // Get top prediction
      final topPrediction = predictions.first;

      // Define confidence thresholds
      const highConfidenceThreshold = 0.85; // 85%
      const minConfidenceThreshold = 0.35; // 35%
      const marginThreshold = 0.25; // 25% margin for clear winner

      // Check if it's a "normal" prediction
      if (topPrediction.key == 'normal') {
        // Require very high confidence for normal prediction
        if (topPrediction.value > highConfidenceThreshold) {
          _logger.i(
              'High confidence normal prediction: ${(topPrediction.value * 100).toStringAsFixed(2)}%');
          return (topPrediction.key, topPrediction.value);
        } else {
          // If normal but not high confidence, check second prediction
          final secondPrediction = predictions[1];
          if (secondPrediction.value > minConfidenceThreshold) {
            _logger.i(
                'Defaulting to second prediction due to low confidence normal: ${secondPrediction.key}');
            return (secondPrediction.key, secondPrediction.value);
          }
        }
      }

      // For disease predictions
      if (topPrediction.value < minConfidenceThreshold) {
        _logger.w(
            'Low confidence prediction: ${(topPrediction.value * 100).toStringAsFixed(2)}%');
        return ('uncertain', topPrediction.value);
      }

      // Check if there's a clear winner among disease predictions
      if (predictions[1].value > minConfidenceThreshold &&
          (topPrediction.value - predictions[1].value) < marginThreshold) {
        _logger.w(
            'Ambiguous prediction between ${topPrediction.key} (${(topPrediction.value * 100).toStringAsFixed(2)}%) and ${predictions[1].key} (${(predictions[1].value * 100).toStringAsFixed(2)}%)');
        // Return the disease prediction if it's competing with 'normal'
        if (predictions[1].key == 'normal' || topPrediction.key == 'normal') {
          final diseasePrediction =
              predictions[1].key == 'normal' ? topPrediction : predictions[1];
          return (diseasePrediction.key, diseasePrediction.value);
        }
        return ('uncertain', topPrediction.value);
      }

      _logger.i(
          'Final prediction: ${topPrediction.key} with confidence: ${(topPrediction.value * 100).toStringAsFixed(2)}%');
      return (topPrediction.key, topPrediction.value);
    } catch (e) {
      _logger.e('Error classifying image', error: e);
      throw Exception('Error classifying image: $e');
    }
  }

  List<double> _applySoftmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) => _exp(x - maxLogit)).toList();
    final sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map((x) => x / sumExp).toList();
  }

  double _exp(double x) {
    if (x > 88.0) return double.maxFinite;
    if (x < -88.0) return 0.0;
    return math.exp(x);
  }

  void dispose() {
    if (_isInitialized) {
      try {
        _interpreter.close();
        _logger.i('TFLite interpreter disposed successfully');
      } catch (e) {
        _logger.e('Error disposing TFLite interpreter: $e');
      } finally {
        _isInitialized = false;
      }
    }
  }
}
