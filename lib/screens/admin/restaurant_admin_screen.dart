import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/food.dart';
import '../../models/restaurant.dart';
import '../../services/food_service.dart';
import '../../services/restaurant_service.dart';
import '../../services/upload_service.dart';
import 'widgets/admin_delete_dialog.dart';
import 'widgets/admin_text_field.dart';

class RestaurantAdminScreen extends StatefulWidget {
  const RestaurantAdminScreen({super.key});

  @override
  State<RestaurantAdminScreen> createState() =>
      _RestaurantAdminScreenState();
}

class _RestaurantAdminScreenState
    extends State<RestaurantAdminScreen> {
  final RestaurantService _service = RestaurantService();
  final FoodService _foodService = FoodService();
  final UploadService _uploadService = UploadService();

  late Future<List<Restaurant>> _restaurantsFuture;
  late Future<List<Food>> _foodsFuture;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
    _loadFoods();
  }

  void _loadRestaurants() {
    _restaurantsFuture = _service.getRestaurants();
  }

  void _loadFoods() {
    _foodsFuture = _foodService.getFoods();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadRestaurants();
      _loadFoods();
    });
  }

  Future<void> _showRestaurantForm({
    Restaurant? restaurant,
  }) async {
    final foods = await _foodsFuture;

    if (!mounted) {
      return;
    }

    if (foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please create a Food before creating a Restaurant.',
          ),
        ),
      );
      return;
    }

    final idController = TextEditingController(
      text: restaurant?.id ?? '',
    );

    final nameController = TextEditingController(
      text: restaurant?.name ?? '',
    );

    final addressController = TextEditingController(
      text: restaurant?.address ?? '',
    );

    final latitudeController = TextEditingController(
      text: restaurant?.latitude.toString() ?? '',
    );

    final longitudeController = TextEditingController(
      text: restaurant?.longitude.toString() ?? '',
    );

    final ratingController = TextEditingController(
      text: restaurant?.rating.toString() ?? '',
    );

    final isEditing = restaurant != null;

    String? selectedFoodId = restaurant?.foodId;

    if (selectedFoodId != null &&
        !foods.any(
              (food) => food.id == selectedFoodId,
        )) {
      selectedFoodId = null;
    }

    Uint8List? selectedImageBytes;
    String? selectedImageName;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasNewImage =
                selectedImageBytes != null;

            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Edit Restaurant'
                    : 'Add Restaurant',
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
                        controller: addressController,
                        labelText: 'Address',
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: selectedFoodId,
                        decoration: const InputDecoration(
                          labelText: 'Food',
                          border: OutlineInputBorder(),
                        ),
                        items: foods.map((food) {
                          return DropdownMenuItem<String>(
                            value: food.id,
                            child: Text(food.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedFoodId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      AdminTextField(
                        controller: latitudeController,
                        labelText: 'Latitude',
                        keyboardType:
                        const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      AdminTextField(
                        controller: longitudeController,
                        labelText: 'Longitude',
                        keyboardType:
                        const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      AdminTextField(
                        controller: ratingController,
                        labelText: 'Rating',
                        keyboardType:
                        const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
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
                          borderRadius:
                          BorderRadius.circular(8),
                          child: Image.memory(
                            selectedImageBytes!,
                            width: 180,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                      else if (isEditing &&
                          restaurant.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius:
                          BorderRadius.circular(8),
                          child: Image.network(
                            '${ApiConfig.baseUrl}/api/images/${restaurant.imageUrl}',
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
                          overflow:
                          TextOverflow.ellipsis,
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
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    final id =
                    idController.text.trim();

                    final name =
                    nameController.text.trim();

                    final address =
                    addressController.text.trim();

                    final latitudeText =
                    latitudeController.text.trim();

                    final longitudeText =
                    longitudeController.text.trim();

                    final ratingText =
                    ratingController.text.trim();

                    if (id.isEmpty ||
                        name.isEmpty ||
                        selectedFoodId == null ||
                        latitudeText.isEmpty ||
                        longitudeText.isEmpty ||
                        ratingText.isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ID, Name, Food, Latitude, Longitude and Rating are required.',
                          ),
                        ),
                      );
                      return;
                    }

                    final latitude =
                    double.tryParse(
                      latitudeText,
                    );

                    final longitude =
                    double.tryParse(
                      longitudeText,
                    );

                    final rating =
                    double.tryParse(
                      ratingText,
                    );

                    if (latitude == null ||
                        longitude == null ||
                        rating == null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Latitude, Longitude and Rating must be valid numbers.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      String imagePath = isEditing
                          ? restaurant.imageUrl
                          : '';

                      if (selectedImageBytes != null &&
                          selectedImageName != null) {
                        imagePath =
                        await _uploadService
                            .uploadImage(
                          bytes:
                          selectedImageBytes!,
                          fileName:
                          selectedImageName!,
                          folder: 'restaurants',
                        );
                      }

                      if (isEditing) {
                        await _service
                            .updateRestaurant(
                          id: restaurant.id,
                          name: name,
                          address: address,
                          foodId: selectedFoodId!,
                          latitude: latitude,
                          longitude: longitude,
                          imageUrl: imagePath,
                          rating: rating,
                        );
                      } else {
                        await _service
                            .createRestaurant(
                          id: id,
                          name: name,
                          address: address,
                          foodId: selectedFoodId!,
                          latitude: latitude,
                          longitude: longitude,
                          imageUrl: imagePath,
                          rating: rating,
                        );
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(
                          dialogContext,
                          true,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
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
    addressController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    ratingController.dispose();

    if (result == true && mounted) {
      setState(() {
        _loadRestaurants();
      });
    }
  }

  Future<void> _deleteRestaurant(
      Restaurant restaurant,
      ) async {
    final confirmed =
    await showAdminDeleteDialog(
      context,
      title: 'Delete Restaurant',
      message:
      'Are you sure you want to delete "${restaurant.name}"?',
    );

    if (!confirmed) {
      return;
    }

    try {
      await _service.deleteRestaurant(
        restaurant.id,
      );

      if (mounted) {
        setState(() {
          _loadRestaurants();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Restaurant deleted successfully.',
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

  Widget _buildRestaurantImage(
      Restaurant restaurant,
      ) {
    if (restaurant.imageUrl.isEmpty) {
      return const Icon(
        Icons.restaurant,
        size: 40,
      );
    }

    if (restaurant.imageUrl.startsWith('assets/')) {
      return Image.asset(
        restaurant.imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) {
          return const Icon(
            Icons.restaurant,
            size: 40,
          );
        },
      );
    }

    return Image.network(
      '${ApiConfig.baseUrl}/api/images/${restaurant.imageUrl}',
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) {
        return const Icon(
          Icons.restaurant,
          size: 40,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Restaurants',
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      floatingActionButton:
      FloatingActionButton(
        onPressed: () {
          _showRestaurantForm();
        },
        child: const Icon(Icons.add),
      ),

      body: FutureBuilder<List<Restaurant>>(
        future: _restaurantsFuture,
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
                'Failed to load restaurants:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final restaurants =
              snapshot.data ?? [];

          if (restaurants.isEmpty) {
            return const Center(
              child: Text(
                'No restaurants found.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final restaurant =
              restaurants[index];

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: ListTile(
                  leading:
                  _buildRestaurantImage(
                    restaurant,
                  ),

                  title: Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  subtitle: Text(
                    '${restaurant.address}\n'
                        'Rating: ${restaurant.rating}',
                  ),

                  isThreeLine: true,

                  trailing: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon:
                        const Icon(Icons.edit),
                        onPressed: () {
                          _showRestaurantForm(
                            restaurant:
                            restaurant,
                          );
                        },
                      ),

                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(
                          Icons.delete,
                        ),
                        onPressed: () {
                          _deleteRestaurant(
                            restaurant,
                          );
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