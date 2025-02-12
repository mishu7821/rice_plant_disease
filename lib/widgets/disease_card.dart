import 'package:flutter/material.dart';
import 'package:rice_disease_classifier/services/disease_info_service.dart';

class DiseaseCard extends StatelessWidget {
  final String disease;
  final double confidence;

  const DiseaseCard({
    super.key,
    required this.disease,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final diseaseInfo = DiseaseInfoService.getInfo(disease);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  diseaseInfo?.name ?? disease,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${(confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (diseaseInfo != null) ...[
              const SizedBox(height: 8),
              Text(
                diseaseInfo.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                'Symptoms',
                diseaseInfo.symptoms,
                Icons.warning_rounded,
                colorScheme.error,
              ),
              const SizedBox(height: 12),
              _buildSection(
                context,
                'Treatment',
                diseaseInfo.treatment,
                Icons.healing_rounded,
                colorScheme.tertiary,
              ),
              const SizedBox(height: 12),
              _buildSection(
                context,
                'Prevention',
                diseaseInfo.prevention,
                Icons.shield_rounded,
                colorScheme.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
