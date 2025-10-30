import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/collab_drawing/presentation/screens/collaborative_drawing_screen.dart';
import 'bloc/drawing_bloc.dart';

const supabaseUrl = 'https://jzzdjlzpoaapavehwbwz.supabase.co';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6emRqbHpwb2FhcGF2ZWh3Ynd6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2NzMwMzQsImV4cCI6MjA3NzI0OTAzNH0.SwyfLsHcPDeLOlTC7DDCMeQF_hOTX9Msf0zznp5FJD4',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DrawingBloc(),
      child: MaterialApp(
        title: 'Collaborative Drawing',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const CollaborativeDrawingScreen(),
      ),
    );
  }
}
