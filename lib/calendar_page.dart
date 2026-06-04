import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';
import 'add_task_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  List<Map<String, dynamic>> allTasks = [];
  List<Map<String, dynamic>> tasksForSelectedDay = [];

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  DateTime parseDeadline(String value) {
  return DateFormat('yyyy-MM-dd HH:mm').parse(value);
}

  Future<void> loadTasks() async {
  final tasks = await DatabaseHelper.instance.getTasks();

  setState(() {
    allTasks = tasks;
    filterTasksForSelectedDay();
  });
}

  void filterTasksForSelectedDay() {
    if (_selectedDay == null) return;

    tasksForSelectedDay = allTasks.where((task) {
       final deadline = parseDeadline(task['deadline']);
       return isSameDay(deadline, _selectedDay);
    }).toList();
  }

  int daysLeft(DateTime deadline) {
    final now = DateTime.now();
    return deadline.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("課題カレンダー"),
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: 'ja_JP',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
            },
            
            eventLoader: (day) {
              return allTasks.where((task) {
                final deadline = parseDeadline(task['deadline']);
                return isSameDay(deadline, day);
              }).toList();
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                filterTasksForSelectedDay();
              });
            },
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.indigo,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: tasksForSelectedDay.isEmpty
                ? const Center(child: Text("この日の課題はありません"))
                : ListView.builder(
                    itemCount: tasksForSelectedDay.length,
                    itemBuilder: (context, index) {
                      final task = tasksForSelectedDay[index];
                      final deadline = parseDeadline(task['deadline']);
                      final left = daysLeft(deadline);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                       child: ListTile(
  title: Text(task['title']),
  subtitle: Text(
    "締め切り: ${deadline.year}/${deadline.month}/${deadline.day}\n"
    "あと $left 日",
  ),
  trailing: const Icon(Icons.chevron_right),
  onTap: () async {
    final original = await DatabaseHelper.instance.getTaskById(task['id']);
    if (original == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskPage(task: original),
      ),
    );

    if (result == "deleted") {
      await loadTasks();
      return;
    }

    if (result is Map<String, dynamic>) {
      await DatabaseHelper.instance.updateTask(result);

      if (result['repeatWeekly'] == 1) {
        await DatabaseHelper.instance.generateWeeklyTasks();
      }

      await loadTasks();
    }
  },
), 
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
