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

      // Resize image
      final processedImage = img.copyResize(
        image,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      // Save processed image
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(imagePath);
      final processedPath = path.join(tempDir.path, 'processed_$fileName');

      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(img.encodeJpg(processedImage));

      return processedPath;
    } catch (e) {
      throw Exception('Failed to process image: $e');
    }
  }
}
