import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _doingTasks = [];
  List<Map<String, dynamic>> _completedTasks = [];
  bool _isCompletedTasksExpanded =
      false; // Track whether completed tasks list is expanded

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final doingTasks = await _dbHelper.getTasksByStatus('doing');
    final completedTasks = await _dbHelper.getTasksByStatus('completed');
    setState(() {
      _doingTasks = doingTasks;
      _completedTasks = completedTasks;
    });
  }

  Future<void> _addTask(String name) async {
    await _dbHelper
        .insertTask({'name': name, 'totalWorkTime': 0, 'status': 'doing'});
    _loadTasks();
  }

  void _startPomodoroForTask(int taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(taskId: taskId),
      ),
    );
    _loadTasks();
  }

  Future<void> _toggleTaskStatus(int taskId, String currentStatus) async {
    final newStatus = currentStatus == 'doing' ? 'completed' : 'doing';
    await _dbHelper.updateTaskStatus(taskId, newStatus);
    _loadTasks();
  }

  Future<void> _deleteTask(int taskId) async {
    await _dbHelper.deleteTask(taskId);
    _loadTasks();
  }

  Future<void> _updateTaskName(int taskId, String newName) async {
    await _dbHelper.updateTask(
        {'id': taskId, 'name': newName, 'totalWorkTime': 0, 'status': 'doing'});
    _loadTasks();
  }

  void _showDeleteConfirmationDialog(int taskId) {
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
                _deleteTask(taskId);
                Navigator.pop(context);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showEditTaskDialog(int taskId, String currentName) {
    TextEditingController _taskNameController =
        TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Task'),
          content: TextField(
            controller: _taskNameController,
            decoration: InputDecoration(hintText: 'Task Name'),
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
                _updateTaskName(taskId, _taskNameController.text);
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showAddTaskDialog() {
    TextEditingController _taskNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Task'),
          content: TextField(
            controller: _taskNameController,
            decoration: InputDecoration(hintText: 'Task Name'),
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

  String formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final totalWorkTimeFormatted = formatDuration(task['totalWorkTime']);
    final isCompleted = task['status'] == 'completed';
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey[200] : Colors.blue[100],
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4.0,
            offset: Offset(2, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(task['name']),
        subtitle: Text('Total Work Time: $totalWorkTimeFormatted'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _showEditTaskDialog(task['id'], task['name']),
            ),
            IconButton(
              icon: Icon(isCompleted ? Icons.undo : Icons.check),
              onPressed: () => _toggleTaskStatus(task['id'], task['status']),
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _showDeleteConfirmationDialog(task['id']),
            ),
          ],
        ),
        onTap: () => _startPomodoroForTask(task['id']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task List'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _doingTasks.length,
              itemBuilder: (context, index) {
                final task = _doingTasks[index];
                return _buildTaskItem(task);
              },
            ),
            Divider(),
            ExpansionTile(
              title: Text('Completed Tasks'),
              initiallyExpanded: _isCompletedTasksExpanded,
              onExpansionChanged: (bool expanded) {
                setState(() {
                  _isCompletedTasksExpanded = expanded;
                });
              },
              children:
                  _completedTasks.map((task) => _buildTaskItem(task)).toList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}
