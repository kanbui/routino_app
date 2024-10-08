import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';
import 'note_form.dart';
import 'subtask_form.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;

  TaskDetailScreen({required this.taskId});

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> with TrayListener {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, dynamic> _task = {}; // Default to an empty map
  List<Map<String, dynamic>> _subtasks = [];
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _timeLogs = [];
  int _remainingTime = 0;
  int _elapsedSeconds = 0; // Elapsed time in seconds
  bool _isWorking = true;
  Timer? _timer;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _pomodoroDuration = 25; // Default value
  int _breakDuration = 5; // Default value
  DateTime? _pomodoroStartTime; // Start time of the current Pomodoro
  bool _showTimeLogs = false; // State to manage time logs visibility
  Map<String, dynamic>? _currentSubtask; // Selected subtask for Pomodoro

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadTask();
    _loadSubtasks();
    _loadNotes(); // Load notes for the task
    _loadTimeLogs(); // Load time logs for the task
    _initializeNotifications(); // Initialize notifications
    _setupTray();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pomodoroDuration = prefs.getInt('pomodoroDuration') ?? 25;
      _breakDuration = prefs.getInt('breakDuration') ?? 5;
      _remainingTime = _pomodoroDuration * 60;
    });
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
        AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      icon: '@mipmap/ic_launcher', // Default app icon
    );
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  Future<void> _loadTask() async {
    final task = await _dbHelper.getTaskById(widget.taskId);
    setState(() {
      _task = task;
    });
  }

  Future<void> _loadSubtasks() async {
    final subtasks = await _dbHelper.getSubtasks(widget.taskId);
    final sortedSubtasks = List<Map<String, dynamic>>.from(subtasks);
    sortedSubtasks.sort((a, b) {
      if (a['status'] == 'completed' && b['status'] != 'completed') {
        return 1;
      } else if (a['status'] != 'completed' && b['status'] == 'completed') {
        return -1;
      }
      return 0;
    });
    setState(() {
      _subtasks = sortedSubtasks;
    });
  }

  Future<void> _loadNotes() async {
    final notes = await _dbHelper.getNotesByTaskId(widget.taskId);
    setState(() {
      _notes = notes;
    });
  }

  Future<void> _loadTimeLogs() async {
    final timeLogs = await _dbHelper.getTimeLogsByTaskId(widget.taskId);
    setState(() {
      _timeLogs = timeLogs;
    });
  }

  Future<void> _logTime() async {
    if (_isWorking && _pomodoroStartTime != null && _elapsedSeconds > 0) {
      final endTime = DateTime.now();
      var logTime = {
        'task_id': widget.taskId,
        'start_time': _pomodoroStartTime!.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'duration': _elapsedSeconds,
      };
      if (_currentSubtask != null) {
        logTime['subtask_id'] = _currentSubtask!['id'];
      }
      await _dbHelper.insertTimeLog(logTime);

      if (_currentSubtask != null) {
        final updatedWorkTime =
            _currentSubtask!['totalWorkTime'] + _elapsedSeconds;
        final updatedSubTask = await _dbHelper.updateSubtask({
          'id': _currentSubtask!['id'],
          'totalWorkTime': updatedWorkTime,
        });
        _currentSubtask =
            await _dbHelper.getSubtaskById(_currentSubtask!['id']);
      }
      await _loadSubtasks(); // Refresh the subtasks

      _pomodoroStartTime = null;
      _elapsedSeconds = 0;
      _loadTimeLogs(); // Reload time logs after adding new log
    }
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

  void _showAddNoteDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return NoteDialog(
          taskId: widget.taskId,
          onNoteAdded: (note) {
            setState(() {
              List<Map<String, dynamic>> updatedNotes =
                  List.from(_notes); // Sao chép danh sách trước khi thêm
              updatedNotes.add(note);
              _notes = updatedNotes;
            });
          },
        );
      },
    );
  }

  void _showEditNoteDialog(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) {
        return NoteDialog(
          taskId: widget.taskId,
          note: note,
          onNoteEdited: (updatedNote) {
            setState(() {
              List<Map<String, dynamic>> updatedNotes =
                  List.from(_notes); // Sao chép danh sách trước khi cập nhật
              int index =
                  updatedNotes.indexWhere((n) => n['id'] == updatedNote['id']);
              if (index != -1) {
                updatedNotes[index] = updatedNote;
                _notes = updatedNotes;
              }
            });
          },
        );
      },
    );
  }

  void _confirmDeleteNote(int noteId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Note'),
          content: Text('Are you sure you want to delete this note?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteNote(noteId);
                Navigator.pop(context);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteNote(int noteId) async {
    await _dbHelper.deleteNote(noteId);
    setState(() {
      _notes.removeWhere((note) => note['id'] == noteId);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _pomodoroStartTime = DateTime.now();
    _elapsedSeconds = 0; // Reset elapsed time
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
          _elapsedSeconds++; // Increment elapsed time
        } else {
          _stopTimer(); // Stop timer after a Pomodoro or break is complete
          _playSound(); // Play sound when Pomodoro or break is complete
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
        _updateTray();
      });
    });
  }

  Future<void> _stopTimer() async {
    await _logTime(); // Log the current Pomodoro time when timer is stopped
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
    _remainingTime = _pomodoroDuration * 60;
    _updateTray();
  }

  void _toggleWorkBreak() {
    setState(() {
      _isWorking = !_isWorking;
      _remainingTime =
          _isWorking ? _pomodoroDuration * 60 : _breakDuration * 60;
      _updateTray();
    });
  }

  Future<void> _updateTaskWorkTime() async {
    if (_task.isNotEmpty) {
      final updatedWorkTime = _task['totalWorkTime'] + 1;
      await _dbHelper.updateTask({
        'id': widget.taskId,
        'name': _task['name'],
        'totalWorkTime': updatedWorkTime,
      });
      _loadTask(); // Refresh the task details
    }
  }

  Future<void> _playSound() async {
    await _audioPlayer.play(AssetSource('ting.mp3'));
  }

  String formatDuration(int? totalSeconds) {
    if (totalSeconds == null) {
      return '00:00';
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _setupTray() async {
    await trayManager.setIcon('assets/app_icon.png');

    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show',
          label: 'Show Application',
        ),
        MenuItem(
          key: 'quit',
          label: 'Quit',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
    trayManager.addListener(this);
  }

  void _updateTray() {
    final formattedTime = formatDuration(_remainingTime);
    trayManager.setTitle(formattedTime);
  }

  void _showSubtaskDialog({Map<String, dynamic>? subtask}) {
    showDialog(
      context: context,
      builder: (context) {
        return SubtaskForm(
          subtask: subtask,
          onSave: (subtask) {
            if (subtask['id'] == null) {
              _addSubtask(subtask);
            } else {
              _updateSubtask(subtask);
            }
          },
        );
      },
    );
  }

  Future<void> _addSubtask(Map<String, dynamic> subtask) async {
    subtask['parentTaskId'] = widget.taskId;
    await _dbHelper.insertSubtask(subtask);
    _loadSubtasks();
  }

  Future<void> _updateSubtask(Map<String, dynamic> subtask) async {
    await _dbHelper.updateSubtask(subtask);
    _loadSubtasks();
  }

  void _confirmDeleteSubtask(int id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Subtask'),
          content: Text('Are you sure you want to delete this subtask?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteSubtask(id);
                Navigator.pop(context);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _toggleSubtaskStatus(Map<String, dynamic> subtask) {
    final updatedSubtask = Map<String, dynamic>.from(subtask);
    updatedSubtask['status'] =
        subtask['status'] == 'doing' ? 'completed' : 'doing';
    _dbHelper.updateSubtask(updatedSubtask);
    _loadSubtasks();
  }

  void _deleteSubtask(int id) {
    _dbHelper.deleteSubtask(id);
    _loadSubtasks();
  }

  Future<void> _startSubtaskTimer(Map<String, dynamic>? subtask) async {
    if (_currentSubtask == subtask) {
      await _stopTimer(); // Stop the Pomodoro timer when closing the subtask
      setState(() {
        _currentSubtask = null;
      });
    } else {
      setState(() {
        _currentSubtask = subtask;
      });
    }
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        break;
      case 'quit':
        windowManager.close();
        break;
    }
  }

  @override
  void dispose() {
    _logTime(); // Log the current Pomodoro time when exiting the screen
    _timer?.cancel();
    _audioPlayer.dispose();
    _resetPomodoro(); // Reset Pomodoro time when exiting the screen
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_task.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Task Detail'),
        ),
        body: Center(
          child: Text('Task not found.'),
        ),
      );
    }

    final totalWorkTimeFormatted = formatDuration(_task['totalWorkTime']);
    final formattedRemainingTime = formatDuration(_remainingTime);

    return Scaffold(
      appBar: AppBar(
        title: Text(_task['name']),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg.jpeg'),
              repeat: ImageRepeat.repeat,
            ),
          ),
        ),
      ),
      body: Container(
        constraints: BoxConstraints.expand(),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpeg'),
            repeat: ImageRepeat.repeat,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Worked Time: $totalWorkTimeFormatted',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      SizedBox(height: 20),
                      Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(
                                'assets/circle.jpeg'), // Thay đường dẫn tới hình ảnh của bạn
                            fit: BoxFit.cover,
                          ),
                          shape: BoxShape.circle, // Giữ hình dạng tròn
                          // color: _isWorking ? Colors.red : Colors.lightBlueAccent,
                        ),
                        child: Center(
                          child: Text(
                            formattedRemainingTime,
                            style: TextStyle(
                              fontSize: 36,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  blurRadius: 10.0,
                                  color: Colors.black,
                                  offset: Offset(2.0, 2.0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      if (_currentSubtask != null)
                        Card(
                          color: _currentSubtask!['status'] == 'doing'
                              ? Colors.lightBlue[200]
                              : Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          margin:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: EdgeInsets.only(
                                left: 10, top: 0, right: 3, bottom: 0),
                            title: Text(
                              _currentSubtask!['name'],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _startSubtaskTimer(_currentSubtask);
                                });
                              },
                            ),
                            subtitle: Text(
                              'Est: ${formatDuration(_currentSubtask!['estimateTime'])} | Worked: ${formatDuration(_currentSubtask!['totalWorkTime'])}',
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
                      SizedBox(height: 20),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _showSubtaskDialog(),
                              child: Text('Add Subtask'),
                            ),
                            SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _showAddNoteDialog,
                              child: Text('Add Note'),
                            ),
                          ]),
                      SizedBox(height: 20),
                      if (_subtasks.isNotEmpty)
                        Text(
                          'Subtasks',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ..._subtasks.map((subtask) {
                        final subtaskTotalWorkTimeFormatted =
                            formatDuration(subtask['totalWorkTime']);
                        final estimateTime =
                            formatDuration(subtask['estimateTime']);
                        final isSelected = _currentSubtask == subtask;
                        return Card(
                          color: subtask['status'] == 'doing'
                              ? Colors.lightBlue[200]
                              : Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.zero, // Remove rounded corners
                          ),
                          margin:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: EdgeInsets.only(
                                left: 10, top: 0, right: 3, bottom: 0),
                            title: Text(
                              subtask['name'],
                              style: TextStyle(
                                fontSize: 14, // Large font size
                                fontWeight: FontWeight.bold, // Bold font weight
                              ),
                            ),
                            leading: Checkbox(
                              value: subtask['status'] == 'completed',
                              onChanged: (value) {
                                _toggleSubtaskStatus(subtask);
                              },
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () {
                                    _showSubtaskDialog(subtask: subtask);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () {
                                    _confirmDeleteSubtask(subtask['id']);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(isSelected
                                      ? Icons.close
                                      : Icons.play_arrow),
                                  onPressed: () {
                                    _startSubtaskTimer(subtask);
                                  },
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Est: $estimateTime | Worked: $subtaskTotalWorkTimeFormatted',
                              style: TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      SizedBox(height: 20),
                      if (_notes.isNotEmpty)
                        Text(
                          'Notes',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ..._notes.map((note) {
                        final createdTime = formatDateTime(note['createdAt']);
                        return Card(
                          color: Colors.teal[100],
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.zero, // Remove rounded corners
                          ),
                          margin: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4.5),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: EdgeInsets.only(
                                left: 10, top: 0, right: 3, bottom: 0),
                            title: Text(
                              '${note['icon']} ${note['content']}',
                              style: TextStyle(
                                fontSize: 14, // Large font size
                                fontWeight: FontWeight.bold, // Bold font weight
                              ),
                            ),
                            subtitle: Text(
                              '${createdTime} | ${note['point']} point',
                              style: TextStyle(
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () {
                                    _showEditNoteDialog(note);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () {
                                    _confirmDeleteNote(note['id']);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      SizedBox(height: 15),
                      if (_timeLogs.length > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4.5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Time Logs',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              IconButton(
                                icon: Icon(_showTimeLogs
                                    ? Icons.expand_less
                                    : Icons.expand_more),
                                onPressed: () {
                                  setState(() {
                                    _showTimeLogs = !_showTimeLogs;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      if (_showTimeLogs)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _timeLogs.length,
                          itemBuilder: (context, index) {
                            final log = _timeLogs[index];
                            final startTime = formatDateTime(log['start_time']);
                            final endTime = formatDateTime(log['end_time']);
                            final duration = formatDuration(log['duration']);
                            return Card(
                              color: Colors.orange[100],
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.zero, // Remove rounded corners
                              ),
                              margin: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              elevation: 2,
                              child: ListTile(
                                contentPadding: EdgeInsets.only(
                                    left: 10, top: 0, right: 3, bottom: 0),
                                title: Text(
                                    'Duration: $duration ($startTime - $endTime) '),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 20), // Add extra spacing to avoid overflow
              ],
            ),
          ),
        ),
      ),
    );
  }
}
