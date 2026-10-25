import 'package:hcm_explorer/widgets/app_ui.dart';
import '../models/food.dart';
import '../models/restaurant.dart';
import '../services/favorites_store.dart';
import '../widgets/favorite_button.dart';
import '../widgets/app_image.dart';
import 'restaurant_map_screen.dart';

class RestaurantDetailScreen extends StatelessWidget {
  final Restaurant restaurant;
  final Food food;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurant,
    required this.food,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant.name),
        actions: [
          FavoriteButton(entry: FavoriteEntry.forRestaurant(restaurant)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(
              source: restaurant.imageUrl,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              fallbackIcon: Icons.restaurant,
              fallbackIconSize: 70,
            ),
            if (restaurant.imageIsIllustrative)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Ảnh minh họa · có thể không phải chi nhánh này',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Đặc sản',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(food.name),
                  const SizedBox(height: 18),
                  const Text(
                    'Địa chỉ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(restaurant.address),
                  if (restaurant.openingHours.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Giờ mở cửa',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      restaurant.openingHoursIsEstimate
                          ? '${restaurant.openingHours} (${AppTranslations.translate('giờ ước tính; vui lòng xác nhận với chi nhánh')})'
                          : restaurant.openingHours,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('Xem trên bản đồ'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RestaurantMapScreen(
                              restaurant: restaurant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
