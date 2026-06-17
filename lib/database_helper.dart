import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

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
    version: 4,
    onCreate: _createDB,
    onUpgrade: (db, oldVersion, newVersion) async {
  final columns = await db.rawQuery("PRAGMA table_info(tasks)");
  final columnNames = columns.map((c) => c['name']).toList();

  if (!columnNames.contains('repeat')) {
    await db.execute(
      "ALTER TABLE tasks ADD COLUMN repeat TEXT;",
    );
  }

  if (!columnNames.contains('repeatWeekly')) {
    await db.execute(
      "ALTER TABLE tasks ADD COLUMN repeatWeekly INTEGER NOT NULL DEFAULT 0;",
    );
  }

  if (!columnNames.contains('notificationDaysBefore')) {
    await db.execute(
      "ALTER TABLE tasks ADD COLUMN notificationDaysBefore INTEGER NOT NULL DEFAULT 1;",
    );
  }  
  },   
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
        isDone INTEGER NOT NULL,
        memo TEXT,
        repeat TEXT,
        repeatWeekly INTEGER NOT NULL DEFAULT 0,
        notificationDaysBefore INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        daysBefore INTEGER NOT NULL,
        time TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        notificationId INTEGER,
        FOREIGN KEY (taskId) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
  }

  // INSERT
  Future<int> insertTask(Map<String, dynamic> task) async {
    final db = await instance.database;

    task.remove('id');
    return await db.insert('tasks', task);
  }

  // REMINDERS CRUD
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    final db = await instance.database;
    reminder.remove('id');
    return await db.insert('reminders', reminder);
  }

  Future<List<Map<String, dynamic>>> getRemindersForTask(int taskId) async {
    final db = await instance.database;
    return await db.query(
      'reminders',
      where: 'taskId = ?',
      whereArgs: [taskId],
      orderBy: 'daysBefore ASC, time ASC',
    );
  }

  Future<int> updateReminder(Map<String, dynamic> reminder) async {
    final db = await instance.database;
    return await db.update(
      'reminders',
      {
        'taskId': reminder['taskId'],
        'daysBefore': reminder['daysBefore'],
        'time': reminder['time'],
        'enabled': reminder['enabled'],
        'notificationId': reminder['notificationId'],
      },
      where: 'id = ?',
      whereArgs: [reminder['id']],
    );
  }

  Future<int> deleteRemindersByTaskId(int taskId) async {
    final db = await instance.database;
    return await db.delete(
      'reminders',
      where: 'taskId = ?',
      whereArgs: [taskId],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await instance.database;
    return await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // SELECT
  Future<List<Map<String, dynamic>>> getTasks() async {
    final db = await instance.database;
    return await db.query(
      'tasks',
      orderBy: 'isDone ASC, deadline ASC'
      );
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
        'memo': task['memo'],
        'repeat': task['repeat'],
        'repeatWeekly': task['repeatWeekly'], 
        'notificationDaysBefore': task['notificationDaysBefore'],
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

  Future<void> deleteWeeklyChildren(String title) async {
    final db = await instance.database;
    await db.delete(
      'tasks',
      where: 'title = ? AND repeat = ?',
      whereArgs: [title, 'weekly'],
  );
}

Future<Map<String, dynamic>?> getTaskById(int id) async {
  final db = await instance.database;
  final result = await db.query(
    'tasks',
    where: 'id = ?',
    whereArgs: [id],
  );
  return result.isNotEmpty ? result.first : null;
}



Future<void> generateWeeklyTasks() async {
  final dbTasks = await getTasks();
  final tasksCopy = List<Map<String, dynamic>>.from(dbTasks);

  final now = DateTime.now();
  final endDate = now.add(const Duration(days: 90));

  final List<Map<String, dynamic>> newTasks = [];

  for (var task in tasksCopy) {
  if ((task['repeatWeekly'] ?? 0) != 1) continue;
  if (task['repeat'] == 'weekly') continue;

  DateTime deadline = DateTime.parse(task['deadline']);
  
    while (deadline.isBefore(endDate)) {
      final next = deadline.add(const Duration(days: 7));
      
      final exists = [
        ...tasksCopy,
        ...newTasks,
      ].any((t) {
        if (t['title'] != task['title']) return false;

        final d = DateTime.parse(t['deadline']);
        return d.year == next.year &&
               d.month == next.month &&
               d.day == next.day;
      });

      if (!exists) {
        final formatted = DateFormat('yyyy-MM-dd HH:mm').format(next);

        newTasks.add({
          'title': task['title'],
          'subject': task['subject'],
          'deadline': formatted,
          'memo': task['memo'],
          'notificationId': next.hashCode,
          'isDone': 0,
          'repeat': 'weekly',
          'repeatWeekly': 0,
          'notificationDaysBefore': task['notificationDaysBefore'] ?? 1,
        });
      }

      deadline = next;
    }
  }

  for (var t in newTasks) {
    await insertTask(t);
  }
}

}