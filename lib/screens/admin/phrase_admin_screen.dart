import 'package:flutter/material.dart';

import '../../models/phrase.dart';
import '../../services/phrase_service.dart';
import 'widgets/admin_delete_dialog.dart';
import 'widgets/admin_text_field.dart';

class PhraseAdminScreen extends StatefulWidget {
  const PhraseAdminScreen({super.key});

  @override
  State<PhraseAdminScreen> createState() =>
      _PhraseAdminScreenState();
}

class _PhraseAdminScreenState extends State<PhraseAdminScreen> {
  final PhraseService _service = PhraseService();

  late Future<List<Phrase>> _phrasesFuture;

  @override
  void initState() {
    super.initState();
    _loadPhrases();
  }

  void _loadPhrases() {
    _phrasesFuture = _service.getPhrases();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadPhrases();
    });
  }

  Future<void> _showPhraseForm({
    Phrase? phrase,
  }) async {
    final idController = TextEditingController(
      text: phrase?.id ?? '',
    );
    final vietnameseController = TextEditingController(
      text: phrase?.vietnamese ?? '',
    );
    final pronunciationController = TextEditingController(
      text: phrase?.pronunciation ?? '',
    );
    final englishController = TextEditingController(
      text: phrase?.english ?? '',
    );
    final explanationController = TextEditingController(
      text: phrase?.explanation ?? '',
    );

    final isEditing = phrase != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isEditing ? 'Edit Phrase' : 'Add Phrase',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdminTextField(
                  controller: idController,
                  labelText: 'ID',
                  enabled: !isEditing,
                ),
                const SizedBox(height: 12),

                AdminTextField(
                  controller: vietnameseController,
                  labelText: 'Vietnamese',
                ),
                const SizedBox(height: 12),

                AdminTextField(
                  controller: pronunciationController,
                  labelText: 'Pronunciation',
                ),
                const SizedBox(height: 12),

                AdminTextField(
                  controller: englishController,
                  labelText: 'English',
                ),
                const SizedBox(height: 12),

                AdminTextField(
                  controller: explanationController,
                  labelText: 'Explanation',
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final id = idController.text.trim();
                final vietnamese =
                vietnameseController.text.trim();
                final pronunciation =
                pronunciationController.text.trim();
                final english =
                englishController.text.trim();
                final explanation =
                explanationController.text.trim();

                if (id.isEmpty ||
                    vietnamese.isEmpty ||
                    english.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'ID, Vietnamese and English are required.',
                      ),
                    ),
                  );
                  return;
                }

                try {
                  if (isEditing) {
                    await _service.updatePhrase(
                      id: phrase.id,
                      vietnamese: vietnamese,
                      pronunciation: pronunciation,
                      english: english,
                      explanation: explanation,
                    );
                  } else {
                    await _service.createPhrase(
                      id: id,
                      vietnamese: vietnamese,
                      pronunciation: pronunciation,
                      english: english,
                      explanation: explanation,
                    );
                  }

                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Operation failed: $e',
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(
                isEditing ? 'Update' : 'Add',
              ),
            ),
          ],
        );
      },
    );

    idController.dispose();
    vietnameseController.dispose();
    pronunciationController.dispose();
    englishController.dispose();
    explanationController.dispose();

    if (result == true) {
      setState(() {
        _loadPhrases();
      });
    }
  }

  Future<void> _deletePhrase(Phrase phrase) async {
    final confirmed = await showAdminDeleteDialog(
      context,
      title: 'Delete Phrase',
      message:
      'Are you sure you want to delete "${phrase.vietnamese}"?',
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deletePhrase(phrase.id);

      if (mounted) {
        setState(() {
          _loadPhrases();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phrase deleted successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Phrases'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showPhraseForm();
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Phrase>>(
        future: _phrasesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
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
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    phrase.vietnamese,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    phrase.english,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _showPhraseForm(
                            phrase: phrase,
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deletePhrase(phrase);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}