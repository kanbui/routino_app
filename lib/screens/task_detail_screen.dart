import 'package:flutter/material.dart';
import 'dart:async';
import '../database/database_helper.dart';

const int pomodoroTime = 5; // 25 * 60; // 25 minutes in seconds
const int breakTime = 3; // 5 * 60; // 5 minutes in seconds

class TaskDetailScreen extends StatefulWidget {
  final int taskId;

  TaskDetailScreen({required this.taskId});

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _task;
  int _remainingTime = pomodoroTime;
  bool _isWorking = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadTask();
    _resetPomodoro(); // Reset Pomodoro time when entering the screen
  }

  Future<void> _loadTask() async {
    final tasks = await _dbHelper.getTasks();
    setState(() {
      _task = tasks.firstWhere((t) => t['id'] == widget.taskId);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _stopTimer(); // Stop timer after a Pomodoro or break is complete
          _toggleWorkBreak(); // Switch between work and break
        }
        if (_isWorking) {
          _updateTaskWorkTime();
        }
        _savePomodoro();
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _resetTimer() {
    _stopTimer();
    setState(() {
      _resetPomodoro();
    });
  }

  void _resetPomodoro() {
    _isWorking = true;
    _remainingTime = pomodoroTime;
  }

  void _toggleWorkBreak() {
    setState(() {
      _isWorking = !_isWorking;
      _remainingTime = _isWorking ? pomodoroTime : breakTime;
    });
  }

  Future<void> _savePomodoro() async {
    await _dbHelper.insertPomodoro({
      'id': widget.taskId,
      'isWorking': _isWorking ? 1 : 0,
      'remainingTime': _remainingTime,
    });
  }

  Future<void> _updateTaskWorkTime() async {
    if (_task != null) {
      final updatedWorkTime = _task!['totalWorkTime'] + 1;
      await _dbHelper.updateTask({
        'id': widget.taskId,
        'name': _task!['name'],
        'totalWorkTime': updatedWorkTime,
      });
      _loadTask(); // Refresh the task details
    }
  }

  String formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resetPomodoro(); // Reset Pomodoro time when exiting the screen
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_task == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Task Detail'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final totalWorkTimeFormatted = formatDuration(_task!['totalWorkTime']);
    final formattedRemainingTime = formatDuration(_remainingTime);

    return Scaffold(
      appBar: AppBar(
        title: Text(_task!['name']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Center(
              child: Column(
                children: [
                  Text(
                    'Total Work Time: $totalWorkTimeFormatted',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(height: 20),
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color:
                          _isWorking ? Colors.red[400] : Colors.lightBlueAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        formattedRemainingTime,
                        style: TextStyle(
                          fontSize: 48,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _startTimer,
                        child: Text('Start'),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _stopTimer,
                        child: Text('Stop'),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _resetTimer,
                        child: Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: Container()),
          ],
        ),
      ),
    );
  }
}
