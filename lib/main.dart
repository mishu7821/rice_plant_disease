import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rice_disease_classifier/providers/disease_classifier_provider.dart';
import 'package:rice_disease_classifier/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DiseaseClassifierProvider()),
      ],
      child: MaterialApp(
        title: 'Rice Disease Classifier',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
