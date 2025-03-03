import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:rice_disease_classifier/providers/disease_classifier_provider.dart';
import 'package:rice_disease_classifier/screens/splash_screen.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Enable performance monitoring in debug mode
    if (kDebugMode) {
      debugPrintRebuildDirtyWidgets = true;
    }

    // Set error handler for uncaught errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.toString()}');
    };

    // Handle errors that occur during initialization
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'An error occurred: ${details.exception}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    };

    // Add memory pressure listener
    WidgetsBinding.instance.addObserver(
      MemoryPressureObserver(onMemoryPressure: () {
        debugPrint('Memory pressure detected - cleaning up resources');
        imageCache.clear();
        imageCache.clearLiveImages();
      }),
    );

    runApp(const MyApp());
  } catch (e, stackTrace) {
    debugPrint('Error during initialization: $e\n$stackTrace');
    rethrow;
  }
}

class MemoryPressureObserver extends WidgetsBindingObserver {
  MemoryPressureObserver({required this.onMemoryPressure});

  final VoidCallback onMemoryPressure;

  @override
  void didHaveMemoryPressure() {
    onMemoryPressure();
  }
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
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          platform: defaultTargetPlatform,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          platform: defaultTargetPlatform,
        ),
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
        builder: (context, child) {
          // Add error boundary widget
          ErrorWidget.builder = (FlutterErrorDetails details) {
            return Material(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'An error occurred',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.red,
                          ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 8),
                      Text(
                        details.exception.toString(),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            );
          };

          // Enable performance optimizations
          if (child != null) {
            return MediaQuery(
              // Optimize MediaQuery rebuilds
              data: MediaQuery.of(context).copyWith(
                platformBrightness: MediaQuery.platformBrightnessOf(context),
                textScaler: TextScaler.linear(1.0),
              ),
              child: child,
            );
          }
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}
