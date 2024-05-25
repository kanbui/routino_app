import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

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
