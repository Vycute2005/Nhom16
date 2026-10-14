import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/restaurant.dart';

class RestaurantMapScreen extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantMapScreen({
    super.key,
    required this.restaurant,
  });

  @override
  Widget build(BuildContext context) {
    final location = LatLng(
      restaurant.latitude,
      restaurant.longitude,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Location'),
      ),
      body: kIsWeb
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      restaurant.address.isEmpty
                          ? '${restaurant.latitude}, ${restaurant.longitude}'
                          : restaurant.address,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open in Google Maps'),
                      onPressed: () async {
                        final query = restaurant.address.isEmpty
                            ? '${restaurant.name} '
                                  '${restaurant.latitude},${restaurant.longitude}'
                            : '${restaurant.name}, ${restaurant.address}';
                        final uri = Uri.https(
                          'www.google.com',
                          '/maps/search/',
                          {'api': '1', 'query': query},
                        );
                        final opened = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open Google Maps.'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            )
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: location,
                zoom: 16,
              ),
              markers: {
                Marker(
                  markerId: MarkerId(restaurant.id),
                  position: location,
                  infoWindow: InfoWindow(
                    title: restaurant.name,
                    snippet: restaurant.address,
                  ),
                ),
              },
              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
            ),
    );
  }
}