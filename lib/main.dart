import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';



Future<void> initTimeZone() async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Chicago')); // Set the correct time zone location
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  runApp(QuoteApp());
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) async {
      print('Notification tapped: ${details.payload}');
    },
  );
}

class QuoteApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Quotes',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white70,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
          bodySmall: TextStyle(color: Colors.black87),
        ),
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Color(0xFF1A1A1A),
        cardColor: Color(0xFF2A2A2A),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
          bodySmall: TextStyle(color: Colors.white70),
        ),
        fontFamily: 'Roboto',
      ),
      themeMode: ThemeMode.system, // Automatically switches based on system settings
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToQuoteScreen();
  }

  Future<void> _navigateToQuoteScreen() async {
    await Future.delayed(Duration(seconds: 3)); // Splash screen delay
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => QuoteScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [Colors.grey.shade800, Colors.black]
                : [Colors.teal, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.format_quote,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              Text(
                'Daily Quotes',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuoteScreen extends StatefulWidget {
  @override
  _QuoteScreenState createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  String currentQuote = "Loading...";
  String errorMessage = "";
  bool isLoading = true;
  bool notificationsEnabled = false;
  TimeOfDay notificationTime = TimeOfDay(hour: 9, minute: 0);

  final List<Map<String, String>> fallbackQuotes = [
    {
      "content": "Success is not final, failure is not fatal: it is the courage to continue that counts.",
      "author": "Winston Churchill"
    },
    {
      "content": "The only way to do great work is to love what you do.",
      "author": "Steve Jobs"
    },
    {
      "content": "Life is what happens when you're busy making other plans.",
      "author": "John Lennon"
    }
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await loadSettings();
    await fetchQuote();
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
        int hour = prefs.getInt('notification_hour') ?? 9;
        int minute = prefs.getInt('notification_minute') ?? 0;
        notificationTime = TimeOfDay(hour: hour, minute: minute);
      });
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', notificationsEnabled);
      await prefs.setInt('notification_hour', notificationTime.hour);
      await prefs.setInt('notification_minute', notificationTime.minute);
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  String getRandomFallbackQuote() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final index = random % fallbackQuotes.length;
    final quote = fallbackQuotes[index];
    return '"${quote['content']}" - ${quote['author']}';
  }

  Future<void> fetchQuote() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.quotable.io/random'),
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('The connection has timed out. Please check your internet connection and try again.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentQuote = '"${data['content']}" - ${data['author']}';
          isLoading = false;
        });
      } else {
        throw HttpException('Failed to load quote (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('Error fetching quote: $e');
      setState(() {
        errorMessage = 'Failed to load quote. Using offline quote instead.';
        currentQuote = getRandomFallbackQuote();
        isLoading = false;
      });
    }

    if (notificationsEnabled) {
      await scheduleNotification();
    }
  }

  // Make sure to initialize your notifications first
Future<void> initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> scheduleNotification() async {
  if (!notificationsEnabled) return;

  try {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      notificationTime.hour,
      notificationTime.minute,
    );

    // If the scheduled time is before the current time, set it for the next day
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(Duration(days: 1));
    }

    await flutterLocalNotificationsPlugin.schedule(
      0,
      'Daily Motivation',
      currentQuote,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_quotes',
          'Daily Quotes',
          channelDescription: 'Daily motivational quotes',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
    );
  } catch (e) {
    print('Error scheduling notification: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Motivation'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [Colors.grey.shade800, Colors.black]
                : [Colors.teal.shade300, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: fetchQuote,
          child: ListView(
            padding: EdgeInsets.all(16.0),
            children: [
              SizedBox(height: 40),
              Text(
                isLoading ? 'Loading Quote...' : currentQuote,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Text(
                    errorMessage,
                    style: TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(height: 40),
              SwitchListTile(
                title: Text('Enable Daily Notifications'),
                value: notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    notificationsEnabled = value;
                  });
                  saveSettings();
                  if (value) {
                    scheduleNotification();
                  }
                },
                secondary: Icon(Icons.notifications),
              ),
              ListTile(
                title: Text('Notification Time'),
                subtitle: Text('${notificationTime.format(context)}'),
                trailing: Icon(Icons.access_time),
                onTap: () async {
                  final TimeOfDay? selectedTime = await showTimePicker(
                    context: context,
                    initialTime: notificationTime,
                  );
                  if (selectedTime != null) {
                    setState(() {
                      notificationTime = selectedTime;
                    });
                    saveSettings();
                    if (notificationsEnabled) {
                      scheduleNotification();
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
