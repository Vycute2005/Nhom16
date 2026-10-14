import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tourist_place.dart';
import '../services/tourist_place_service.dart';
import '../widgets/app_image.dart';
import 'place_detail_screen.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final TouristPlaceService _service = TouristPlaceService();

  late Future<List<TouristPlace>> _placesFuture;

  @override
  void initState() {
    super.initState();
    _placesFuture = _service.getTouristPlaces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourist Places'),
        actions: [
          IconButton(
            tooltip: 'Photo credits',
            icon: const Icon(Icons.copyright_outlined),
            onPressed: _showPhotoCredits,
          ),
        ],
      ),
      body: FutureBuilder<List<TouristPlace>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load tourist places:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final places = snapshot.data ?? [];

          if (places.isEmpty) {
            return const Center(
              child: Text('No tourist places found.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: AppImage(
                    source: place.imageUrl,
                    width: 90,
                    height: 80,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.location_city_outlined,
                    fallbackIconSize: 32,
                  ),
                  title: Text(place.name),
                  subtitle: Text(
                    place.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaceDetailScreen(place: place),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPhotoCredits() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Photo credits'),
        content: SizedBox(
          width: 560,
          height: 460,
          child: FutureBuilder<String>(
            future: rootBundle.loadString(
              'assets/images/places/ATTRIBUTIONS.md',
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SelectableText(
                  'Failed to load photo credits: ${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return SingleChildScrollView(
                child: SelectableText(snapshot.data!),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
