import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:task_manager/calendar_page.dart';
import 'package:task_manager/database_helper.dart';
import 'add_task_page.dart';
import 'notification_service.dart';








// Notifications are handled by `NotificationService`.

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja_JP', null);
  await NotificationService.initialize();
  runApp(const TaskApp());
}

class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '課題管理アプリ',
      theme: ThemeData(
        primarySwatch: Colors.indigo, 
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.white,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.all(Colors.white),
        )
        ),
      home: const TaskListPage(),
    );
  }
}

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
   Map<int, bool> animating = {};
   List<Map<String, dynamic>> tasks = [];
   String searchQuery = '';

  @override
   void initState() {
    super.initState();
    loadTasksFromDB(); 
   }

@override
    void didChangeDependencies() {
      super.didChangeDependencies();
    }
  
   Future<void> loadTasksFromDB() async {
  final dbTasks = await DatabaseHelper.instance.getTasks();

  setState(() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final sevenDaysLater = today.add(const Duration(days: 7));

  tasks = dbTasks.where((t) {
    final repeat = t['repeat']?.toString() ?? 'none';

    if (repeat != 'weekly') return true;

    final deadline = DateFormat('yyyy-MM-dd HH:mm').parse(t['deadline']);
    final taskDay = DateTime(deadline.year, deadline.month, deadline.day);

    return !taskDay.isBefore(today) && !taskDay.isAfter(sevenDaysLater);
  }).toList();
});
}

  


    Future<void> addTaskToDB(Map<String,dynamic> task) async {
  final reminders = (task['reminders'] as List?) ?? [];
  task.remove('reminders');

  final newId = await DatabaseHelper.instance.insertTask(task);

  // persist reminders if any
  if (reminders.isNotEmpty) {
    for (var r in reminders) {
      await DatabaseHelper.instance.insertReminder({
        'taskId': newId,
        'daysBefore': r['daysBefore'],
        'time': r['time'],
        'enabled': r['enabled'] ?? 1,
        'notificationId': r['notificationId'],
      });
    }
  }
    else {
      // If no detailed reminders provided, migrate single notificationDaysBefore into reminders
      final daysBefore = task['notificationDaysBefore'];
      if (daysBefore != null && daysBefore != -1) {
        final nid = newId * 1000 + 0;
        await DatabaseHelper.instance.insertReminder({
          'taskId': newId,
          'daysBefore': daysBefore,
          'time': null,
          'enabled': 1,
          'notificationId': nid,
        });
      }
    }

  final taskWithId = {...task, 'id': newId};
  await NotificationService.scheduleTaskNotification(taskWithId);

  if (task['repeatWeekly'] == 1) {
    await DatabaseHelper.instance.generateWeeklyTasks();
  }

  await loadTasksFromDB();
}

    Future<void> updateTaskInDB(Map<String, dynamic> task) async{
      final reminders = (task['reminders'] as List?) ?? [];

      await DatabaseHelper.instance.updateTask(task);

      // cancel existing notifications (task + reminders)
      await NotificationService.cancelTaskNotification(task);
      await NotificationService.cancelRemindersForTask(task);

      // replace reminders: remove existing then insert provided list,
      // if no detailed reminders provided, migrate notificationDaysBefore into a single reminder
      await DatabaseHelper.instance.deleteRemindersByTaskId(task['id']);

      if (reminders.isNotEmpty) {
        for (var r in reminders) {
          await DatabaseHelper.instance.insertReminder({
            'taskId': task['id'],
            'daysBefore': r['daysBefore'],
            'time': r['time'],
            'enabled': r['enabled'] ?? 1,
            'notificationId': r['notificationId'],
          });
        }
      } else {
        final daysBefore = task['notificationDaysBefore'];
        if (daysBefore != null && daysBefore != -1) {
          final nid = task['id'] * 1000 + 0;
          await DatabaseHelper.instance.insertReminder({
            'taskId': task['id'],
            'daysBefore': daysBefore,
            'time': null,
            'enabled': 1,
            'notificationId': nid,
          });
        }
      }

      if (task['isDone'] == 0) {
        await NotificationService.scheduleTaskNotification(task);
      }

      await DatabaseHelper.instance.generateWeeklyTasks();

      await loadTasksFromDB();
      setState(() {});
    }

    Future<void> deleteTaskFromDB(int id) async {
      final task = await DatabaseHelper.instance.getTaskById(id);
      if (task != null) {
        await NotificationService.cancelTaskNotification(task);
        await NotificationService.cancelRemindersForTask(task);
      }
      await DatabaseHelper.instance.deleteRemindersByTaskId(id);
      await DatabaseHelper.instance.deleteTask(id);
      await loadTasksFromDB();
    }

  // Notification scheduling now handled by NotificationService.

  int daysLeft(String deadlineString) {
    try {
      final deadline = DateTime.parse(deadlineString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return deadline.difference(today).inDays;
    } catch (_) {
      return 0;
    }
      }

      String deadlineLabel(String deadlineString) {
  final left = daysLeft(deadlineString);

  if (left < 0) {
    return '${left.abs()}日遅れ';
  }

  if (left == 0) {
    return '今日まで';
  }

  if (left == 1) {
    return '明日まで';
  }

  return 'あと $left 日';
}

  Widget buildAnimatedTaskCard(Map<String, dynamic> task) {
  return TweenAnimationBuilder(
    tween: Tween<double>(begin: 0.8, end: 1.0),
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Transform.scale(
          scale: value,
          child: child,
        ),
      );
    },
    child: buildTaskCard(task), 
  );
}

  
  Widget buildTaskCard(Map<String, dynamic> task) {
  final isDone = task['isDone'] == 1;
  final int leftDays = daysLeft(task['deadline']);

  return Card(
    elevation: 3,
    color: isDone
    ? Colors.grey[300]
    : leftDays < 0
      ? Colors.deepPurple[100]
      : leftDays <= 3
        ? Colors.red[100]
        : Colors.white, 
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
  onTap: () async {
  final original = await DatabaseHelper.instance.getTaskById(task['id']);
  if (original == null) return;

  final result = await Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (_) => AddTaskPage(task: original),
    ),
  );

  if (result == "deleted") {
    await loadTasksFromDB();
    return;
  }

  if (result is Map<String, dynamic>) {
  await updateTaskInDB(result);
}
},
  

      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              width:6,
              height:60,
              decoration: BoxDecoration(
                color: isDone
                  ? Colors.grey[300]
                 : leftDays < 0
                   ? Colors.deepPurple
                  : leftDays <= 3
                    ? Colors.red
                    : Colors.blueGrey,
                borderRadius:BorderRadius.circular(4),
              ),
            ),

            const SizedBox(width: 12),
            GestureDetector(
              onTap: () async {
                setState(() {
                animating[task['id']] = true;
                });

              await Future.delayed(const Duration(milliseconds: 80));

              setState(() {
               animating[task['id']] = false;
              });

              final updatedTask = {
                ...task,
                'isDone': isDone ? 0 : 1,
              };

              await updateTaskInDB(updatedTask);
            },
            child: AnimatedScale(
              scale: animating[task['id']] == true ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isDone ? Colors.green : Colors.grey,
                size: 28,
             ),
            ),
           ),


            const SizedBox(width: 16),
            Expanded(
              child: Opacity(
                opacity: isDone ? 0.5 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['title'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task['subject'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          task['deadline'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                   const SizedBox(height: 4),

                  Text(
                   deadlineLabel(task['deadline']),
                   style: TextStyle(
                     fontSize: 13,
                     color: daysLeft(task['deadline']) < 0
                         ? Colors.deepPurple
                         : Colors.redAccent,
                     fontWeight: FontWeight.bold,
                    ),
                   ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {

    final filteredTasks = tasks.where((task) {
         final title = task['title'].toString();
         final subject = task['subject']?.toString() ?? '';
         final q = searchQuery.trim().toLowerCase();
         if (q.isEmpty) return true;
         return title.toLowerCase().contains(q) || subject.toLowerCase().contains(q);
       }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('課題一覧'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child:Padding(
            padding:const EdgeInsets.all(8.0),
            child:TextField(
              decoration: const InputDecoration(
                hintText: '検索(タイトル / 科目)',
                prefixIcon: Icon(Icons.search),
               border: OutlineInputBorder(),
               filled: true,
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              }            
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed:() async {
              await Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => const CalendarPage()
                  ),
                );

                await loadTasksFromDB();
                setState(() {});
              }, 
            ),
        ],
      ),

    

      body: ListView.builder(
        itemCount: filteredTasks.length,
        itemBuilder: (context, index) {
          final task = filteredTasks[index];
          return Dismissible(
            key: ValueKey(task['id']),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.indigo),
            ),
            onDismissed: (direction) async {
              await deleteTaskFromDB(task['id']);
            },
            
            child: buildAnimatedTaskCard(task),
          );
        },
      ),
       floatingActionButton: FloatingActionButton(
        onPressed:() async {
          final newTask = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(builder: (_) => AddTaskPage())
          );
          if(newTask != null) {
            await addTaskToDB(newTask);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

