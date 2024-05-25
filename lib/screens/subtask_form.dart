import 'package:flutter/material.dart';

class SubtaskForm extends StatefulWidget {
  final Map<String, dynamic>? subtask;
  final Function(Map<String, dynamic> subtask)? onSave;

  SubtaskForm({this.subtask, this.onSave});

  @override
  _SubtaskFormState createState() => _SubtaskFormState();
}

class _SubtaskFormState extends State<SubtaskForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subtaskNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.subtask != null) {
      _subtaskNameController.text = widget.subtask!['name'];
    }
  }

  void _submitSubtask() {
    if (_formKey.currentState!.validate()) {
      final subtask = {
        'name': _subtaskNameController.text,
        'parentTaskId': widget.subtask?['parentTaskId'],
        'totalWorkTime': widget.subtask?['totalWorkTime'] ?? 0,
        'status': widget.subtask?['status'] ?? 'doing',
      };

      if (widget.subtask != null) {
        subtask['id'] = widget.subtask!['id'];
      }

      widget.onSave?.call(subtask);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // Square corners
      ),
      title: Text(widget.subtask == null ? 'Add Subtask' : 'Edit Subtask'),
      content: Container(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _subtaskNameController,
            decoration: InputDecoration(hintText: 'Subtask Name'),
            validator: (value) =>
                value!.isEmpty ? 'Please enter a subtask name' : null,
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
          onPressed: _submitSubtask,
          child: Text(widget.subtask == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
