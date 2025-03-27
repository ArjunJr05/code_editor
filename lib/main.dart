import 'package:codeed/login2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:codeed/api.dart'; // Make sure to import your AppState

void main() async {
  // Ensure Flutter binding is initialized before Supabase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your project URL and ANON key
  await Supabase.initialize(
    url: 'https://qlhokknudragpbnueexe.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsaG9ra251ZHJhZ3BibnVlZXhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI5MTkyNjAsImV4cCI6MjA1ODQ5NTI2MH0.BJSQeLonr6oYi63VeEr_0E05Zut9p-Aue-dnUoIBkig',
  );

  // Create an instance of AppState
  final appState = AppState();

  // Run the app with MultiProvider
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        // Add other providers if needed
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudySync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Primary color theme
        primarySwatch: Colors.blue,
        primaryColor: Colors.blue[700],

        // App-wide text theme
        textTheme: TextTheme(
          displayLarge: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
        ),

        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade700, width: 2)),
        ),

        // Button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24))),

        // App bar theme
        appBarTheme: AppBarTheme(
            color: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.blue[700]),
            titleTextStyle: TextStyle(
                color: Colors.blue[700],
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ),

      // Set login page as the home page
      home: LoginPage(),
    );
  }
}
