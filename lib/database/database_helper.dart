import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'pomodoro.db');

    // In đường dẫn tệp cơ sở dữ liệu
    print("Database path: $path");
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'pomodoro.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE pomodoro(id INTEGER PRIMARY KEY, isWorking INTEGER, remainingTime INTEGER)",
        );
      },
    );
  }

  Future<void> insertPomodoro(Map<String, dynamic> pomodoro) async {
    final db = await database;
    await db.insert('pomodoro', pomodoro,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getPomodoro(int id) async {
    final db = await database;
    List<Map<String, dynamic>> maps =
        await db.query('pomodoro', where: "id = ?", whereArgs: [id]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> updatePomodoro(Map<String, dynamic> pomodoro) async {
    final db = await database;
    await db.update('pomodoro', pomodoro,
        where: "id = ?", whereArgs: [pomodoro['id']]);
  }

  Future<void> deletePomodoro(int id) async {
    final db = await database;
    await db.delete('pomodoro', where: "id = ?", whereArgs: [id]);
  }
}
