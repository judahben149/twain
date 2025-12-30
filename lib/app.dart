import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twain/widgets/auth_gate.dart';


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twain',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
        textTheme: GoogleFonts.jostTextTheme(),
      ),
      home: const AuthGate(),
    );
  }
}