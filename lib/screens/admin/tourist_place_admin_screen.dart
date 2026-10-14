import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/tourist_place.dart';
import '../../services/tourist_place_service.dart';
import '../../services/upload_service.dart';
import 'widgets/admin_delete_dialog.dart';
import 'widgets/admin_text_field.dart';

class TouristPlaceAdminScreen extends StatefulWidget {
  const TouristPlaceAdminScreen({super.key});

  @override
  State<TouristPlaceAdminScreen> createState() =>
      _TouristPlaceAdminScreenState();
}

class _TouristPlaceAdminScreenState
    extends State<TouristPlaceAdminScreen> {
  final TouristPlaceService _service =
  TouristPlaceService();

  final UploadService _uploadService =
  UploadService();

  late Future<List<TouristPlace>> _placesFuture;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  void _loadPlaces() {
    _placesFuture =
        _service.getTouristPlaces();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadPlaces();
    });
  }

  Future<void> _showPlaceForm({
    TouristPlace? place,
  }) async {
    final idController = TextEditingController(
      text: place?.id ?? '',
    );

    final nameController = TextEditingController(
      text: place?.name ?? '',
    );

    final historyController = TextEditingController(
      text: place?.history ?? '',
    );

    final cultureController = TextEditingController(
      text: place?.culture ?? '',
    );

    final addressController = TextEditingController(
      text: place?.address ?? '',
    );

    final latitudeController = TextEditingController(
      text: place?.latitude.toString() ?? '',
    );

    final longitudeController = TextEditingController(
      text: place?.longitude.toString() ?? '',
    );

    final isEditing = place != null;

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
                    ? 'Edit Tourist Place'
                    : 'Add Tourist Place',
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
                        controller: historyController,
                        labelText: 'History',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),

                      AdminTextField(
                        controller: cultureController,
                        labelText: 'Culture',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),

                      AdminTextField(
                        controller: addressController,
                        labelText: 'Address',
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
                          place.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius:
                          BorderRadius.circular(8),
                          child: _buildNetworkImage(
                            place.imageUrl,
                            width: 180,
                            height: 120,
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

                    final history =
                    historyController.text.trim();

                    final culture =
                    cultureController.text.trim();

                    final address =
                    addressController.text.trim();

                    final latitude =
                    double.tryParse(
                      latitudeController.text.trim(),
                    );

                    final longitude =
                    double.tryParse(
                      longitudeController.text.trim(),
                    );

                    if (id.isEmpty ||
                        name.isEmpty ||
                        latitude == null ||
                        longitude == null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ID, Name, Latitude and Longitude are required.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      String imagePath = isEditing
                          ? place.imageUrl
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
                          folder:
                          'tourist-places',
                        );
                      }

                      if (isEditing) {
                        await _service
                            .updateTouristPlace(
                          id: place.id,
                          name: name,
                          imageUrl: imagePath,
                          history: history,
                          culture: culture,
                          address: address,
                          latitude: latitude,
                          longitude: longitude,
                        );
                      } else {
                        await _service
                            .createTouristPlace(
                          id: id,
                          name: name,
                          imageUrl: imagePath,
                          history: history,
                          culture: culture,
                          address: address,
                          latitude: latitude,
                          longitude: longitude,
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
    historyController.dispose();
    cultureController.dispose();
    addressController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();

    if (result == true && mounted) {
      setState(() {
        _loadPlaces();
      });
    }
  }

  Widget _buildNetworkImage(
      String imageUrl, {
        required double width,
        required double height,
      }) {
    return Image.network(
      '${ApiConfig.baseUrl}/api/images/$imageUrl',
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
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
    );
  }

  Widget _buildPlaceImage(
      TouristPlace place,
      ) {
    if (place.imageUrl.isEmpty) {
      return const Icon(
        Icons.location_city,
        size: 40,
      );
    }

    if (place.imageUrl.startsWith('assets/')) {
      return Image.asset(
        place.imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) {
          return const Icon(
            Icons.location_city,
            size: 40,
          );
        },
      );
    }

    return Image.network(
      '${ApiConfig.baseUrl}/api/images/${place.imageUrl}',
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) {
        return const Icon(
          Icons.location_city,
          size: 40,
        );
      },
    );
  }

  Future<void> _deletePlace(
      TouristPlace place,
      ) async {
    final confirmed =
    await showAdminDeleteDialog(
      context,
      title: 'Delete Tourist Place',
      message:
      'Are you sure you want to delete "${place.name}"?',
    );

    if (!confirmed) {
      return;
    }

    try {
      await _service.deleteTouristPlace(
        place.id,
      );

      if (mounted) {
        setState(() {
          _loadPlaces();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tourist place deleted successfully.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Tourist Places',
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
          _showPlaceForm();
        },
        child: const Icon(Icons.add),
      ),

      body: FutureBuilder<List<TouristPlace>>(
        future: _placesFuture,
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
                'Failed to load tourist places:\n'
                    '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final places =
              snapshot.data ?? [];

          if (places.isEmpty) {
            return const Center(
              child: Text(
                'No tourist places found.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: ListTile(
                  leading:
                  _buildPlaceImage(place),

                  title: Text(
                    place.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  subtitle: Text(
                    place.address,
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis,
                  ),

                  trailing: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon:
                        const Icon(Icons.edit),
                        onPressed: () {
                          _showPlaceForm(
                            place: place,
                          );
                        },
                      ),

                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(
                          Icons.delete,
                        ),
                        onPressed: () {
                          _deletePlace(place);
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