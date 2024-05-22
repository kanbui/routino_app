import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static Database? _database;

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

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        totalWorkTime INTEGER NOT NULL,
        estimateTime INTEGER,
        dueTime TEXT,
        status TEXT NOT NULL,
        estimateTime INTEGER,
        dueTime TEXT
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
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    Database db = await database;
    return await db.query('tasks', orderBy: 'dueTime ASC, id ASC');
  }

  Future<int> insertTask(Map<String, dynamic> task) async {
    Database db = await database;
    return await db.insert('tasks', task);
  }

  Future<int> updateTask(Map<String, dynamic> task) async {
    Database db = await database;
    return await db
        .update('tasks', task, where: 'id = ?', whereArgs: [task['id']]);
  }

  Future<int> deleteTask(int id) async {
    Database db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getSubtasks(int parentId) async {
    Database db = await database;
    return await db
        .query('subtasks', where: 'parentTaskId = ?', whereArgs: [parentId]);
  }

  Future<int> insertSubtask(Map<String, dynamic> subtask) async {
    Database db = await database;
    return await db.insert('subtasks', subtask);
  }

  Future<int> updateSubtask(Map<String, dynamic> subtask) async {
    Database db = await database;
    return await db.update('subtasks', subtask,
        where: 'id = ?', whereArgs: [subtask['id']]);
  }

  Future<int> deleteSubtask(int id) async {
    Database db = await database;
    return await db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }
}
