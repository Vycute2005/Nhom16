import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/phrase.dart';
import '../services/phrase_service.dart';

class PhrasesScreen extends StatefulWidget {
  const PhrasesScreen({super.key});

  @override
  State<PhrasesScreen> createState() => _PhrasesScreenState();
}

class _PhrasesScreenState extends State<PhrasesScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final PhraseService _service = PhraseService();

  late Future<List<Phrase>> _phrasesFuture;

  @override
  void initState() {
    super.initState();
    _phrasesFuture = _service.getPhrases();
  }

  Future<void> speakVietnamese(String text) async {
    await flutterTts.setLanguage('vi-VN');
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vietnamese Phrases'),
      ),
      body: FutureBuilder<List<Phrase>>(
        future: _phrasesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load phrases:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final phrases = snapshot.data ?? [];

          if (phrases.isEmpty) {
            return const Center(
              child: Text('No phrases found.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: phrases.length,
            itemBuilder: (context, index) {
              final phrase = phrases[index];

              return Card(
                child: ExpansionTile(
                  title: Text(
                    phrase.vietnamese,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(phrase.english),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pronunciation: ${phrase.pronunciation}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Explanation: ${phrase.explanation}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(
                          Icons.volume_up,
                          color: Colors.teal,
                        ),
                        tooltip: 'Listen',
                        onPressed: () {
                          speakVietnamese(phrase.vietnamese);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}