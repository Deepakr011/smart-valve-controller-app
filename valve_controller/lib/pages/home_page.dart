import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../services/mongodb_service.dart';
import 'mqtt_service.dart';
import 'dashboard_page.dart';
import 'login_page.dart';
import 'about_page.dart'; // Import the AboutPage
import 'write_note_session_page.dart'; // Import the WriteNodeSessionPage

class HomePage extends StatefulWidget {
  final String email;

  HomePage({required this.email});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showTextOverlay = false;
  String _deviceStatus = 'Offline';
  late MqttService _mqttService;
  String _mqttBroker = '';
  String _mqttSubscribeTopic = '';
  String _mqttPublishTopic = '';
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _initializeMqtt();
  }

  void _initializeMqtt() async {
    final email = widget.email;
    final user = await MongoDBService.userCollection?.findOne({'email': email});

    if (user != null) {
      final brokerAddress = user['mqtt_broker'];
      final subscribeTopic = user['mqtt_subscribe_topic'];
      final publishTopic = user['mqtt_publish_topic'];
      final deviceId = user['device_id'];

      setState(() {
        _mqttBroker = brokerAddress;
        _mqttSubscribeTopic = subscribeTopic;
        _mqttPublishTopic = publishTopic;
        _deviceId = deviceId;
      });

      final client =
          MqttServerClient(brokerAddress, 'flutter_client_unique_id');
      client.logging(on: true);
      client.port = 1883;
      client.keepAlivePeriod = 20;
      client.connectTimeoutPeriod = 50000;

      _mqttService =
          MqttService(client, subscribeTopic, publishTopic, (status) {
        setState(() {
          _deviceStatus = status == 'online' ? 'Online' : 'Offline';
        });
      });

      try {
        await _mqttService.connect();
      } catch (e) {
        print('Error connecting to MQTT broker: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to the MQTT broker.')),
        );
      }

    }
     else {
      print('MQTT settings not found for user');
    }
  }

  void _toggleTextOverlay() {
    setState(() {
      _showTextOverlay = !_showTextOverlay;
    });
  }

  void _showLoginDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
  context: context,
  builder: (BuildContext context) {
    return AlertDialog(
      title: Text('MQTT Setting'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: emailController,
            decoration: InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: passwordController,
            decoration: InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Check if the email or password fields are empty
            if (emailController.text.isEmpty || passwordController.text.isEmpty) {
              // Show a SnackBar or AlertDialog to notify the user to fill in the fields
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please enter both email and password'),
                ),
              );
            } else {
              // Proceed with login if both fields are filled
              _login(emailController.text, passwordController.text, context);
            }
          },
          child: Text('Login'),
        ),
      ],
    );
  },
);
  }
  void _login(String email, String password, BuildContext context) async {
    final user = await MongoDBService.loginUser(email, password);

    if (user != null) {
      Navigator.pop(context);
      _showMqttSettingsDialog(context, email);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed. Please check your credentials.')),
      );
    }
  }

  void _showMqttSettingsDialog(BuildContext context, String email) {
    final TextEditingController brokerController = TextEditingController();
    final TextEditingController subscribeTopicController =
        TextEditingController();
    final TextEditingController publishTopicController =
        TextEditingController();
    final TextEditingController deviceIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('MQTT Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: brokerController,
                decoration: InputDecoration(labelText: 'Broker Address'),
              ),
              TextField(
                controller: subscribeTopicController,
                decoration: InputDecoration(labelText: 'Subscribe Topic'),
              ),
              TextField(
                controller: publishTopicController,
                decoration: InputDecoration(labelText: 'Publish Topic'),
              ),
              TextField(
                controller: deviceIdController,
                decoration: InputDecoration(labelText: 'Device ID'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Check if any of the input fields are empty
                if (brokerController.text.isEmpty ||
                    subscribeTopicController.text.isEmpty ||
                    publishTopicController.text.isEmpty ||
                    deviceIdController.text.isEmpty) {
                  // Show a SnackBar or AlertDialog to notify the user to fill in the fields
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please fill in all fields before saving.'),
                    ),
                  );
                } else {
                  // Proceed with updating the MongoDB if all fields are filled
                  await MongoDBService.userCollection?.updateOne(
                    {'email': email},
                    {
                      r'$set': {
                        'mqtt_broker': brokerController.text,
                        'mqtt_subscribe_topic': subscribeTopicController.text,
                        'mqtt_publish_topic': publishTopicController.text,
                        'device_id': deviceIdController.text,
                      },
                    },
                  );
                  Navigator.pop(context);
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Irrigation App'),
        backgroundColor: Colors.green[700],
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_circle, color: Colors.white),
                SizedBox(width: 8.0),
                Flexible(
                  child: Text(
                    widget.email,
                    style: TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[700]!, Colors.green[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildDrawerItem(
              icon: Icons.home,
              text: 'Home',
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.login,
              text: 'MQTT Configuration',
              onTap: () => _showLoginDialog(context),
            ),
            _buildDrawerItem(
              icon: Icons.edit,
              text: 'Write Note',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WriteNoteSessionPage()),
              ),
            ),
            _buildDrawerItem(
              icon: Icons.logout,
              text: 'Logout',
              onTap: () => _handleLogout(context),
            ),
            _buildDrawerItem(
              icon: Icons.info,
              text: 'About App',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AboutPage()),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.green[50],
        child: Column(
          children: [
            Flexible(
              flex: 2,
              child: GestureDetector(
                onTap: _toggleTextOverlay,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8.0),
                        image: DecorationImage(
                          image: AssetImage('assets/images/homepageimage.png'),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 5,
                            blurRadius: 7,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    if (_showTextOverlay)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              "Effortlessly manage and monitor your agricultural irrigation valves with real-time control and insights.",
                              style: TextStyle(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10.0,
                                    color: Colors.black54,
                                    offset: Offset(3.0, 3.0),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Flexible(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[200]!, Colors.green[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 5,
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Device Status',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: Duration(milliseconds: 300),
                          child: Icon(
                            _deviceStatus == 'Online'
                                ? Icons.wifi
                                : Icons.wifi_off,
                            color: _deviceStatus == 'Online'
                                ? Colors.green
                                : Colors.red,
                            size: 30,
                            key: ValueKey(_deviceStatus),
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Text(
                          _deviceStatus,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _deviceStatus == 'Online'
                                  ? Colors.green
                                  : Colors.red),
                        ),
                        SizedBox(width: 16.0),
                        IconButton(
                          onPressed: () {
                            final mqttInfo =
                                'Broker: $_mqttBroker\nSubscribe Topic: $_mqttSubscribeTopic\nPublish Topic: $_mqttPublishTopic\nDevice ID: $_deviceId';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(mqttInfo)),
                            );
                          },
                          icon: Icon(Icons.info_outline),
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.grey[200]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 5,
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_deviceStatus == 'Online') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DashboardPage(
                                payload: _mqttService.getPayload(),
                                mqttService: _mqttService,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Device is offline. Cannot open dashboard.'),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.dashboard),
                      label: Text(
                        'Open Dashboard',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 12.0),
                        backgroundColor: Colors.green[
                            600], // Use backgroundColor instead of primary
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),

                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _buildDrawerItem({
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.green[700]),
      title: Text(
        text,
        style: TextStyle(fontSize: 16, color: Colors.black),
      ),
      tileColor: Colors.green[100],
      onTap: onTap,
    );
  }

  void _handleLogout(BuildContext context) async {
    // Show confirmation dialog before logging out
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Logout'),
          content: Text(
              'Are you sure you want to logout? This will change the settings.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Proceed with logout
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.clear(); // Clear all stored preferences

                // Navigate to LoginPage and remove all routes in the stack to prevent going back
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (Route<dynamic> route) => false,
                );
              },
              child: Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}
