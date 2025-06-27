import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemNavigator.pop()
import 'package:shared_preferences/shared_preferences.dart';
import 'services/mongodb_service.dart'; // Ensure this path is correct
import 'pages/home_page.dart'; // Ensure this path is correct
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(SplashScreen());

  try {
    await MongoDBService.connect(); // Initialize MongoDB connection
    runApp(MyApp());
  } catch (e) {
    runApp(MyApp(error: e.toString()));
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.greenAccent, Colors.green],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png', // Replace with your logo image
                  width: 150,
                  height: 150,
                ),
                SizedBox(height: 20),
                Text(
                  'Irrigation App',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Managing Your Water, Effortlessly',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 50),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final String? error;

  MyApp({this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Irrigation App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: error == null
          ? FutureBuilder<String?>(
              future: _checkLoginStatus(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SplashScreen(); // Show splash screen while checking login status
                } else if (snapshot.hasData && snapshot.data != null) {
                  return HomePage(
                      email: snapshot.data!); // Pass user email to HomePage
                } else if (snapshot.hasError) {
                  return _buildErrorScreen(context);
                } else {
                  return LoginPage();
                }
              },
            )
          : _buildErrorScreen(context),
      routes: {
        '/login': (context) => LoginPage(),
        '/home': (context) => HomePage(
            email: ModalRoute.of(context)!.settings.arguments as String),
      },
    );
  }

  Future<String?> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  Widget _buildErrorScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Network Error',
              style: TextStyle(fontSize: 24, color: Colors.red),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Retry by restarting the app
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => MyApp()),
                  (Route<dynamic> route) => false,
                );
              },
              child: Text('Retry'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Exit the app
                SystemNavigator.pop();
              },
              child: Text('Exit'),
            ),
          ],
        ),
      ),
    );
  }
}
