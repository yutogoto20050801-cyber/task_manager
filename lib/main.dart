import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  await initializeNotifications();
  runApp(const TaskApp());
}

class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '優斗のアプリ',
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
class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
   List<Map<String, dynamic>> tasks = [];
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
      await loadTasksFromDB();
    }

    Future<void> deleteTaskFromDB(int id) async {
      await DatabaseHelper.instance.deleteTask(id);
      await loadTasksFromDB();
    }

    Future<void> scheduleTaskNotification(Map<String, dynamic> task) async {
    final parts = task['deadline'].split(' ');
    final dateParts = parts[0].split('/');
    final timeParts = parts[1].split(':');

    final month = int.parse(dateParts[0]);
    final day = int.parse(dateParts[1]);
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final deadlineDateTime = DateTime(
      DateTime.now().year,
      month,
      day,
      hour,
      minute,
    );

    final notifyDateTime = deadlineDateTime.subtract(const Duration(days: 1));

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
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('課題一覧')),
      body: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];

          
        

          return Dismissible(
            key: ValueKey(task['notificationId']),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.indigo),
            ),

            onDismissed: (direction) async {
              await deleteTaskFromDB(task['id']);
              await loadTasksFromDB();
              setState(() {});
            },
            
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child:Opacity( 
              opacity: task['isDone'] == 1 ?0.5 : 1.0,
              child: ListTile(
                leading: Checkbox(
                  value: task['isDone'] == 1,
                  onChanged: (value) async {
                    final updatedTask = {       
                       'id': task['id'],
                       'title': task['title'],
                       'subject': task['subject'],
                       'deadline': task['deadline'],
                       'notificationId': task['notificationId'],
                       'isDone': value! ? 1 : 0,
                      };

                      if (value == true) {
                        await notifications.cancel(task['notificationId']);
                      }

                      if (value == false)  {
                        await scheduleTaskNotification(updatedTask);
                      }
                

                      await DatabaseHelper.instance.updateTask(updatedTask);
                      await loadTasksFromDB();
                      setState(() {});
                    },
                  ), 

                title: Text(task['title']),
                subtitle: Text('${task['subject']} / 締切: ${task['deadline']}'),

                onTap: () async {
                  final updatedTask = await Navigator.push(
                   context,
                   MaterialPageRoute(
                    builder: (_) => AddTaskPage(task: task),
                   ),
                  );

                  if(updatedTask != null){

                    await notifications.cancel(task['notificationId']);

                    await scheduleTaskNotification(updatedTask);
                    await DatabaseHelper.instance.updateTask(updatedTask);
                    await loadTasksFromDB();
                    setState(() {});
                  }
                }
              ),
            ),
          ),
        );
      },
    ),
    

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newTask = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(builder: (_) => const AddTaskPage()),
          );

          if (newTask != null) {
            await addTaskToDB(newTask);
          }
        },
        child: const Icon(Icons.add),
      ),
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
  DateTime? deadline;
  TimeOfDay? deadlineTime;

  void initState(){
    super.initState();

    if(widget.task != null){
      final t = widget.task!;
      titleController.text = t['title'];
      subjectController.text = t['subject'];

      final parts = t['deadline'].split(' ');
      final dateParts = parts[0].split('/');
      final timeParts = parts[1].split(':');

      deadline = DateTime(
        2024,
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
      );

      deadlineTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
        );
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


                final taskData = {
                  'id': widget.task?['id'],
                  'title': titleController.text,
                  'subject': subjectController.text,
                  'deadline':
                      '${deadline!.month}/${deadline!.day} ${deadlineTime!.hour}:${deadlineTime!.minute.toString().padLeft(2, '0')}',
                  'notificationId': deadlineDateTime.hashCode,
                  'isDone': widget.task?['isDone'] ?? 0,
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

