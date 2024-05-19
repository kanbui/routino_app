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
    // Determine the environment
    bool isDevelopment = const bool.fromEnvironment('dart.vm.product') == false;
    String folderName = isDevelopment ? 'development' : 'production';
    String path = join(documentsDirectory.path, 'routino_app_db', folderName,
        'routino_app.db');
    // Create the necessary directories if they don't exist
    await Directory(dirname(path)).create(recursive: true);
    print('Database path: $path'); // Print the database path

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
        await db.execute('''
          CREATE TABLE subtasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            parentTaskId INTEGER,
            name TEXT,
            totalWorkTime INTEGER DEFAULT 0,
            status TEXT,
            FOREIGN KEY (parentTaskId) REFERENCES tasks (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    Database db = await database;
    return await db.query('tasks');
  }

  Future<List<Map<String, dynamic>>> getSubtasks(int parentTaskId) async {
    Database db = await database;
    return await db.query('subtasks',
        where: 'parentTaskId = ?', whereArgs: [parentTaskId]);
  }

  Future<void> insertTask(Map<String, dynamic> task) async {
    Database db = await database;
    await db.insert('tasks', task);
  }

  Future<void> insertSubtask(Map<String, dynamic> subtask) async {
    Database db = await database;
    await db.insert('subtasks', subtask);
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

  Future<void> updateSubtask(Map<String, dynamic> subtask) async {
    Database db = await database;
    await db.update(
      'subtasks',
      subtask,
      where: 'id = ?',
      whereArgs: [subtask['id']],
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

  Future<void> deleteSubtask(int id) async {
    Database db = await database;
    await db.delete(
      'subtasks',
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
