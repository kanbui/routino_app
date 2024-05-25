import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskDialog extends StatefulWidget {
  final Map<String, dynamic>? task;
  final Function(Map<String, dynamic> task)? onSave;

  TaskDialog({this.task, this.onSave});

  @override
  _TaskDialogState createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _taskEstimateHoursController =
      TextEditingController();
  final TextEditingController _taskEstimateMinutesController =
      TextEditingController();
  DateTime? _dueTime;
  int _priority = 3;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _taskNameController.text = widget.task!['name'];
      _taskEstimateHoursController.text =
          (widget.task!['estimateTime'] ~/ 60).toString();
      _taskEstimateMinutesController.text =
          (widget.task!['estimateTime'] % 60).toString();
      _dueTime = DateTime.tryParse(widget.task!['dueTime']);
      _priority = widget.task!['priority'];
    }
  }

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

  void _submitTask() {
    if (_formKey.currentState!.validate()) {
      final int hours = int.tryParse(_taskEstimateHoursController.text) ?? 0;
      final int minutes =
          int.tryParse(_taskEstimateMinutesController.text) ?? 0;
      final estimateTime = (hours * 60) + minutes;
      final dueTimeFinal = _dueTime ?? DateTime.now();

      final task = {
        'name': _taskNameController.text,
        'estimateTime': estimateTime,
        'dueTime': dueTimeFinal.toIso8601String(),
        'priority': _priority,
      };

      if (widget.task != null) {
        task['id'] = widget.task!['id'];
      }

      widget.onSave?.call(task);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // Square corners
      ),
      title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
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
                    child: TextFormField(
                      controller: _taskEstimateHoursController,
                      decoration: InputDecoration(labelText: 'Hours'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
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
                        DropdownMenuItem(value: 1, child: Text('urgent')),
                        DropdownMenuItem(value: 2, child: Text('high')),
                        DropdownMenuItem(value: 3, child: Text('normal')),
                        DropdownMenuItem(value: 4, child: Text('low')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _priority = value ?? 3;
                        });
                      },
                      decoration: InputDecoration(labelText: 'Độ ưu tiên'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dueTime == null
                          ? 'Select Due Time'
                          : DateFormat('d MMM yyyy HH:mm').format(_dueTime!),
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
          onPressed: _submitTask,
          child: Text(widget.task == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
