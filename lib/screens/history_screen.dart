import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rice_disease_classifier/providers/disease_classifier_provider.dart';
import 'package:rice_disease_classifier/models/classification_record.dart';
import 'package:rice_disease_classifier/widgets/processed_image_view.dart';
import 'package:rice_disease_classifier/services/disease_info_service.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Set<int> _selectedItems = {};
  bool _isSelectionMode = false;
  final ScrollController _scrollController = ScrollController();
  List<ClassificationRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final provider =
        Provider.of<DiseaseClassifierProvider>(context, listen: false);
    _records = await provider.getHistory();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedItems.contains(id)) {
        _selectedItems.remove(id);
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItems.add(id);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _deleteSelected() async {
    try {
      final provider =
          Provider.of<DiseaseClassifierProvider>(context, listen: false);
      await provider.deleteRecords(_selectedItems.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected items deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Reload records after deletion
      await _loadRecords();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting items: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectedItems.clear();
          _isSelectionMode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode
            ? '${_selectedItems.length} selected'
            : 'Classification History'),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _selectedItems.isEmpty ? null : _deleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectedItems.clear();
                  _isSelectionMode = false;
                });
              },
            ),
          ],
        ],
      ),
      body: _buildHistoryList(),
    );
  }

  Widget _buildHistoryList() {
    if (_records.isEmpty) {
      return const Center(
        child: Text('No classification history yet'),
      );
    }

    return ListView.builder(
      key: const PageStorageKey('history_list'),
      controller: _scrollController,
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        final isSelected = _selectedItems.contains(record.id);
        final diseaseInfo = DiseaseInfoService.getInfo(record.prediction);

        if (diseaseInfo == null) return const SizedBox.shrink();

        return HistoryListItem(
          key: ValueKey(record.id),
          record: record,
          diseaseInfo: diseaseInfo,
          isSelected: isSelected,
          isSelectionMode: _isSelectionMode,
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(record.id!);
            } else {
              _showDiseaseDetails(diseaseInfo, record.confidence);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              _toggleSelection(record.id!);
            }
          },
        );
      },
    );
  }

  void _showDiseaseDetails(DiseaseInfo diseaseInfo, double confidence) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                diseaseInfo.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(diseaseInfo.description),
              const SizedBox(height: 16),
              Text(
                'Symptoms',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(diseaseInfo.symptoms),
              const SizedBox(height: 16),
              Text(
                'Treatment',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(diseaseInfo.treatment),
              const SizedBox(height: 16),
              Text(
                'Prevention',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(diseaseInfo.prevention),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryListItem extends StatelessWidget {
  final ClassificationRecord record;
  final DiseaseInfo diseaseInfo;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const HistoryListItem({
    super.key,
    required this.record,
    required this.diseaseInfo,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: ProcessedImageView(
                    imagePath: record.imagePath,
                    width: 80,
                    height: 80,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diseaseInfo.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Confidence: ${(record.confidence * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, y HH:mm').format(record.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
