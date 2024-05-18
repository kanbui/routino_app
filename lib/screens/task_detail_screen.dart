import 'package:flutter/material.dart';
import 'dart:async';
import '../database/database_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const int pomodoroTime = 5; // 5 seconds for testing
const int breakTime = 3; // 3 seconds for testing

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
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _loadTask();
    _resetPomodoro(); // Reset Pomodoro time when entering the screen
    _initializeNotifications(); // Initialize notifications
  }

  Future<void> _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
            macOS: initializationSettingsDarwin);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('your_channel_id', 'your_channel_name',
            channelDescription: 'your_channel_description',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false);
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: darwinPlatformChannelSpecifics,
        macOS: darwinPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin
        .show(0, title, body, platformChannelSpecifics, payload: 'item x');
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
          _showNotification(
              _isWorking ? 'Pomodoro Complete' : 'Break Complete',
              _isWorking
                  ? 'Time to take a break!'
                  : 'Time to get back to work!');
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
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: _isWorking ? Colors.red : Colors.lightBlueAccent,
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
