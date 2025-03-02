import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';

/// Service to handle ML model operations including initialization and image classification
class MLService {
  final _logger = Logger();

  late final Interpreter _interpreter;
  late final List<String> _labels;
  bool _isInitialized = false;

  // Fixed labels for the model
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

  // Initialization of the ML model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.i('Initializing ML Service');

      // Load model
      final interpreterOptions = InterpreterOptions();

      // Get the model path
      final modelPath = await _getModelPath();
      _logger.i('Loading model from path: $modelPath');

      try {
        _interpreter =
            await Interpreter.fromAsset(modelPath, options: interpreterOptions);
      } catch (e) {
        _logger.e('Error loading model from asset: $e');
        // Try loading with a different path format for release mode
        final alternativePath = modelPath.startsWith('assets/')
            ? modelPath.substring(7) // Remove 'assets/' prefix
            : 'assets/$modelPath';
        _logger.i('Trying alternative path: $alternativePath');
        _interpreter = await Interpreter.fromAsset(alternativePath,
            options: interpreterOptions);
      }

      // Use predefined labels since labels.txt doesn't exist
      _logger.i('Using predefined labels: $_modelLabels');
      _labels = List.from(_modelLabels);

      _logger.i('Model loaded successfully with ${_labels.length} labels');
      _isInitialized = true;
    } catch (e) {
      _logger.e('Failed to initialize ML Service', error: e);
      throw Exception('Failed to initialize ML Service: $e');
    }
  }

  // Helper method to get the model path
  Future<String> _getModelPath() async {
    return 'assets/models/rice_disease_model.tflite';
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

      // Resize image to model input size
      var processedImage = img.copyResize(
        image,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.cubic,
      );

      // Convert to float array and normalize using improved technique
      final inputBuffer = Float32List(1 * 224 * 224 * 3);
      var index = 0;

      // Calculate image statistics for better normalization
      double meanR = 0, meanG = 0, meanB = 0;
      double stdR = 0, stdG = 0, stdB = 0;

      // First pass: calculate means
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = processedImage.getPixel(x, y);
          meanR += pixel.r.toDouble();
          meanG += pixel.g.toDouble();
          meanB += pixel.b.toDouble();
        }
      }

      int totalPixels = 224 * 224;
      meanR /= totalPixels;
      meanG /= totalPixels;
      meanB /= totalPixels;

      // Second pass: calculate standard deviations
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = processedImage.getPixel(x, y);
          stdR += (pixel.r.toDouble() - meanR) * (pixel.r.toDouble() - meanR);
          stdG += (pixel.g.toDouble() - meanG) * (pixel.g.toDouble() - meanG);
          stdB += (pixel.b.toDouble() - meanB) * (pixel.b.toDouble() - meanB);
        }
      }

      stdR = math.sqrt(stdR / totalPixels);
      stdG = math.sqrt(stdG / totalPixels);
      stdB = math.sqrt(stdB / totalPixels);

      // Prevent division by zero
      stdR = stdR < 1.0 ? 1.0 : stdR;
      stdG = stdG < 1.0 ? 1.0 : stdG;
      stdB = stdB < 1.0 ? 1.0 : stdB;

      _logger.i(
          'Image statistics - Mean: ($meanR, $meanG, $meanB), StdDev: ($stdR, $stdG, $stdB)');

      // Third pass: normalize using calculated statistics (z-score normalization)
      index = 0;
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = processedImage.getPixel(x, y);

          // Z-score normalization with scaling to [-1, 1] range
          // Increase scaling factor from 0.5 to 1.0 for better confidence representation
          inputBuffer[index++] = ((pixel.r.toDouble() - meanR) / stdR);
          inputBuffer[index++] = ((pixel.g.toDouble() - meanG) / stdG);
          inputBuffer[index++] = ((pixel.b.toDouble() - meanB) / stdB);
        }
      }

      // Run multiple inferences and average results for more stability
      final List<List<double>> allPredictions = [];
      const int numInferences = 3;

      for (int i = 0; i < numInferences; i++) {
        final outputBuffer = Float32List(_labels.length);
        _interpreter.run(inputBuffer.buffer, outputBuffer.buffer);
        allPredictions.add(outputBuffer.toList());
      }

      // Average the predictions
      final List<double> averagedRawPredictions =
          List.filled(_labels.length, 0.0);
      for (int labelIdx = 0; labelIdx < _labels.length; labelIdx++) {
        for (int inferenceIdx = 0;
            inferenceIdx < numInferences;
            inferenceIdx++) {
          averagedRawPredictions[labelIdx] +=
              allPredictions[inferenceIdx][labelIdx];
        }
        averagedRawPredictions[labelIdx] /= numInferences;
      }

      _logger.i('Averaged raw predictions: $averagedRawPredictions');

      final probabilities = _applySoftmax(averagedRawPredictions);

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

      // Get second prediction for comparison
      final secondPrediction = predictions.length > 1 ? predictions[1] : null;

      // Define confidence thresholds
      const double minConfidenceThreshold = 0.20; // 20%
      const double marginThreshold = 0.10; // 10% margin for clear winner

      // Check if it's a "normal" prediction
      if (topPrediction.key == 'normal') {
        // For normal prediction, check if there's a disease with reasonable confidence
        final diseasePredictions = predictions
            .where((pred) => pred.key != 'normal' && pred.value > 0.15)
            .toList();

        if (diseasePredictions.isNotEmpty) {
          // If there's a disease with reasonable confidence, return it instead
          _logger.i(
              'Found potential disease despite "normal" prediction: ${diseasePredictions.first.key}');
          return (diseasePredictions.first.key, diseasePredictions.first.value);
        }

        // Otherwise return normal if confidence is high enough
        if (topPrediction.value > 0.6) {
          return (topPrediction.key, topPrediction.value);
        } else {
          // If normal but low confidence, check second prediction
          return secondPrediction != null
              ? (secondPrediction.key, secondPrediction.value)
              : (topPrediction.key, topPrediction.value);
        }
      }

      // For disease predictions
      if (topPrediction.value < minConfidenceThreshold) {
        _logger.w(
            'Low confidence prediction: ${(topPrediction.value * 100).toStringAsFixed(2)}%');

        // Check if there are any disease predictions with reasonable confidence
        final diseasePredictions = predictions
            .where((pred) =>
                pred.key != 'normal' &&
                pred.key != 'uncertain' &&
                pred.value > 0.15)
            .toList();

        if (diseasePredictions.isNotEmpty) {
          _logger.i(
              'Found disease prediction with low confidence: ${diseasePredictions.first.key}');
          return (diseasePredictions.first.key, diseasePredictions.first.value);
        }

        // If no reasonable disease prediction, return uncertain
        return ('uncertain', topPrediction.value);
      }

      // Check if the top prediction is significantly better than the second
      if (secondPrediction != null &&
          (topPrediction.value - secondPrediction.value) < marginThreshold) {
        _logger.i(
            'Close predictions between ${topPrediction.key} and ${secondPrediction.key}');

        // If the second prediction is a disease and the first is normal, prefer the disease
        if (secondPrediction.key != 'normal' && topPrediction.key == 'normal') {
          return (secondPrediction.key, secondPrediction.value);
        }

        // Otherwise return the top prediction
        return (topPrediction.key, topPrediction.value);
      }

      // Return the top prediction
      return (topPrediction.key, topPrediction.value);
    } catch (e) {
      _logger.e('Error during classification', error: e);
      throw Exception('Classification failed: $e');
    }
  }

  // Apply softmax to convert raw model outputs to probabilities
  List<double> _applySoftmax(List<double> logits) {
    // Find the maximum value to prevent overflow
    final double maxLogit = logits.reduce((a, b) => a > b ? a : b);

    // Subtract max for numerical stability and apply exp
    final List<double> expValues =
        logits.map((logit) => math.exp(logit - maxLogit)).toList();

    // Calculate sum of all exp values
    final double sumExp = expValues.reduce((a, b) => a + b);

    // Normalize to get probabilities
    return expValues.map((exp) => exp / sumExp).toList();
  }

  void dispose() {
    if (_isInitialized) {
      try {
        _interpreter.close();
        _logger.i('ML Service disposed');
      } catch (e) {
        _logger.e('Error disposing ML Service', error: e);
      }
    }
  }
}
