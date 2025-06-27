import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For encoding and decoding JSON data
import 'package:intl/intl.dart'; // For date formatting

class WriteNoteSessionPage extends StatefulWidget {
  @override
  _WriteNoteSessionPageState createState() => _WriteNoteSessionPageState();
}

class _WriteNoteSessionPageState extends State<WriteNoteSessionPage> {
  final TextEditingController _noteController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  List<Map<String, dynamic>> _notes = [];

  void _loadNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedNotesJson = prefs.getString('notes');
    if (savedNotesJson != null) {
      setState(() {
        _notes = List<Map<String, dynamic>>.from(json.decode(savedNotesJson));
        // Ensure all notes have the 'isCompleted' field set
        for (var note in _notes) {
          note['isCompleted'] ??= false;
        }
      });
    }
  }

  void _saveNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes', json.encode(_notes));
  }

  void _addNote() {
    String noteText = _noteController.text;

    if (noteText.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a note and select a date.')),
      );
      return;
    }

    Map<String, dynamic> newNote = {
      'note': noteText,
      'date': _selectedDate!.toIso8601String(),
      'isCompleted': false, // Default to false when a new note is added
    };
    setState(() {
      _notes.add(newNote);

      // Ensure only the last 30 notes are kept
      if (_notes.length > 30) {
        _notes.removeAt(0); // Remove the oldest note
      }
    });

    _saveNotes();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Note saved successfully.')),
    );

    _noteController.clear();
    setState(() {
      _selectedDate = null;
    });
  }

  void _toggleCompletion(int index) {
    setState(() {
      _notes[index]['isCompleted'] = !_notes[index]['isCompleted'];
    });
    _saveNotes();
  }

  void _pickDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Write Note Session'),
        backgroundColor: Colors.green[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _noteController,
              decoration: InputDecoration(labelText: 'Enter your note'),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Text(
                  _selectedDate == null
                      ? 'No date chosen!'
                      : 'Target Date: ${DateFormat.yMMMd().format(_selectedDate!)}',
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: () => _pickDate(context),
                  child: Text('Choose Date'),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addNote,
              child: Text('Save Note'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> note = _notes[index];
                  DateTime targetDate = DateTime.parse(note['date']);
                  bool isCompleted = note['isCompleted'] ?? false;
                  bool isPastDue =
                      !isCompleted && targetDate.isBefore(DateTime.now());

                  return ListTile(
                    title: Text(
                      note['note'],
                      style: TextStyle(
                        color: isCompleted
                            ? Colors.grey
                            : isPastDue
                                ? Colors.red
                                : Colors.black,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    subtitle: Text(
                      'Target Date: ${DateFormat.yMMMd().format(targetDate)}',
                    ),
                    trailing: Checkbox(
                      value: isCompleted,
                      onChanged: (bool? value) {
                        _toggleCompletion(index);
                      },
                    ),
                    onTap: () => _toggleCompletion(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
