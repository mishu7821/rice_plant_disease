class DiseaseInfo {
  final String name;
  final String description;
  final String symptoms;
  final String treatment;
  final String prevention;

  const DiseaseInfo({
    required this.name,
    required this.description,
    required this.symptoms,
    required this.treatment,
    required this.prevention,
  });
}

class DiseaseInfoService {
  static final Map<String, DiseaseInfo> _diseaseInfo = {
    'bacterial_leaf_blight': const DiseaseInfo(
      name: 'Bacterial Leaf Blight',
      description:
          'A serious bacterial disease caused by Xanthomonas oryzae pv. oryzae.',
      symptoms:
          '• Water-soaked lesions on leaf edges\n• Yellow to white striping\n• Lesions turn grayish-white\n• Wilting of seedlings',
      treatment:
          '• Remove infected plants\n• Apply copper-based bactericides\n• Drain fields\n• Maintain proper spacing',
      prevention:
          '• Use resistant varieties\n• Clean field equipment\n• Balanced fertilization\n• Proper water management',
    ),
    'bacterial_leaf_streak': const DiseaseInfo(
      name: 'Bacterial Leaf Streak',
      description:
          'A bacterial disease caused by Xanthomonas oryzae pv. oryzicola.',
      symptoms:
          '• Narrow, dark brown streaks\n• Translucent leaf lesions\n• Yellow bacterial ooze\n• Interveinal streaking',
      treatment:
          '• Apply appropriate bactericides\n• Remove infected plants\n• Improve field drainage\n• Adjust pH levels',
      prevention:
          '• Use certified seeds\n• Crop rotation\n• Proper field sanitation\n• Avoid overhead irrigation',
    ),
    'bacterial_panicle_blight': const DiseaseInfo(
      name: 'Bacterial Panicle Blight',
      description:
          'A bacterial disease affecting rice panicles, caused by Burkholderia glumae.',
      symptoms:
          '• Discolored panicles\n• Unfilled grains\n• Brown lesions on grain\n• Panicle sterility',
      treatment:
          '• Remove affected panicles\n• Apply copper-based products\n• Improve air circulation\n• Manage water properly',
      prevention:
          '• Use resistant cultivars\n• Proper spacing\n• Avoid excessive nitrogen\n• Time planting appropriately',
    ),
    'blast': const DiseaseInfo(
      name: 'Rice Blast',
      description: 'A devastating fungal disease caused by Magnaporthe oryzae.',
      symptoms:
          '• Diamond-shaped lesions\n• White to gray center spots\n• Neck rot\n• Panicle blanking',
      treatment:
          '• Apply fungicides\n• Remove infected plants\n• Improve drainage\n• Balance nutrients',
      prevention:
          '• Plant resistant varieties\n• Avoid dense seeding\n• Monitor humidity\n• Time planting properly',
    ),
    'brown_spot': const DiseaseInfo(
      name: 'Brown Spot',
      description: 'A fungal disease caused by Cochliobolus miyabeanus.',
      symptoms:
          '• Oval brown lesions\n• Dark brown spots\n• Infected seeds\n• Yellowing leaves',
      treatment:
          '• Apply fungicides\n• Remove debris\n• Improve soil fertility\n• Proper water management',
      prevention:
          '• Use healthy seeds\n• Balanced nutrition\n• Proper spacing\n• Soil management',
    ),
    'dead_heart': const DiseaseInfo(
      name: 'Dead Heart',
      description: 'A condition caused by stem borer infestation.',
      symptoms:
          '• Central leaf whorl withering\n• Dead tillers\n• Hollow stems\n• Whitish patches',
      treatment:
          '• Apply appropriate insecticides\n• Remove affected tillers\n• Use light traps\n• Biological control',
      prevention:
          '• Early planting\n• Crop rotation\n• Field sanitation\n• Monitor pest levels',
    ),
    'downy_mildew': const DiseaseInfo(
      name: 'Downy Mildew',
      description: 'A fungal disease caused by Sclerophthora macrospora.',
      symptoms:
          '• White to yellow spots\n• Downy growth underneath\n• Twisted leaves\n• Stunted growth',
      treatment:
          '• Apply fungicides\n• Improve ventilation\n• Remove infected parts\n• Manage irrigation',
      prevention:
          '• Use resistant varieties\n• Proper spacing\n• Avoid overhead irrigation\n• Field sanitation',
    ),
    'hispa': const DiseaseInfo(
      name: 'Rice Hispa',
      description:
          'An insect pest (Dicladispa armigera) that damages rice leaves.',
      symptoms:
          '• Scrapped patches on leaves\n• White streaks\n• Mines in leaves\n• Skeletonized leaves',
      treatment:
          '• Apply insecticides\n• Remove egg masses\n• Use light traps\n• Biological control',
      prevention:
          '• Early planting\n• Crop rotation\n• Remove alternative hosts\n• Monitor pest levels',
    ),
    'normal': const DiseaseInfo(
      name: 'Healthy Plant',
      description: 'The plant shows no signs of disease or pest damage.',
      symptoms: 'No disease symptoms present',
      treatment: 'No treatment needed',
      prevention:
          '• Regular monitoring\n• Good agricultural practices\n• Balanced fertilization\n• Proper irrigation',
    ),
    'tungro': const DiseaseInfo(
      name: 'Rice Tungro',
      description: 'A viral disease transmitted by green leafhoppers.',
      symptoms:
          '• Yellow-orange leaves\n• Stunted growth\n• Reduced tillering\n• Delayed flowering',
      treatment:
          '• Remove infected plants\n• Control vectors\n• Use virus-free seedlings\n• Roguing',
      prevention:
          '• Use resistant varieties\n• Early planting\n• Vector management\n• Synchronous planting',
    ),
  };

  static DiseaseInfo? getInfo(String diseaseName) {
    return _diseaseInfo[diseaseName];
  }

  static List<String> getAllLabels() {
    return _diseaseInfo.keys.toList();
  }
}
