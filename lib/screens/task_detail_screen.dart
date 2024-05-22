import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';

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
  int _remainingTime = 0;
  bool _isWorking = true;
  Timer? _timer;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _pomodoroDuration = 25; // Default value
  int _breakDuration = 5; // Default value

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadTask();
    _loadSubtasks();
    _loadNotes(); // Load notes for the task
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
    final tasks = await _dbHelper.getTasks();
    setState(() {
      _task = tasks.firstWhere(
        (t) => t['id'] == widget.taskId,
        orElse: () =>
            <String, dynamic>{}, // Return an empty map instead of null
      );
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

  String formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return 'No due';
    }
    final dateTime = DateTime.parse(dateTimeString);
    final formatter = DateFormat('d MMM HH:mm');
    return formatter.format(dateTime);
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
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
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

  String formatDuration(int totalSeconds) {
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

  void _showAddSubtaskDialog() {
    TextEditingController _subtaskNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // Square corners
          ),
          title: Text('Add Subtask'),
          content: Container(
            width: double.maxFinite,
            child: TextField(
              controller: _subtaskNameController,
              decoration: InputDecoration(hintText: 'Subtask Name'),
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
              onPressed: () async {
                await _dbHelper.insertSubtask({
                  'parentTaskId': widget.taskId,
                  'name': _subtaskNameController.text,
                  'totalWorkTime': 0,
                  'status': 'doing',
                });
                _loadSubtasks();
                Navigator.pop(context);
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditSubtaskDialog(Map<String, dynamic> subtask) {
    TextEditingController _subtaskNameController =
        TextEditingController(text: subtask['name']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // Square corners
          ),
          title: Text('Edit Subtask'),
          content: Container(
            width: double.maxFinite,
            child: TextField(
              controller: _subtaskNameController,
              decoration: InputDecoration(hintText: 'Subtask Name'),
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
                final updatedSubtask = Map<String, dynamic>.from(subtask);
                updatedSubtask['name'] = _subtaskNameController.text;
                _dbHelper.updateSubtask(updatedSubtask);
                _loadSubtasks();
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
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

  void _startSubtaskTimer(Map<String, dynamic> subtask) {
    // Implement timer logic for subtasks if needed
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
      ),
      body: Padding(
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
                    SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ElevatedButton(
                        onPressed: _showAddSubtaskDialog,
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
                        'Subtasks:',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ..._subtasks.map((subtask) {
                      final subtaskTotalWorkTimeFormatted =
                          formatDuration(subtask['totalWorkTime']);
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
                          title: Text(
                            subtask['name'],
                            style: TextStyle(
                              decoration: subtask['status'] == 'completed'
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
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
                                  _showEditSubtaskDialog(subtask);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () {
                                  _confirmDeleteSubtask(subtask['id']);
                                },
                              ),
                            ],
                          ),
                          subtitle:
                              Text('Worked: $subtaskTotalWorkTimeFormatted'),
                        ),
                      );
                    }).toList(),
                    SizedBox(height: 20),
                    if (_notes.isNotEmpty)
                      Text(
                        'Notes:',
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
                        margin:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        elevation: 2,
                        child: ListTile(
                          title: Text('${note['icon']} ${note['content']}'),
                          subtitle:
                              Text('${createdTime} | ${note['point']} point'),
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
                  ],
                ),
              ),
              SizedBox(height: 20), // Add extra spacing to avoid overflow
            ],
          ),
        ),
      ),
    );
  }
}

class NoteDialog extends StatefulWidget {
  final int taskId;
  final Map<String, dynamic>? note;
  final Function(Map<String, dynamic>)? onNoteAdded;
  final Function(Map<String, dynamic>)? onNoteEdited;

  NoteDialog({
    required this.taskId,
    this.note,
    this.onNoteAdded,
    this.onNoteEdited,
  });

  @override
  _NoteDialogState createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  final _formKey = GlobalKey<FormState>();
  String _icon = '';
  String _content = '';
  int _point = 1;
  TextEditingController _contentController = TextEditingController();
  TextEditingController _iconController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper(); // Sử dụng _dbHelper

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _icon = widget.note!['icon'];
      _content = widget.note!['content'];
      _point = widget.note!['point'];
      _iconController.text = _icon;
      _contentController.text = _content;
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final DateTime now = DateTime.now();
      final note = {
        'id': widget.note?['id'],
        'icon': _iconController.text,
        'content': _contentController.text,
        'task_id': widget.taskId,
        'point': _point,
        'createdAt': now.toIso8601String()
      };
      if (widget.note == null) {
        // Add new note
        _dbHelper.insertNote(note).then((id) {
          note['id'] = id;
          if (widget.onNoteAdded != null) {
            widget.onNoteAdded!(note);
          }
          Navigator.of(context).pop();
        });
      } else {
        // Edit existing note
        _dbHelper.updateNote(note).then((_) {
          if (widget.onNoteEdited != null) {
            widget.onNoteEdited!(note);
          }
          Navigator.of(context).pop();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // Square corners
      ),
      title: Text(widget.note == null ? 'Add Note' : 'Edit Note'),
      content: Container(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _iconController,
                decoration: InputDecoration(hintText: 'Icon'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter an icon' : null,
              ),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(hintText: 'Content'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter content' : null,
              ),
              DropdownButtonFormField<int>(
                decoration: InputDecoration(labelText: 'Point'),
                value: _point,
                onChanged: (value) => setState(() => _point = value!),
                items: List.generate(
                    5,
                    (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1}'),
                        )),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(widget.note == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
