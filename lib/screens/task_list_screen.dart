import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _tasks = [];
  bool _showCompletedTasks =
      false; // State to manage completed tasks visibility

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await _dbHelper.getTasks();
    setState(() {
      _tasks = tasks;
    });
  }

  Future<void> _addTask(String name, int estimateTime, DateTime dueTime) async {
    await _dbHelper.insertTask({
      'name': name,
      'totalWorkTime': 0,
      'estimateTime': estimateTime,
      'dueTime': dueTime.toIso8601String(),
      'status': 'doing',
    });
    _loadTasks();
  }

  Future<void> _updateTask(Map<String, dynamic> task) async {
    await _dbHelper.updateTask(task);
    _loadTasks();
  }

  Future<void> _deleteTask(int id) async {
    await _dbHelper.deleteTask(id);
    _loadTasks();
  }

  void _showAddTaskDialog() {
    TextEditingController _taskNameController = TextEditingController();
    TextEditingController _taskEstimateTimeController = TextEditingController();
    DateTime? _dueTime;

    Future<void> _selectDueTime(BuildContext context) async {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );
      if (pickedDate != null) {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (pickedTime != null) {
          setState(() {
            _dueTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
          });
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // Square corners
          ),
          title: Text('Add Task'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _taskNameController,
                  decoration: InputDecoration(hintText: 'Task Name'),
                ),
                TextField(
                  controller: _taskEstimateTimeController,
                  decoration:
                      InputDecoration(hintText: 'Estimate Time (minutes)'),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Text(_dueTime == null
                        ? 'Select Due Time'
                        : DateFormat('yyyy-MM-dd HH:mm').format(_dueTime!)),
                    IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: () {
                        _selectDueTime(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final estimateTime =
                    int.tryParse(_taskEstimateTimeController.text) ?? 0;
                final dueTime = _dueTime ?? DateTime.now();
                _addTask(_taskNameController.text, estimateTime, dueTime);
                Navigator.pop(context);
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditTaskDialog(Map<String, dynamic> task) {
    TextEditingController _taskNameController =
        TextEditingController(text: task['name']);
    TextEditingController _taskEstimateTimeController =
        TextEditingController(text: task['estimateTime'].toString());
    DateTime? _dueTime = DateTime.tryParse(task['dueTime']);

    Future<void> _selectDueTime(BuildContext context) async {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _dueTime ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );
      if (pickedDate != null) {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_dueTime ?? DateTime.now()),
        );
        if (pickedTime != null) {
          setState(() {
            _dueTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
          });
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // Square corners
          ),
          title: Text('Edit Task'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _taskNameController,
                  decoration: InputDecoration(hintText: 'Task Name'),
                ),
                TextField(
                  controller: _taskEstimateTimeController,
                  decoration:
                      InputDecoration(hintText: 'Estimate Time (minutes)'),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Text(_dueTime == null
                        ? 'Select Due Time'
                        : DateFormat('yyyy-MM-dd HH:mm').format(_dueTime!)),
                    IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: () {
                        _selectDueTime(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final updatedTask = Map<String, dynamic>.from(task);
                updatedTask['name'] = _taskNameController.text;
                updatedTask['estimateTime'] =
                    int.tryParse(_taskEstimateTimeController.text) ?? 0;
                updatedTask['dueTime'] = _dueTime?.toIso8601String();
                _updateTask(updatedTask);
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _toggleTaskStatus(Map<String, dynamic> task) {
    final updatedTask = Map<String, dynamic>.from(task);
    updatedTask['status'] = task['status'] == 'doing' ? 'completed' : 'doing';
    _updateTask(updatedTask);
  }

  void _confirmDeleteTask(int id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Task'),
          content: Text('Are you sure you want to delete this task?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteTask(id);
                Navigator.pop(context);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _openTaskDetail(int taskId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(taskId: taskId),
      ),
    ).then((_) {
      _loadTasks(); // Reload tasks when returning from task detail screen
    });
  }

  String formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return 'No due';
    }
    final dateTime = DateTime.parse(dateTimeString);
    final formatter = DateFormat('d MMM HH:mm');
    return formatter.format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> doingTasks =
        _tasks.where((task) => task['status'] == 'doing').toList();
    List<Map<String, dynamic>> completedTasks =
        _tasks.where((task) => task['status'] == 'completed').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('My Routino'),
        actions: [
          Container(
            margin:
                EdgeInsets.only(right: 6.0), // Thêm khoảng cách bên phải 20px
            child: IconButton(
              icon: Icon(Icons.settings, size: 26.0),
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: doingTasks.length,
            itemBuilder: (context, index) {
              final task = doingTasks[index];
              final totalWorkTimeFormatted =
                  formatDuration(task['totalWorkTime']);
              final estimateTime = task['estimateTime'];
              final dueTimeFormatted = formatDateTime(task['dueTime']);
              return Card(
                color: Colors.lightBlue[200], // Change color to light blue
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero, // Remove rounded corners
                ),
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 2,
                child: ListTile(
                  title: Text(
                    task['name'],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '$dueTimeFormatted | Est: $estimateTime min | Worked: $totalWorkTimeFormatted')
                    ],
                  ),
                  leading: Checkbox(
                    value: task['status'] == 'completed',
                    onChanged: (value) {
                      _toggleTaskStatus(task);
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          _showEditTaskDialog(task);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          _confirmDeleteTask(task['id']);
                        },
                      ),
                    ],
                  ),
                  onTap: () => _openTaskDetail(task['id']),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Completed Tasks'),
                IconButton(
                  icon: Icon(
                    _showCompletedTasks ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() {
                      _showCompletedTasks = !_showCompletedTasks;
                    });
                  },
                ),
              ],
            ),
          ),
          if (_showCompletedTasks)
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: completedTasks.length,
              itemBuilder: (context, index) {
                final task = completedTasks[index];
                final totalWorkTimeFormatted =
                    formatDuration(task['totalWorkTime']);
                final estimateTime = task['estimateTime'];
                final dueTimeFormatted = formatDateTime(task['dueTime']);
                return Card(
                  color: Colors.grey[300], // Change color to grey
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero, // Remove rounded corners
                  ),
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 2,
                  child: ListTile(
                    title: Text(
                      task['name'],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '$dueTimeFormatted | Est: $estimateTime min | Worked: $totalWorkTimeFormatted')
                      ],
                    ),
                    leading: Checkbox(
                      value: task['status'] == 'completed',
                      onChanged: (value) {
                        _toggleTaskStatus(task);
                      },
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            _showEditTaskDialog(task);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            _confirmDeleteTask(task['id']);
                          },
                        ),
                      ],
                    ),
                    onTap: () => _openTaskDetail(task['id']),
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: _showAddTaskDialog, child: Icon(Icons.add)),
    );
  }
}
