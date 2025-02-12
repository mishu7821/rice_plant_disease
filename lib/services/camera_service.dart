import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

/// A simplified camera service that handles image capture and gallery selection
class CameraService {
  final ImagePicker _picker = ImagePicker();
  final _logger = Logger();

  /// Captures an image using the system camera with optimized settings
  Future<String?> captureImage() async {
    try {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        _logger.w('Camera permission denied');
        throw Exception('Camera permission is required');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 640, // Reduced for better performance
        maxHeight: 640, // Reduced for better performance
        imageQuality: 85, // Slightly reduced quality for better performance
        preferredCameraDevice: CameraDevice.rear, // Prefer rear camera
      );

      if (image != null) {
        _logger.i('Image captured: ${image.path}');
      }
      return image?.path;
    } catch (e) {
      _logger.e('Failed to capture image', error: e);
      throw Exception('Failed to capture image: $e');
    }
  }

  /// Picks an image from the gallery with optimized settings
  Future<String?> pickImageFromGallery() async {
    try {
      final photosStatus = await Permission.photos.request();
      if (!photosStatus.isGranted) {
        _logger.w('Gallery permission denied');
        throw Exception('Gallery permission is required');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 640, // Reduced for better performance
        maxHeight: 640, // Reduced for better performance
        imageQuality: 85, // Slightly reduced quality for better performance
      );

      if (image != null) {
        _logger.i('Image selected from gallery: ${image.path}');
      }
      return image?.path;
    } catch (e) {
      _logger.e('Failed to pick image from gallery', error: e);
      throw Exception('Failed to pick image from gallery: $e');
    }
  }
}
