import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  final String payload;
  final MqttService mqttService;

  DashboardPage({required this.payload, required this.mqttService});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isManualMode = false;
  bool _isRestMode = false;
  late List<bool> _valveStatuses;
  late List<String> _valveNames;
  late List<bool> _valveSkipped;
  String _currentTime = "";
  int _restHours = 0;
  int _restMinutes = 0;
  int _restSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeDashboard(widget.payload);
    _loadValveNames();
    _parseSkippedValvesFromPayload(widget.payload);
  }
 void _parseSkippedValvesFromPayload(String payload) {
    final data = _parsePayload(payload);
    final skippedValves = data['skipped_valves'];


///netti
    // Check if 'skipped_valves' exists and is a List or integer
    if (skippedValves != null) {
      if (skippedValves is List) {
        // If the list is empty or equals [0], treat it as no skipped valves
        if (skippedValves.isEmpty ||
            (skippedValves.length == 1 && skippedValves[0] == 0)) {
          print('No valves are skipped');
        } else {
          // Proceed with parsing the list of skipped valves
          _parseSkippedValves(skippedValves);
        }
      } else if (skippedValves is int && skippedValves == 0) {
        // Handle case where skippedValves is an integer and equals 0
        print('No valves are skipped');
      } else {
        // Handle any other unexpected case
        print('Unexpected skippedValves value: $skippedValves');
      }
    } else {
      print('No skipped valves data available');
    }
  }


  void _parseSkippedValves(List<dynamic> skippedValves) {
    setState(() {
      for (int i = 0; i < skippedValves.length; i++) {
        _valveSkipped[skippedValves[i] - 1] = true;
      }
    });
  }


  void _initializeDashboard(String payload) {
    final data = _parsePayload(payload);
    final int numberOfValves = data['number_of_valve'];

    _valveStatuses = List<bool>.filled(numberOfValves, false);
    _valveSkipped = List<bool>.filled(numberOfValves, false);
    _valveNames =
        List<String>.generate(numberOfValves, (index) => 'Valve ${index + 1}');

    _isManualMode = data['mode'] == 'manual';
    _isRestMode = data['mode'] == 'rest';
    _currentTime = data['Current Time'] ?? "";

    if (data['skipped_valves'] != null) {
      final skippedValves = data['skipped_valves'];
      if (skippedValves is List) {
        // Proceed only if skippedValves is a valid list
        _parseSkippedValves(skippedValves);
      } else if (skippedValves is int && skippedValves == 0) {
        // No skipped valves
        print('No valves are skipped');
      } else {
        // Handle any unexpected cases
        print('Unexpected skipped_valves value: $skippedValves');
      }
    }
  }


  Future<void> _loadValveNames() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList('valve_names');
    if (names != null && names.length == _valveNames.length) {
      setState(() {
        _valveNames = names;
      });
    }
  }

  Future<void> _saveValveNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('valve_names', _valveNames);
  }

  Map<String, dynamic> _parsePayload(String payload) {
    return json.decode(
        payload.replaceAll("Published data: ", "").replaceAll("'", '"'));
  }


  void _showIntervalPickerDialog(BuildContext context, int valveIndex) async {
    int selectedHours = 0;
    int selectedMinutes = 0;
    int selectedSeconds = 0;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Set Interval for ${_valveNames[valveIndex]}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selected Interval: ${selectedHours}h ${selectedMinutes}m ${selectedSeconds}s',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _buildSlider('Hours', selectedHours, 23, (value) {
                    setState(() {
                      selectedHours = value;
                    });
                  }),
                  _buildSlider('Minutes', selectedMinutes, 59, (value) {
                    setState(() {
                      selectedMinutes = value;
                    });
                  }),
                  _buildSlider('Seconds', selectedSeconds, 59, (value) {
                    setState(() {
                      selectedSeconds = value;
                    });
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'hours': selectedHours,
                      'minutes': selectedMinutes,
                      'seconds': selectedSeconds,
                    });
                  },
                  child: Text('Set Interval'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      _sendIntervalToHardware(context, valveIndex, result['hours']!,
          result['minutes']!, result['seconds']!);
    }
  }

  void _showRestIntervalDialog(BuildContext context) async {
    int selectedHours = _restHours;
    int selectedMinutes = _restMinutes;
    int selectedSeconds = _restSeconds;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context , setState) {
            return AlertDialog(
              title: Text('Set Rest Interval'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selected Interval: ${selectedHours}h ${selectedMinutes}m ${selectedSeconds}s',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _buildSlider('Hours', selectedHours, 23, (value) {
                    setState(() {
                      selectedHours = value;
                    });
                  }),
                  _buildSlider('Minutes', selectedMinutes, 59, (value) {
                    setState(() {
                      selectedMinutes = value;
                    });
                  }),
                  _buildSlider('Seconds', selectedSeconds, 59, (value) {
                    setState(() {
                      selectedSeconds = value;
                    });
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'hours': selectedHours,
                      'minutes': selectedMinutes,
                      'seconds': selectedSeconds,
                    });
                  },
                  child: Text('Set Rest Interval'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _restHours = result['hours']!;
        _restMinutes = result['minutes']!;
        _restSeconds = result['seconds']!;
      });

      _sendRestIntervalToHardware();
    }
  }

  void _sendRestIntervalToHardware() {
    final restInterval = {
      'rest_hours': _restHours,
      'rest_minutes': _restMinutes,
      'rest_seconds': _restSeconds,
    };
    final String message = json.encode(restInterval);

    widget.mqttService.publish(message);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Rest interval set: ${_restHours}h ${_restMinutes}m ${_restSeconds}s')),
    );
  }

  Widget _buildSlider(
      String label, int value, int max, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: $value',
          style: TextStyle(fontSize: 16),
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: max.toDouble(),
          divisions: max,
          label: '$value',
          onChanged: (double newValue) {
            onChanged(newValue.toInt());
          },
        ),
      ],
    );
  }

  void _sendIntervalToHardware(BuildContext context, int valveIndex, int hours,
      int minutes, int seconds) {
    final interval = {
      'valve': valveIndex + 1,
      'hours': hours,
      'minutes': minutes,
      'seconds': seconds,
      'manual_mode': _isManualMode,
    };
    final String message = json.encode(interval);

    widget.mqttService.publish(message);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Interval sent to ${_valveNames[valveIndex]}: ${hours}h ${minutes}m ${seconds}s')),
    );
  }

bool _isLoading = false; // Flag to indicate if loading is in progress

  void _toggleManualMode(bool value) async {
    if (_isRestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot switch modes while in Rest Mode')),
      );
      return;
    }

    if (_isLoading) return; // Prevent multiple presses during loading

    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      setState(() {
        _isManualMode = value;
      });

      final modeMessage = json.encode({'manual_mode': _isManualMode});
      widget.mqttService.publish(modeMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Switched to ${_isManualMode ? "Manual" : "Automatic"} Mode')),
      );

      await _sendOnValvesStatus();
    } finally {
      setState(() {
        _isLoading = false; // Stop loading after completion
      });
    }
  }

  void _toggleValveStatus(int valveIndex, bool isOn) async {
    if (_isRestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot change valve status in Rest Mode')),
      );
      return;
    }

    if (_isLoading) return; // Prevent multiple presses during loading

    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      setState(() {
        _valveStatuses[valveIndex] = isOn;
      });

      final valveMessage = json.encode({
        'valve': valveIndex + 1,
        'status': isOn ? 'on' : 'off',
        'manual_mode': _isManualMode,
      });

      widget.mqttService.publish(valveMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${_valveNames[valveIndex]} turned ${isOn ? "on" : "off"}')),
      );

      await _sendOnValvesStatus();
    } finally {
      setState(() {
        _isLoading = false; // Stop loading after completion
      });
    }
  }

// You can display a loading indicator in the UI
  Widget _buildLoadingIndicator() {
    if (_isLoading) {
      return CircularProgressIndicator();
    }
    return Container(); // Return an empty container if not loading
  }


  void _toggleValveSkipped(int valveIndex) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Skip Valve'),
          content: Text(
            'Are you sure you want to ${_valveSkipped[valveIndex] ? 'unskip' : 'skip'} Valve ${valveIndex + 1}?',
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
                setState(() {
                  _valveSkipped[valveIndex] = !_valveSkipped[valveIndex];
                });
                _sendSkippedValvesToHardware();
                Navigator.pop(context);
              },
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _sendSkippedValvesToHardware() {
    final skippedValves = [];
    for (int i = 0; i < _valveSkipped.length; i++) {
      if (_valveSkipped[i]) {
        skippedValves.add(i + 1);
      }
    }

    final skippedValvesMessage = json.encode({
      'skipped_valves': skippedValves,
    });

    widget.mqttService.publish(skippedValvesMessage);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Skipped valves updated: ${skippedValves.join(", ")}')),
    );
  }

  Future<void> _sendOnValvesStatus() async {
    final List<int> onValves = [];
    for (int i = 0; i < _valveStatuses.length; i++) {
      if (_valveStatuses[i]) {
        onValves.add(i + 1); // Collect valves that are on
      }
    }

    final onValvesMessage = json.encode({
      'on_valves': onValves,
      'manual_mode': _isManualMode,
    });

    widget.mqttService.publish(onValvesMessage);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('On valves updated: ${onValves.join(", ")}')),
    );
  }



  void _editValveName(int valveIndex) async {
    if (_isRestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot edit valve names in Rest Mode')),
      );
      return;
    }

    final TextEditingController _controller = TextEditingController();
    _controller.text = _valveNames[valveIndex];

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Valve Name'),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: 'Enter new name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _controller.text);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _valveNames[valveIndex] = newName;
      });

      try {
        await _saveValveNames();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Valve name saved successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save valve name.')),
        );
      }
    }
  }

  void _exitRestMode(BuildContext context) async {
    final bool? confirmExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Exit Rest Mode'),
          content: Text('Are you sure you want to exit Rest Mode?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Exit'),
            ),
          ],
        );
      },
    );

    if (confirmExit == true) {
      setState(() {
        _isRestMode = false;
      });

      final exitRestModeMessage = json.encode({'mode': 'automatic'});
      widget.mqttService.publish(exitRestModeMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Rest Mode exited, system is now in Automatic Mode')),
      );
    }
  }
  

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Irrigation Dashboard'),
      backgroundColor: Colors.green[800],
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.help_outline),
          onPressed: () {
            // Add help functionality here
          },
        ),
      ],
    ),
    body: StreamBuilder<String>(
      stream: widget.mqttService.mqttStream,
      initialData: widget.payload,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final data = _parsePayload(snapshot.data!);
          final int numberOfValves = data['number_of_valve'];
          final List<dynamic> openValves = List.from(data['open_valve']);
          final List<String> setPeriod =
              List<String>.from(data['set period']);
          _currentTime = data['Current Time'] ?? "";

          // Update the valves and modes based on the latest snapshot data
          _isManualMode = data['mode'] == 'manual';
          _isRestMode = data['mode'] == 'rest';

          if (_valveStatuses.length != numberOfValves) {
            _valveStatuses = List<bool>.filled(numberOfValves, false);
          }

          if (_valveSkipped.length != numberOfValves) {
            _valveSkipped = List<bool>.filled(numberOfValves, false);
          }

          if (_valveNames.length != numberOfValves) {
            _valveNames = List<String>.generate(
                numberOfValves, (index) => 'Valve ${index + 1}');
          }

          for (int i = 0; i < numberOfValves; i++) {
            _valveStatuses[i] = openValves.contains(i + 1);
          }

          _updateSkippedValves(data);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Manual Mode:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Switch(
                        value: _isManualMode,
                        onChanged: _toggleManualMode,
                        activeColor: Colors.green[800],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (_isRestMode)
                    Column(
                      children: [
                        Center(
                          child: Text(
                            'System is in Rest Mode',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            onPressed: () => _exitRestMode(context),
                            child: Text('Exit Rest Mode'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            onPressed: () => _showRestIntervalDialog(context),
                            child: Text('Set Rest Interval'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!_isRestMode) ...[
                    Text(
                      'Valves:',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Column(
                        children: List.generate(_valveStatuses.length, (index) {
                          bool isOpen = _valveStatuses[index];
                          bool isSkipped = _valveSkipped[index];
                          String setTime = setPeriod.length > index
                              ? setPeriod[index]
                              : "N/A";

                          return Container(
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.all(12),
  width: double.infinity,
  decoration: BoxDecoration(
    color: isSkipped
        ? Colors.grey[300]  // Grayed out background for skipped valves
        : isOpen
            ? Colors.green[100]
            : Colors.red[100],
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        spreadRadius: 2,
        blurRadius: 5,
        offset: Offset(0, 3),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            isSkipped
                ? Icons.pause_circle_filled  // Clear pause icon for skipped
                : isOpen
                    ? Icons.check_circle_outline
                    : Icons.cancel,
            color: isSkipped
                ? Colors.grey[600]  // Gray color for skipped valves
                : isOpen
                    ? Colors.green[700]
                    : Colors.red[700],
            size: 36,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              _valveNames[index],
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSkipped
                    ? Colors.grey[600]  // Gray text for skipped valves
                    : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _editValveName(index),
            tooltip: 'Edit Valve Name',
          ),
          if (!_isManualMode)
            IconButton(
              icon: Icon(Icons.timer, color: Colors.grey[600]),
              onPressed: () => _showIntervalPickerDialog(context, index),
              tooltip: 'Set Interval Period',
            ),
          
          // Enhanced Skip Button with Tooltip, Animation, and Label
          GestureDetector(
            onTap: () => _toggleValveSkipped(index),
            child: Tooltip(
              message: isSkipped ? 'Unskip Valve' : 'Skip Valve',  // Tooltip for skipped/active state
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSkipped ? Colors.grey[600] : Colors.blue,  // Color transition for button
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isSkipped
                          ? Colors.grey.withOpacity(0.5)
                          : Colors.blue.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: Offset(0, 3), // Shadow position
                    ),
                  ],
                ),
                child: Icon(
                  isSkipped ? Icons.skip_next : Icons.skip_previous,  // Skipping icon
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Text(
            isSkipped ? 'Skipped' : 'Active',  // Label to indicate skipped/active state
            style: TextStyle(
              fontSize: 16,
              color: isSkipped ? Colors.grey[600] : Colors.blue,
            ),
          ),
        ],
      ),
      SizedBox(height: 12),
      if (isOpen)
        Text(
          'Current Time: $_currentTime',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      Text(
        'Set Interval: $setTime',
        style: TextStyle(
          fontSize: 18,
          color: Colors.black54,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      if (_isManualMode) ...[
        SizedBox(height: 12),
        SwitchListTile(
          title: Text(
            'Turn ${_valveStatuses[index] ? "Off" : "On"} ${_valveNames[index]}',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          value: _valveStatuses[index],
          onChanged: (bool value) {
            _toggleValveStatus(index, value);
          },
          activeColor: Colors.green[700],
        ),
      ],
    ],
  ),
);
}),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => _showRestIntervalDialog(context),
                        child: Text('Set Rest Interval'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    ),
  );
}

void _updateSkippedValves(Map<String, dynamic> data) {
  if (data['skipped_valves'] != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        for (int i = 0; i < _valveSkipped.length; i++) {
          _valveSkipped[i] = data['skipped_valves'].contains(i + 1);
        }
      });
    });
  }
}}