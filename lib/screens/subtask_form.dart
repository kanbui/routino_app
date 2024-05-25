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
  final TextEditingController _subtaskEstimateHoursController =
      TextEditingController();
  final TextEditingController _subtaskEstimateMinutesController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.subtask != null) {
      _subtaskNameController.text = widget.subtask!['name'];
      final int estimateTime = widget.subtask!['estimateTime'] ?? 0;
      _subtaskEstimateHoursController.text = (estimateTime ~/ 60).toString();
      _subtaskEstimateMinutesController.text = (estimateTime % 60).toString();
    } else {
      _subtaskEstimateHoursController.text = '0';
      _subtaskEstimateMinutesController.text = '0';
    }
  }

  void _submitSubtask() {
    if (_formKey.currentState!.validate()) {
      final int hours = int.tryParse(_subtaskEstimateHoursController.text) ?? 0;
      final int minutes =
          int.tryParse(_subtaskEstimateMinutesController.text) ?? 0;
      final estimateTime = (hours * 60) + minutes;

      final subtask = {
        'name': _subtaskNameController.text,
        'estimateTime': estimateTime,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _subtaskNameController,
                decoration: InputDecoration(hintText: 'Subtask Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a subtask name' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _subtaskEstimateHoursController,
                      decoration: InputDecoration(labelText: 'Hours'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _subtaskEstimateMinutesController,
                      decoration: InputDecoration(labelText: 'Minutes'),
                      keyboardType: TextInputType.number,
                    ),
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
          onPressed: _submitSubtask,
          child: Text(widget.subtask == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
