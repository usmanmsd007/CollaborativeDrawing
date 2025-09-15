import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'collab_drawing_screen.dart';
import 'bloc/drawing_bloc.dart';

// Import statements

// Minor code improvements
// Code cleanup
// Code maintenance

const supabaseUrl = 'https://jzzdjlzpoaapavehwbwz.supabase.co';

// Main function
Future<void> main() async {
  // Initialization
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    // Supabase initialization
    url: supabaseUrl,
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6emRqbHpwb2FhcGF2ZWh3Ynd6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2NzMwMzQsImV4cCI6MjA3NzI0OTAzNH0.SwyfLsHcPDeLOlTC7DDCMeQF_hOTX9Msf0zznp5FJD4',
  );
  runApp(const MyApp());
}

// App entry point
// App class definition

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Constructor

  @override
  Widget build(BuildContext context) { // Build method
    return BlocProvider(
      // Bloc provider setup
      create: (_) => DrawingBloc(),
      child: MaterialApp(
        // Material app configuration
        title: 'Collaborative Drawing',
        theme: ThemeData(
          // Theme configuration
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        // Home screen
        home: const CollaborativeDrawingScreen(),
      ),
    );
  }
}
