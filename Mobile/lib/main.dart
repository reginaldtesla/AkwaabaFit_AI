import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Laravel + Flutter')),
        body: const Center(child: LaravelDataFetcher()),
      ),
    );
  }
}

class LaravelDataFetcher extends StatefulWidget {
  const LaravelDataFetcher({super.key});

  @override
  State<LaravelDataFetcher> createState() => _LaravelDataFetcherState();
}

class _LaravelDataFetcherState extends State<LaravelDataFetcher> {
  String message = 'Press button to fetch data';

  Future<void> fetchData() async {
    // CHANGE THIS URL based on your device (see notes above)
    // For Android Emulator:
    final url = Uri.parse('http://10.132.213.232:8000/api/hello');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          message = data['message'];
        });
      } else {
        setState(() {
          message = 'Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        message = 'Connection failed. Is Laravel running?';
      });
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(message, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: fetchData, child: const Text('Call Laravel')),
      ],
    );
  }
}
