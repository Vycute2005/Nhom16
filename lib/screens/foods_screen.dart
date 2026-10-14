import 'package:flutter/material.dart';

import '../models/food.dart';
import '../services/food_service.dart';
import '../services/restaurant_service.dart';
import '../widgets/app_image.dart';
import 'restaurants_screen.dart';

class FoodsScreen extends StatefulWidget {
  const FoodsScreen({super.key});

  @override
  State<FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends State<FoodsScreen> {
  final FoodService _foodService = FoodService();
  final RestaurantService _restaurantService = RestaurantService();

  late Future<List<Food>> _foodsFuture;

  @override
  void initState() {
    super.initState();

    _foodsFuture = _foodService.getFoods();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Food'),
      ),
      body: FutureBuilder<List<Food>>(
        future: _foodsFuture,
        builder: (context, snapshot) {
          // Đang tải dữ liệu
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Có lỗi
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load foods:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          // Không có dữ liệu
          final foodsFromApi = snapshot.data ?? [];

          if (foodsFromApi.isEmpty) {
            return const Center(
              child: Text('No food found.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: foodsFromApi.length,
            itemBuilder: (context, index) {
              final food = foodsFromApi[index];

              return FoodCard(
                food: food,
                onTap: () async {
                  try {
                    final restaurants = await _restaurantService.getRestaurants();

                    final foodRestaurants = restaurants
                        .where(
                          (restaurant) => restaurant.foodId == food.id,
                        )
                        .toList();

                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantsScreen(
                          food: food,
                          restaurants: foodRestaurants,
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to load restaurants: $e'),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class FoodCard extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;

  const FoodCard({
    super.key,
    required this.food,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(
              source: food.imageUrl,
              width: double.infinity,
              height: 190,
              fit: BoxFit.cover,
              fallbackIcon: Icons.restaurant,
              fallbackIconSize: 50,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                food.name,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                food.description,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                bottom: 14,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View restaurants',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.teal,
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