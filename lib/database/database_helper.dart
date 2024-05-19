import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
    String path = join(documentsDirectory.path, 'routino_app.db');
    print('Database path: $path'); // In đường dẫn tới DB
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            totalWorkTime INTEGER DEFAULT 0,
            status TEXT
          )
        ''');
      },
    );
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    Database db = await database;
    return await db.query('tasks');
  }

  Future<void> insertTask(Map<String, dynamic> task) async {
    Database db = await database;
    await db.insert('tasks', task);
  }

  Future<void> updateTask(Map<String, dynamic> task) async {
    Database db = await database;
    await db.update(
      'tasks',
      task,
      where: 'id = ?',
      whereArgs: [task['id']],
    );
  }

  Future<void> deleteTask(int id) async {
    Database db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getTasksByStatus(String status) async {
    final db = await database;
    return await db.query('tasks', where: "status = ?", whereArgs: [status]);
  }

  Future<void> updateTaskStatus(int id, String status) async {
    final db = await database;
    await db.update('tasks', {'status': status},
        where: "id = ?", whereArgs: [id]);
  }
}
