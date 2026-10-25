import 'package:hcm_explorer/widgets/app_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatelessWidget {
  final String title;
  final double latitude;
  final double longitude;

  const MapScreen({
    super.key,
    this.title = 'Bản đồ tương tác',
    this.latitude = 10.7769,
    this.longitude = 106.7009,
  });

  Future<void> _openGoogleMaps(BuildContext context) async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': latitude.toString() + ',' + longitude.toString(),
      },
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text(title,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on,
                      size: 64, color: Color(0xFFB83B26)),
                  const SizedBox(height: 12),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(latitude.toString() + ', ' + longitude.toString(),
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _openGoogleMaps(context),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Mở Google Maps'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
