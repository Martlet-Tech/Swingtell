import 'package:flutter/material.dart';
import 'core/models/book.dart';
import 'features/home/home_screen.dart';
import 'features/reader/reader_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwingTell 阅读器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/reader') {
          final book = settings.arguments as Book;
          return MaterialPageRoute(
            builder: (_) => ReaderScreen(book: book),
          );
        }
        return null;
      },
    );
  }
}
