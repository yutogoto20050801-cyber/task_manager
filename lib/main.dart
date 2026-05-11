import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:task_manager/calendar_page.dart';
import 'package:task_manager/database_helper.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;






final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const settings = InitializationSettings(android: android, iOS: ios);

  await notifications.initialize(settings);

  tz.initializeTimeZones();
}
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja_jp', null);
  await initializeNotifications();
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
          fillColor:WidgetStateProperty.all(Colors.white)
        )
        ),
      home: const TaskListPage(),
    );
  }
}

class AddTaskPage extends StatefulWidget {
  final Map<String, dynamic>? task;
  const AddTaskPage({super.key,this.task});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final titleController = TextEditingController();
  final subjectController = TextEditingController();
  final memoContoroller = TextEditingController();
  DateTime? deadline;
  TimeOfDay? deadlineTime;

  void initState(){
    super.initState();

    if(widget.task != null){
      final t = widget.task!;

      titleController.text = t['title'];
      subjectController.text = t['subject'];

      memoContoroller.text = t['memo'] ?? '';

      final dt = DateTime.parse(t['deadline']);

      deadline = DateTime(dt.year, dt.month, dt.day);
      deadlineTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.task != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ?'課題を編集' : '課題を追加')
        ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '課題名'),
            ),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: '科目'),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                setState(() => deadline = picked);
              },
              child: Text(
                deadline == null
                    ? '締切日を選択'
                    : '締切: ${deadline!.month}/${deadline!.day}',
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 23, minute: 59),
                );
                setState(() => deadlineTime = picked);
              },
              child: Text(
                deadlineTime == null
                    ? '締切時間を選択'
                    : '時間: ${deadlineTime!.hour}:${deadlineTime!.minute.toString().padLeft(2, '0')}',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: memoContoroller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'メモ',
                border: OutlineInputBorder(),
              ),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty ||
                subjectController.text.isEmpty ||
                deadline == null ||
                deadlineTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('すべての項目を入力してください')),
                  );
                  return;
                }

                final deadlineDateTime = DateTime(
                  deadline!.year,
                  deadline!.month,
                  deadline!.day,
                  deadlineTime!.hour,
                  deadlineTime!.minute,
                );

                final formattedDeadline = DateFormat('yyyy-MM-dd HH:mm').format(deadlineDateTime);


                final taskData = {
                  if(isEdit) 'id': widget.task!['id'],
                  'id': widget.task?['id'],
                  'title': titleController.text,
                  'subject': subjectController.text,
                  'deadline': formattedDeadline,
                  'notificationId': deadlineDateTime.hashCode,
                  'isDone': widget.task?['isDone'] ?? 0,
                  'memo': memoContoroller.text,
                };

                Navigator.pop(context, taskData);
              },
              child: Text(isEdit ? '更新' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}
class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
   List<Map<String, dynamic>> tasks = [];
   String searchQuery = '';
   void initState() {
    super.initState();
    loadTasksFromDB();
   }
    Future<void>loadTasksFromDB() async {
      final dbTasks = await DatabaseHelper.instance.getTasks();
      setState(() {
        tasks = dbTasks;
      });
    }

    Future<void> addTaskToDB(Map<String,dynamic> task) async {
      await DatabaseHelper.instance.insertTask(task);
      await scheduleTaskNotification(task);
      await loadTasksFromDB();
    }

    Future<void> updateTaskInDB(Map<String, dynamic> task) async{
      await DatabaseHelper.instance.updateTask(task);

      await notifications.cancel(task['notificationId']);

      if (task['isDone'] == 0) {
        await scheduleTaskNotification(task);
      }
      
      await loadTasksFromDB();
      setState(() {});
    }

    Future<void> deleteTaskFromDB(int id) async {
      await DatabaseHelper.instance.deleteTask(id);
      await loadTasksFromDB();
    }

    Future<void> scheduleTaskNotification(Map<String, dynamic> task) async {
    final date = DateTime.parse(task['deadline']);
    final notifyDateTime = date.subtract(const Duration(days:1));

    if(notifyDateTime.isBefore(DateTime.now())) return;

    await notifications.zonedSchedule(
      task['notificationId'],
      '締め切りが近いよ',
      '${task['title']} の締め切りは明日だよ',
      tz.TZDateTime.from(notifyDateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel',
          'Task Notification',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  int daysLeft(String deadlineString) {
    final deadline = DateTime.parse(deadlineString);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return deadline.difference(today).inDays;
      }

  Widget buildTaskCard(Map<String, dynamic> task) {
  final isDone = task['isDone'] == 1;

  return Card(
    elevation: 3,
    color: isDone
        ? Colors.grey[300]
        : daysLeft(task['deadline']) <= 3
            ? Colors.red[100]
            : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final updatedTask = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTaskPage(task: task),
          ),
        );

        if (updatedTask != null) {
          await updateTaskInDB(updatedTask);
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
                   : daysLeft(task['deadline']) <= 3
                  ? Colors.red
                  :Colors.blueGrey,
                borderRadius:BorderRadius.circular(4),
              ),
            ),

            const SizedBox(width: 12),
            GestureDetector(
              onTap: () async {
                final updatedTask = {
                  ...task,
                  'isDone': isDone ? 0 : 1,
                };

                await updateTaskInDB(updatedTask);
              },
              child: Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isDone ? Colors.green : Colors.grey,
                size: 28,
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
                    'あと ${daysLeft(task['deadline'])} 日',
                     style: TextStyle(
                     fontSize: 13,
                     color: Colors.redAccent,
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
         return title.contains(searchQuery) || subject.contains(searchQuery);
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
            onPressed:() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context)=> const CalendarPage()),
                );
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
            
            child: buildTaskCard(task),
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

