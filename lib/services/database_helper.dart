import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:rice_disease_classifier/models/classification_record.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'rice_disease.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE classification_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT,
            prediction TEXT,
            confidence REAL,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertClassification({
    required String imagePath,
    required String disease,
    required double confidence,
  }) async {
    final db = await database;
    return await db.insert(
      'classification_records',
      {
        'image_path': imagePath,
        'prediction': disease,
        'confidence': confidence,
        'timestamp': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ClassificationRecord>> getRecords() async {
    final db = await database;
    final maps = await db.query(
      'classification_records',
      orderBy: 'timestamp DESC',
    );
    return List.generate(
        maps.length, (i) => ClassificationRecord.fromMap(maps[i]));
  }

  Future<void> deleteRecord(int id) async {
    final db = await database;
    await db.delete(
      'classification_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
