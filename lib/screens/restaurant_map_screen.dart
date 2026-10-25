import 'package:hcm_explorer/widgets/app_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/restaurant.dart';

class RestaurantMapScreen extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantMapScreen({super.key, required this.restaurant});

  Future<void> _openGoogleMaps(BuildContext context) async {
    final query = restaurant.name +
        ', ' +
        restaurant.latitude.toString() +
        ',' +
        restaurant.longitude.toString();
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {'api': '1', 'query': query},
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được Google Maps.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được Google Maps.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = restaurant.address.isEmpty
        ? restaurant.latitude.toString() + ', ' + restaurant.longitude.toString()
        : restaurant.address;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(restaurant.name),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on,
                  size: 60, color: Color(0xFFB83B26)),
              const SizedBox(height: 12),
              Text(address, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openGoogleMaps(context),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Mở Google Maps'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
