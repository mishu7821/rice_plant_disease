import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageProcessingService {
  static const int targetSize = 224; // Standard input size for MobileNetV3

  Future<String> preprocessImage(String imagePath) async {
    try {
      // Read image
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Enhanced preprocessing for disease recognition
      // First resize image with high-quality interpolation
      var processedImage = img.copyResize(
        image,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.cubic,
      );

      // Apply adaptive image enhancement based on image statistics
      processedImage = _adaptiveEnhancement(processedImage);

      // Apply advanced edge enhancement
      processedImage = _enhanceEdgesAdvanced(processedImage);

      // Save processed image
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(imagePath);
      final processedPath = path.join(tempDir.path, 'processed_$fileName');

      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(
          img.encodeJpg(processedImage, quality: 100)); // Use maximum quality

      return processedPath;
    } catch (e) {
      throw Exception('Failed to process image: $e');
    }
  }

  // Adaptive enhancement based on image statistics
  img.Image _adaptiveEnhancement(img.Image image) {
    // Calculate image statistics
    int totalPixels = image.width * image.height;
    double sumR = 0, sumG = 0, sumB = 0;
    int minR = 255, minG = 255, minB = 255;
    int maxR = 0, maxG = 0, maxB = 0;

    // Sample pixels to calculate statistics (every 5th pixel for performance)
    for (int y = 0; y < image.height; y += 5) {
      for (int x = 0; x < image.width; x += 5) {
        final pixel = image.getPixel(x, y);

        // Update sums
        sumR += pixel.r.toDouble();
        sumG += pixel.g.toDouble();
        sumB += pixel.b.toDouble();

        // Update min/max
        if (pixel.r < minR) minR = pixel.r.toInt();
        if (pixel.g < minG) minG = pixel.g.toInt();
        if (pixel.b < minB) minB = pixel.b.toInt();

        if (pixel.r > maxR) maxR = pixel.r.toInt();
        if (pixel.g > maxG) maxG = pixel.g.toInt();
        if (pixel.b > maxB) maxB = pixel.b.toInt();
      }
    }

    // Calculate average values
    double avgR = sumR / (totalPixels / 25); // Adjusted for sampling
    double avgG = sumG / (totalPixels / 25);
    double avgB = sumB / (totalPixels / 25);

    // Calculate dynamic range
    double rangeR = (maxR - minR).toDouble();
    double rangeG = (maxG - minG).toDouble();
    double rangeB = (maxB - minB).toDouble();

    // Determine adaptive parameters based on image statistics
    double contrastFactor = 1.0;
    double brightnessFactor = 1.0;
    double saturationFactor = 1.0;

    // Low contrast image needs more contrast enhancement
    if ((rangeR < 100) || (rangeG < 100) || (rangeB < 100)) {
      contrastFactor = 1.5;
    } else {
      contrastFactor = 1.2;
    }

    // Dark image needs brightness boost
    if ((avgR < 100) || (avgG < 100) || (avgB < 100)) {
      brightnessFactor = 1.2;
    }

    // Low saturation (close RGB values) needs saturation boost
    double rgbVariance =
        ((avgR - avgG).abs() + (avgR - avgB).abs() + (avgG - avgB).abs()) / 3;
    if (rgbVariance < 20) {
      saturationFactor = 1.4;
    } else {
      saturationFactor = 1.2;
    }

    // Apply the adaptive enhancement
    return img.adjustColor(
      image,
      contrast: contrastFactor,
      brightness: brightnessFactor,
      saturation: saturationFactor,
    );
  }

  // Advanced edge enhancement with disease-specific optimizations
  img.Image _enhanceEdgesAdvanced(img.Image image) {
    // Create a copy of the image to work with
    final result = img.Image.from(image);

    // Skip the border pixels to avoid index out of range errors
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        // Get the center pixel and surrounding pixels
        final center = image.getPixel(x, y);
        final top = image.getPixel(x, y - 1);
        final bottom = image.getPixel(x, y + 1);
        final left = image.getPixel(x - 1, y);
        final right = image.getPixel(x + 1, y);

        // Get diagonal pixels for better edge detection
        final topLeft = image.getPixel(x - 1, y - 1);
        final topRight = image.getPixel(x + 1, y - 1);
        final bottomLeft = image.getPixel(x - 1, y + 1);
        final bottomRight = image.getPixel(x + 1, y + 1);

        // Calculate the enhanced values for each channel with improved algorithm
        final enhancedR = _enhanceChannelAdvanced(
            center.r.toInt(),
            top.r.toInt(),
            bottom.r.toInt(),
            left.r.toInt(),
            right.r.toInt(),
            topLeft.r.toInt(),
            topRight.r.toInt(),
            bottomLeft.r.toInt(),
            bottomRight.r.toInt());

        final enhancedG = _enhanceChannelAdvanced(
            center.g.toInt(),
            top.g.toInt(),
            bottom.g.toInt(),
            left.g.toInt(),
            right.g.toInt(),
            topLeft.g.toInt(),
            topRight.g.toInt(),
            bottomLeft.g.toInt(),
            bottomRight.g.toInt());

        final enhancedB = _enhanceChannelAdvanced(
            center.b.toInt(),
            top.b.toInt(),
            bottom.b.toInt(),
            left.b.toInt(),
            right.b.toInt(),
            topLeft.b.toInt(),
            topRight.b.toInt(),
            bottomLeft.b.toInt(),
            bottomRight.b.toInt());

        // Set the enhanced pixel in the result image
        result.setPixel(x, y, img.ColorRgb8(enhancedR, enhancedG, enhancedB));
      }
    }

    return result;
  }

  // Advanced channel enhancement with diagonal pixels and improved weighting
  int _enhanceChannelAdvanced(int center, int top, int bottom, int left,
      int right, int topLeft, int topRight, int bottomLeft, int bottomRight) {
    // Calculate the edge response with improved kernel
    final double edge = (center * 5.0) -
        (top * 1.0) -
        (bottom * 1.0) -
        (left * 1.0) -
        (right * 1.0) -
        (topLeft * 0.5) -
        (topRight * 0.5) -
        (bottomLeft * 0.5) -
        (bottomRight * 0.5);

    // Adaptive enhancement factor based on edge strength
    double enhancementFactor = 0.5; // Default enhancement factor
    if (edge.abs() > 100) {
      // Strong edge - enhance more
      enhancementFactor = 0.7;
    } else if (edge.abs() < 30) {
      // Weak edge - enhance less
      enhancementFactor = 0.3;
    }

    // Enhance the center value by adding a portion of the edge response
    final enhanced = center + (edge * enhancementFactor).round();

    // Clamp the result to valid color range [0-255]
    return enhanced.clamp(0, 255);
  }
}
