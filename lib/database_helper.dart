import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        subject TEXT NOT NULL,
        deadline TEXT NOT NULL,
        notificationId INTEGER NOT NULL,
        isDone INTEGER NOT NULL
      )
    ''');
  }

  // INSERT
  Future<int> insertTask(Map<String, dynamic> task) async {
    final db = await instance.database;
    return await db.insert('tasks', task);
  }

  // SELECT
  Future<List<Map<String, dynamic>>> getTasks() async {
    final db = await instance.database;
    return await db.query('tasks');
  }

  // UPDATE
  Future<int> updateTask(Map<String, dynamic> task) async {
    final db = await instance.database;
    return await db.update(
      'tasks',
      {
        'title': task['title'],
        'subject': task['subject'],
        'deadline': task['deadline'],
        'notificationId': task['notificationId'],
        'isDone': task['isDone'],
      },
      where: 'id = ?',
      whereArgs: [task['id']],
    );
  }

  // DELETE
  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}