import 'package:flutter/material.dart';
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

  Future<void> _addTask(String name) async {
    await _dbHelper
        .insertTask({'name': name, 'totalWorkTime': 0, 'status': 'doing'});
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
            child: TextField(
              controller: _taskNameController,
              decoration: InputDecoration(hintText: 'Task Name'),
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
                _addTask(_taskNameController.text);
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
            child: TextField(
              controller: _taskNameController,
              decoration: InputDecoration(hintText: 'Task Name'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> doingTasks =
        _tasks.where((task) => task['status'] == 'doing').toList();
    List<Map<String, dynamic>> completedTasks =
        _tasks.where((task) => task['status'] == 'completed').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Task List'),
      ),
      body: ListView(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: doingTasks.length,
            itemBuilder: (context, index) {
              final task = doingTasks[index];
              return Card(
                color: Colors.lightBlueAccent, // Change color to light blue
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero, // Remove rounded corners
                ),
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 2,
                child: ListTile(
                  title: Text(
                    task['name'],
                    style: TextStyle(
                      decoration: task['status'] == 'completed'
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
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
                return Card(
                  color: Colors.grey, // Change color to grey
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero, // Remove rounded corners
                  ),
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 2,
                  child: ListTile(
                    title: Text(
                      task['name'],
                      style: TextStyle(
                        decoration: task['status'] == 'completed'
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
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
        onPressed: _showAddTaskDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}
