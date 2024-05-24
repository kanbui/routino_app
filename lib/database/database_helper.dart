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

    const int currentDatabaseVersion = 3;

    String folderName = isDevelopment ? 'development' : 'production';
    String path = join(documentsDirectory.path, 'routino_app_db', folderName,
        'routino_app.db');

    // Create the necessary directories if they don't exist
    await Directory(dirname(path)).create(recursive: true);

    print('Database path: $path'); // Print the database path

    return await openDatabase(path,
        version: currentDatabaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        totalWorkTime INTEGER NOT NULL,
        estimateTime INTEGER,
        dueTime TEXT,
        priority INTEGER,
        status TEXT NOT NULL
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
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        icon TEXT,
        content TEXT,
        task_id INTEGER,
        point INTEGER,
        createdAt TEXT,
        FOREIGN KEY(task_id) REFERENCES tasks(id)
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          icon TEXT,
          content TEXT,
          task_id INTEGER,
          point INTEGER,
          createdAt TEXT,
          FOREIGN KEY(task_id) REFERENCES tasks(id)
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE tasks ADD priority INTEGER;
      ''');
    }
  }

  Future<List<Map<String, dynamic>>> getTasks(String timeFilter) async {
    Database db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    DateTime now = DateTime.now();
    switch (timeFilter) {
      case 'today':
        whereClause = 'DATE(dueTime) = DATE(?)';
        whereArgs = [now.toIso8601String()];
        break;
      case 'tomorrow':
        DateTime tomorrow = now.add(Duration(days: 1));
        whereClause = 'DATE(dueTime) = DATE(?)';
        whereArgs = [tomorrow.toIso8601String()];
        break;
      case 'this_week':
        DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        DateTime endOfWeek = startOfWeek.add(Duration(days: 6));
        whereClause = 'DATE(dueTime) BETWEEN DATE(?) AND DATE(?)';
        whereArgs = [
          startOfWeek.toIso8601String(),
          endOfWeek.toIso8601String()
        ];
        break;
      case 'this_month':
        DateTime startOfMonth = DateTime(now.year, now.month, 1);
        DateTime endOfMonth = DateTime(now.year, now.month + 1, 0);
        whereClause = 'DATE(dueTime) BETWEEN DATE(?) AND DATE(?)';
        whereArgs = [
          startOfMonth.toIso8601String(),
          endOfMonth.toIso8601String()
        ];
        break;
      default:
        // No filter, get all tasks
        whereClause = '';
        whereArgs = [];
        break;
    }

    return await db.query(
      'tasks',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'DATE(dueTime) ASC, priority ASC, dueTime ASC',
    );
  }

  Future<Map<String, dynamic>> getTaskById(int taskId) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    );

    return result.first;
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

  // Thêm các hàm CRUD cho bảng notes

  Future<int> insertNote(Map<String, dynamic> note) async {
    Database db = await database;
    return await db.insert('notes', note);
  }

  Future<int> updateNote(Map<String, dynamic> note) async {
    Database db = await database;
    return await db
        .update('notes', note, where: 'id = ?', whereArgs: [note['id']]);
  }

  Future<int> deleteNote(int id) async {
    Database db = await database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getNotesByTaskId(int taskId) async {
    Database db = await database;
    return await db.query('notes',
        where: 'task_id = ?', orderBy: 'createdAt DESC', whereArgs: [taskId]);
  }
}
