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
  String _selectedTimeFilter = 'all'; // Default time filter
  String _selectedPriorityFilter = 'all'; // Default time filter

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() async {
    final tasks =
        await _dbHelper.getTasks(_selectedTimeFilter, _selectedPriorityFilter);
    setState(() {
      _tasks = tasks;
    });
  }

  Future<void> _deleteTask(int id) async {
    await _dbHelper.deleteTask(id);
    _loadTasks();
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

  Color _getColorByPriority(int? priority) {
    if (priority == null) {
      return Colors.white; // Màu mặc định nếu priority là null
    }
    switch (priority) {
      case 1:
        return Colors.purple[200]!; // Màu tím
      case 2:
        return Colors.red[200]!; // Màu đỏ
      case 3:
        return Colors.green[200]!; // Màu xanh
      case 4:
        return Colors.grey[200]!; // Màu trắng xám
      default:
        return Colors.white; // Màu mặc định nếu priority không khớp
    }
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
    final now = DateTime.now();

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      // Nếu là ngày hôm nay
      final formatter = DateFormat('HH:mm');
      return 'Today ${formatter.format(dateTime)}';
    } else {
      // Nếu là ngày khác
      final formatter = DateFormat('d MMM HH:mm');
      return formatter.format(dateTime);
    }
  }

  String formatEstimateTime(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00';
  }

  void _showTaskDialog({Map<String, dynamic>? task}) {
    final TextEditingController _taskNameController =
        TextEditingController(text: task?['name']);
    final TextEditingController _taskEstimateHoursController =
        TextEditingController(
            text: task != null ? (task['estimateTime'] ~/ 60).toString() : '');
    final TextEditingController _taskEstimateMinutesController =
        TextEditingController(
            text: task != null ? (task['estimateTime'] % 60).toString() : '');
    final _formKey = GlobalKey<FormState>();
    DateTime? _dueTime =
        task != null ? DateTime.tryParse(task['dueTime']) : null;
    int _priority =
        task != null ? task['priority'] : 3; // default normal priority

    Future<void> _selectDueTime(
        BuildContext context, void Function(void Function()) setState) async {
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
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero, // Square corners
              ),
              title: Text(task == null ? 'Add Task' : 'Edit Task'),
              content: Container(
                width: double.maxFinite,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _taskNameController,
                        decoration: InputDecoration(hintText: 'Task Name'),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter task name' : null,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _taskEstimateHoursController,
                              decoration: InputDecoration(labelText: 'Hours'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _taskEstimateMinutesController,
                              decoration: InputDecoration(labelText: 'Minutes'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _priority,
                              items: [
                                DropdownMenuItem(
                                    value: 1, child: Text('urgent')),
                                DropdownMenuItem(value: 2, child: Text('high')),
                                DropdownMenuItem(
                                    value: 3, child: Text('normal')),
                                DropdownMenuItem(value: 4, child: Text('low')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _priority = value ?? 3;
                                });
                              },
                              decoration:
                                  InputDecoration(labelText: 'Độ ưu tiên'),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _dueTime == null
                                  ? 'Select Due Time'
                                  : DateFormat('d MMM yyyy HH:mm')
                                      .format(_dueTime!),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.calendar_today),
                            onPressed: () {
                              _selectDueTime(context, setState);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
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
                    final int hours =
                        int.tryParse(_taskEstimateHoursController.text) ?? 0;
                    final int minutes =
                        int.tryParse(_taskEstimateMinutesController.text) ?? 0;
                    final estimateTime = (hours * 60) + minutes;
                    final dueTime = _dueTime ?? DateTime.now();

                    if (_formKey.currentState!.validate()) {
                      if (task == null) {
                        _addTask(_taskNameController.text, estimateTime,
                            dueTime, _priority);
                      } else {
                        final updatedTask = Map<String, dynamic>.from(task);
                        updatedTask['name'] = _taskNameController.text;
                        updatedTask['estimateTime'] = estimateTime;
                        updatedTask['dueTime'] = _dueTime?.toIso8601String();
                        updatedTask['priority'] = _priority;
                        _updateTask(updatedTask);
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: Text(task == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addTask(
      String name, int estimateTime, DateTime dueTime, int priority) async {
    await _dbHelper.insertTask({
      'name': name,
      'totalWorkTime': 0,
      'estimateTime': estimateTime,
      'dueTime': dueTime.toIso8601String(),
      'status': 'doing',
      'priority': priority
    });
    _loadTasks();
  }

  Future<void> _updateTask(Map<String, dynamic> task) async {
    await _dbHelper.updateTask(task);
    _loadTasks();
  }

  void _showAddTaskDialog() {
    _showTaskDialog();
  }

  void _showEditTaskDialog(Map<String, dynamic> task) {
    _showTaskDialog(task: task);
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
            margin: EdgeInsets.only(right: 6.0),
            child: IconButton(
              icon: Icon(Icons.settings, size: 26.0),
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTimeFilter,
                    items: [
                      DropdownMenuItem(
                          value: 'all', child: Text('Tất cả thời gian')),
                      DropdownMenuItem(value: 'today', child: Text('Hôm nay')),
                      DropdownMenuItem(
                          value: 'tomorrow', child: Text('Ngày Mai')),
                      DropdownMenuItem(
                          value: 'this_week', child: Text('Tuần Này')),
                      DropdownMenuItem(
                          value: 'this_month', child: Text('Tháng Này')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTimeFilter = value!;
                      });
                      _loadTasks();
                    },
                    decoration: InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                    ),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                    dropdownColor: Colors.white,
                    icon: Icon(Icons.arrow_drop_down),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPriorityFilter,
                    items: [
                      DropdownMenuItem(
                          value: 'all', child: Text('Tất cả cấp độ')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPriorityFilter = value!;
                      });
                      _loadTasks();
                    },
                    decoration: InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                    ),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                    dropdownColor: Colors.white,
                    icon: Icon(Icons.arrow_drop_down),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: doingTasks.length,
                  itemBuilder: (context, index) {
                    final task = doingTasks[index];
                    final totalWorkTimeFormatted =
                        formatDuration(task['totalWorkTime']);
                    final estimateTime =
                        formatEstimateTime(task['estimateTime']);
                    final dueTimeFormatted = formatDateTime(task['dueTime']);
                    return Card(
                      color: _getColorByPriority(task['priority']),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      elevation: 2,
                      child: ListTile(
                        title: Text(task['name']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '$dueTimeFormatted | Est: $estimateTime | Worked: $totalWorkTimeFormatted')
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Completed Tasks'),
                      IconButton(
                        icon: Icon(_showCompletedTasks
                            ? Icons.expand_less
                            : Icons.expand_more),
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
                      final estimateTime =
                          formatEstimateTime(task['estimateTime']);
                      final dueTimeFormatted = formatDateTime(task['dueTime']);
                      return Card(
                        color: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        margin:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        elevation: 2,
                        child: ListTile(
                          title: Text(task['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '$dueTimeFormatted | Est: $estimateTime | Worked: $totalWorkTimeFormatted')
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}
