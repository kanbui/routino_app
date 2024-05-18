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
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'pomodoro.db');

    return await openDatabase(
      path,
      version: 2, // Update the version to trigger onUpgrade
      onCreate: (db, version) {
        db.execute(
            "CREATE TABLE pomodoro(id INTEGER PRIMARY KEY, isWorking INTEGER, remainingTime INTEGER)");
        db.execute(
            "CREATE TABLE tasks(id INTEGER PRIMARY KEY, name TEXT, totalWorkTime INTEGER, status TEXT)");
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 2) {
          db.execute("ALTER TABLE tasks ADD COLUMN status TEXT");
          db.execute("UPDATE tasks SET status = 'doing'");
        }
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

  Future<void> insertTask(Map<String, dynamic> task) async {
    final db = await database;
    await db.insert('tasks', task,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    final db = await database;
    return await db.query('tasks');
  }

  Future<List<Map<String, dynamic>>> getTasksByStatus(String status) async {
    final db = await database;
    return await db.query('tasks', where: "status = ?", whereArgs: [status]);
  }

  Future<void> updateTask(Map<String, dynamic> task) async {
    final db = await database;
    await db.update('tasks', task, where: "id = ?", whereArgs: [task['id']]);
  }

  Future<void> updateTaskStatus(int id, String status) async {
    final db = await database;
    await db.update('tasks', {'status': status},
        where: "id = ?", whereArgs: [id]);
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('tasks', where: "id = ?", whereArgs: [id]);
  }
}
