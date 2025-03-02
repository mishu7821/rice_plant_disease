import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rice_disease_classifier/providers/disease_classifier_provider.dart';
import 'package:rice_disease_classifier/services/camera_service.dart';
import 'package:rice_disease_classifier/widgets/processed_image_view.dart';
import 'package:rice_disease_classifier/screens/history_screen.dart';
import 'package:rice_disease_classifier/widgets/loading_overlay.dart';
import 'package:rice_disease_classifier/widgets/camera_button.dart';
import 'package:rice_disease_classifier/widgets/disease_card.dart';
import 'package:rice_disease_classifier/services/error_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _handleGalleryImage() async {
    if (!mounted) return;

    final provider =
        Provider.of<DiseaseClassifierProvider>(context, listen: false);
    try {
      final cameraService = CameraService();
      final imagePath = await cameraService.pickImageFromGallery();

      if (!mounted) return;
      if (imagePath != null) {
        await provider.classifyImage(imagePath);
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, ErrorHandler.getErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DiseaseClassifierProvider>(
      builder: (context, provider, child) {
        return LoadingOverlay(
          isLoading: provider.isProcessing,
          message: 'Processing image...',
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Rice Disease Classifier'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoryScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (provider.processedImagePath != null) ...[
                    ProcessedImageView(
                      imagePath: provider.processedImagePath!,
                      width: double.infinity,
                      height: 300,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (provider.result != null && provider.confidence != null)
                    DiseaseCard(
                      disease: provider.result!,
                      confidence: provider.confidence!,
                      diseaseInfo: provider.currentDiseaseInfo,
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Take or select a photo of a rice plant to classify diseases',
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  CameraButton(
                    onPressed: () async {
                      if (!mounted) return;

                      final provider = Provider.of<DiseaseClassifierProvider>(
                          context,
                          listen: false);
                      try {
                        final cameraService = CameraService();
                        final imagePath = await cameraService.captureImage();
                        if (!mounted) return;

                        if (imagePath != null) {
                          await provider.classifyImage(imagePath);
                        }
                      } catch (e) {
                        if (!mounted) return;
                        if (context.mounted) {
                          ErrorHandler.showError(
                              context, ErrorHandler.getErrorMessage(e));
                        }
                      }
                    },
                    icon: Icons.camera_alt,
                    label: 'Take Photo',
                  ),
                  const SizedBox(height: 12),
                  CameraButton(
                    onPressed: _handleGalleryImage,
                    icon: Icons.photo_library,
                    label: 'Choose from Gallery',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
