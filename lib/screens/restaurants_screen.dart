import 'package:hcm_explorer/widgets/app_ui.dart';
import '../models/food.dart';
import '../models/restaurant.dart';
import '../widgets/app_image.dart';
import 'restaurant_detail_screen.dart';

class RestaurantsScreen extends StatelessWidget {
  final Food food;
  final List<Restaurant> restaurants;

  const RestaurantsScreen({
    super.key,
    required this.food,
    required this.restaurants,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.isEnglish ? '${food.name} Restaurants' : 'Quán ăn · ${food.name}'),
      ),
      body: restaurants.isEmpty
          ? const Center(
              child: Text(
                'Chưa có quán ăn.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: restaurants.length,
              itemBuilder: (context, index) {
                final restaurant = restaurants[index];

                return RestaurantCard(
                  restaurant: restaurant,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailScreen(
                          restaurant: restaurant,
                          food: food,
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

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(
              source: restaurant.imageUrl,
              width: 120,
              height: 130,
              fit: BoxFit.cover,
              fallbackIcon: Icons.restaurant,
              fallbackIconSize: 45,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (restaurant.imageIsIllustrative) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Ảnh minh họa · có thể không phải chi nhánh này',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      restaurant.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (restaurant.openingHours.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.schedule, size: 17),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${AppTranslations.translate(restaurant.openingHoursIsEstimate ? 'Giờ dự kiến' : 'Giờ mở cửa')}: ${restaurant.openingHours}',
                              style: TextStyle(
                                color: restaurant.openingHoursIsEstimate
                                    ? Colors.grey.shade700
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Xem chi tiết',
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
