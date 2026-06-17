import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'notification_service.dart';


class AddTaskPage extends StatefulWidget {
  final Map<String, dynamic>? task;
  const AddTaskPage({super.key, this.task});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final titleController = TextEditingController();
  final subjectController = TextEditingController();
  final memoContoroller = TextEditingController();
  DateTime? deadline;
  TimeOfDay? deadlineTime;
  List<Map<String, dynamic>> reminders = [];
  bool useDetailedReminders = false;

  bool repeatWeekly = false;
  int notificationDaysBefore = 1;

  @override
  void initState() {
    super.initState();

    if (widget.task != null) {
      final t = widget.task!;
      titleController.text = t['title'];
      subjectController.text = t['subject'];
      memoContoroller.text = t['memo'] ?? '';
      notificationDaysBefore = t['notificationDaysBefore'] ?? 1;

      final dt = DateTime.parse(t['deadline']);
      deadline = DateTime(dt.year, dt.month, dt.day);
      deadlineTime = TimeOfDay(hour: dt.hour, minute: dt.minute);

        // load reminders for edit
        () async {
          final r = await DatabaseHelper.instance.getRemindersForTask(t['id']);
          setState(() {
            reminders = r;
            useDetailedReminders = r.isNotEmpty;
          });
        }();

     if(t['repeat'] == 'weekly') {
      repeatWeekly = false;
     } else {
      repeatWeekly = (t['repeatWeekly'] ?? 0) == 1;
     }      
    }
    
  }

  @override
void dispose() {
  titleController.dispose();
  subjectController.dispose();
  memoContoroller.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.task != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '課題を編集' : '課題を追加'),
        actions: [
          if (isEdit)
           IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () async {
          final id = widget.task!['id'];
          final title = widget.task!['title'];
          final repeatWeekly = widget.task!['repeatWeekly'] == 1 || widget.task!['repeat'] == 'weekly';

          if (repeatWeekly) {
            showDialog(
              context: context,
              builder: (_) {
                return AlertDialog(
                  title: const Text("削除しますか？"),
                  content: const Text("この予定だけ消すか、毎週分すべて消すか選んでください"),
                  actions: [
                    TextButton(
                      child: const Text("この予定だけ消す"),
                        onPressed: () async {
                        Navigator.pop(context);
                        await NotificationService.cancelTaskNotification(widget.task!);
                        await DatabaseHelper.instance.deleteTask(id);
                        Navigator.pop(context, "deleted");
                      },
                    ),
                    TextButton(
                      child: const Text("全て消す"),
                      onPressed: () async {
                        Navigator.pop(context);
                        await DatabaseHelper.instance.deleteWeeklyChildren(title);
                        await DatabaseHelper.instance.deleteTask(id);
                        Navigator.pop(context, "deleted");
                      },
                    ),
                  ],
                );
              },
            );
          } else {
            await DatabaseHelper.instance.deleteTask(id);
            Navigator.pop(context, "deleted");
          }
        },
      ),
  ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
                child: ListView(
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
                       if (picked != null) { 
                        setState(() => deadline = picked);
                       }
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
                        if (picked != null) {
                        setState(() => deadlineTime = picked);
                       }
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

                    SwitchListTile(
                      title: const Text('詳細リマインダーを使う'),
                      value: useDetailedReminders,
                      onChanged: (v) => setState(() => useDetailedReminders = v),
                    ),
                    if (!useDetailedReminders)
                      DropdownButtonFormField<int>(
                        value: notificationDaysBefore,
                        decoration: const InputDecoration(labelText: '通知タイミング'),
                        items: const [
                          DropdownMenuItem(value: -1, child: Text('通知なし')),
                          DropdownMenuItem(value: 0, child: Text('当日')),
                          DropdownMenuItem(value: 1, child: Text('1日前')),
                          DropdownMenuItem(value: 3, child: Text('3日前')),
                          DropdownMenuItem(value: 7, child: Text('1週間前')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            notificationDaysBefore = value;
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    const Text('リマインダー'),
                    const SizedBox(height: 8),
                    if (useDetailedReminders) ...reminders.map((r) {
                      final days = r['daysBefore'];
                      final time = r['time'] ?? '09:00';
                      return ListTile(
                        title: Text('${days}日前 $time'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              reminders.removeWhere((x) => x['id'] == r['id']);
                            });
                          },
                        ),
                      );
                    }),
                    if (useDetailedReminders)
                      TextButton.icon(
                      onPressed: () async {
                        int selectedDays = 1;
                        TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);

                        final days = await showDialog<int>(
                          context: context,
                          builder: (_) {
                            int tmp = selectedDays;
                            return AlertDialog(
                              title: const Text('何日前に通知しますか？'),
                              content: StatefulBuilder(
                                builder: (_, st) {
                                  return DropdownButton<int>(
                                    value: tmp,
                                    items: const [
                                      DropdownMenuItem(value: 0, child: Text('当日')),
                                      DropdownMenuItem(value: 1, child: Text('1日前')),
                                      DropdownMenuItem(value: 3, child: Text('3日前')),
                                      DropdownMenuItem(value: 7, child: Text('1週間前')),
                                    ],
                                    onChanged: (v) { if (v!=null) { tmp=v; st((){}); } },
                                  );
                                },
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('キャンセル')),
                                TextButton(onPressed: () => Navigator.pop(context, tmp), child: const Text('次へ')),
                              ],
                            );
                          },
                        );

                        if (days == null) return;

                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );

                        if (pickedTime == null) return;

                        setState(() {
                          reminders.add({
                            'daysBefore': days,
                            'time': '${pickedTime.hour.toString().padLeft(2,'0')}:${pickedTime.minute.toString().padLeft(2,'0')}',
                            'enabled': 1,
                          });
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('リマインダーを追加'),
                    ),
                    if (!useDetailedReminders)
                      const SizedBox.shrink(),

                  SizedBox(
                    width: double.infinity,
                    child:Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              repeatWeekly = !repeatWeekly;
                            });
                          },
                          child:Icon(
                            repeatWeekly ? Icons.check_circle:Icons.radio_button_unchecked,
                            color: repeatWeekly ? Colors.green : Colors.grey,
                            size: 28
                          )
                        ),
                        const SizedBox(width: 20),
                        const Text('毎週繰り返す'),
                      ],
                    ),
                  ),
                  ],
                ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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

                  final formattedDeadline =
                      DateFormat('yyyy-MM-dd HH:mm').format(deadlineDateTime);

                  final taskData = {
                if (isEdit) 'id': widget.task!['id'],
                 'title': titleController.text,
                 'subject': subjectController.text,
                 'deadline': formattedDeadline,
                 'notificationId': widget.task?['notificationId'] ?? deadlineDateTime.millisecondsSinceEpoch ~/ 1000,
                 'isDone': widget.task?['isDone'] ?? 0,
                 'memo': memoContoroller.text,
                 'repeat': 'none',
                 'repeatWeekly': repeatWeekly ? 1 : 0,
                 'notificationDaysBefore': notificationDaysBefore,
                 'reminders': useDetailedReminders ? reminders : [],
                };


                  if (isEdit && !repeatWeekly) {
                    await DatabaseHelper.instance.deleteWeeklyChildren(titleController.text);

                  }

                  Navigator.pop(context, taskData);
                },
                child: Text(isEdit ? '更新' : '保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}