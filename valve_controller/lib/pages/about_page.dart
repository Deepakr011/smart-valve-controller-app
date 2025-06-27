import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About Smart Valve Controller'),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Valve Controller',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Developer: Deepak R',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            Text(
              'Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'The Smart Valve Controller is an advanced solution designed to automate and optimize irrigation processes, addressing challenges like unpredictable power supply in agricultural settings. This app provides real-time control and monitoring of irrigation valves, ensuring efficient water distribution and minimal manual intervention.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 20),
            Text(
              'Key Features',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              '• Automated Valve Control: Manage irrigation schedules automatically.\n'
              '• Interval-based Operation: Customize watering intervals for precise control.\n'
              '• Power Resilience: Seamlessly resumes operations after power outages.\n'
              '• Multi-Valve Support: Handle multiple valves individually or in batches.\n'
              '• Low Power Consumption: Designed for efficient energy use.\n'
              '• User-friendly Interface: Easy configuration and monitoring of irrigation systems.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 20),
            Text(
              'Developer Contact',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'For any inquiries or support, please contact Deepak R at deepak948267@gmail.com.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
