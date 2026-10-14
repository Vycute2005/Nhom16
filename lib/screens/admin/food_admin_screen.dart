import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/food.dart';
import '../../services/food_service.dart';
import '../../services/upload_service.dart';
import 'widgets/admin_delete_dialog.dart';
import 'widgets/admin_text_field.dart';

class FoodAdminScreen extends StatefulWidget {
  const FoodAdminScreen({super.key});

  @override
  State<FoodAdminScreen> createState() => _FoodAdminScreenState();
}

class _FoodAdminScreenState extends State<FoodAdminScreen> {
  final FoodService _service = FoodService();
  final UploadService _uploadService = UploadService();

  late Future<List<Food>> _foodsFuture;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  void _loadFoods() {
    _foodsFuture = _service.getFoods();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadFoods();
    });
  }

  Future<void> _showFoodForm({Food? food}) async {
    final idController = TextEditingController(
      text: food?.id ?? '',
    );

    final nameController = TextEditingController(
      text: food?.name ?? '',
    );

    final descriptionController = TextEditingController(
      text: food?.description ?? '',
    );

    final isEditing = food != null;

    Uint8List? selectedImageBytes;
    String? selectedImageName;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasNewImage = selectedImageBytes != null;

            return AlertDialog(
              title: Text(
                isEditing ? 'Edit Food' : 'Add Food',
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
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
                        controller: nameController,
                        labelText: 'Name',
                      ),
                      const SizedBox(height: 12),

                      AdminTextField(
                        controller: descriptionController,
                        labelText: 'Description',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Image',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (hasNewImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            selectedImageBytes!,
                            width: 180,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                      else if (isEditing &&
                          food.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '${ApiConfig.baseUrl}/api/images/${food.imageUrl}',
                            width: 180,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) {
                              return Container(
                                width: 180,
                                height: 120,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          width: 180,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey,
                            ),
                            borderRadius:
                            BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),

                      const SizedBox(height: 8),

                      if (selectedImageName != null)
                        Text(
                          selectedImageName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),

                      const SizedBox(height: 8),

                      OutlinedButton.icon(
                        onPressed: () async {
                          final file =
                          await FilePicker.pickFile(
                            type: FileType.image,
                          );

                          if (file == null) {
                            return;
                          }

                          final bytes =
                          await file.readAsBytes();

                          setDialogState(() {
                            selectedImageBytes = bytes;
                            selectedImageName = file.name;
                          });
                        },
                        icon: const Icon(Icons.image),
                        label: Text(
                          isEditing
                              ? 'Choose New Image'
                              : 'Choose Image',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final id = idController.text.trim();
                    final name = nameController.text.trim();
                    final description =
                    descriptionController.text.trim();

                    if (id.isEmpty || name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ID and Name are required.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      String imagePath =
                      isEditing ? food.imageUrl : '';

                      if (selectedImageBytes != null &&
                          selectedImageName != null) {
                        imagePath =
                        await _uploadService.uploadImage(
                          bytes: selectedImageBytes!,
                          fileName: selectedImageName!,
                        );
                      }

                      if (isEditing) {
                        await _service.updateFood(
                          id: food.id,
                          name: name,
                          description: description,
                          imageUrl: imagePath,
                        );
                      } else {
                        await _service.createFood(
                          id: id,
                          name: name,
                          description: description,
                          imageUrl: imagePath,
                        );
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
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
      },
    );

    idController.dispose();
    nameController.dispose();
    descriptionController.dispose();

    if (result == true && mounted) {
      setState(() {
        _loadFoods();
      });
    }
  }

  Future<void> _deleteFood(Food food) async {
    final confirmed = await showAdminDeleteDialog(
      context,
      title: 'Delete Food',
      message:
      'Are you sure you want to delete "${food.name}"?',
    );

    if (!confirmed) {
      return;
    }

    try {
      await _service.deleteFood(food.id);

      if (mounted) {
        setState(() {
          _loadFoods();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Food deleted successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Delete failed: $e',
            ),
          ),
        );
      }
    }
  }

  Widget _buildFoodImage(Food food) {
    if (food.imageUrl.isEmpty) {
      return const Icon(
        Icons.restaurant_menu,
        size: 40,
      );
    }

    if (food.imageUrl.startsWith('assets/')) {
      return Image.asset(
        food.imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) {
          return const Icon(
            Icons.restaurant_menu,
            size: 40,
          );
        },
      );
    }

    return Image.network(
      '${ApiConfig.baseUrl}/api/images/${food.imageUrl}',
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) {
        return const Icon(
          Icons.restaurant_menu,
          size: 40,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Foods'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showFoodForm();
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Food>>(
        future: _foodsFuture,
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
                'Failed to load foods:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final foods = snapshot.data ?? [];

          if (foods.isEmpty) {
            return const Center(
              child: Text('No foods found.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: foods.length,
            itemBuilder: (context, index) {
              final food = foods[index];

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: ListTile(
                  leading: _buildFoodImage(food),
                  title: Text(
                    food.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    food.description,
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
                          _showFoodForm(food: food);
                        },
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteFood(food);
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