import 'dart:async';

import 'package:hcm_explorer/widgets/app_ui.dart';

import '../models/lichtrinh.dart';
import '../models/tourist_place.dart';
import '../screens/place_detail_screen.dart';
import '../services/favorites_store.dart';
import 'account_access_screen.dart';
import 'lichtrinh_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with AppLocaleAwareState<FavoritesScreen> {
  FavoriteKind _selectedKind = FavoriteKind.place;

  Future<void> _openAccount() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AccountAccessScreen()),
    );
  }

  void _openEntry(FavoriteEntry entry) {
    final data = entry.data;
    if (data is TouristPlace) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => PlaceDetailScreen(place: data)),
      );
    } else if (data is ItineraryPlan) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ItineraryDaysScreen(plan: data)),
      );
    } else if (data is ItineraryTemplate) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CreateItineraryScreen(
            initialName: data.name,
            initialDestination: data.destination,
            initialDurationDays: data.durationDays,
            initialStopsByDay: data.stopsByDay,
          ),
        ),
      );
    }
  }

  IconData _iconFor(FavoriteKind kind) => switch (kind) {
        FavoriteKind.place => Icons.location_city_outlined,
        FavoriteKind.food => Icons.restaurant_outlined,
        FavoriteKind.restaurant => Icons.storefront_outlined,
        FavoriteKind.itinerary => Icons.route_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'Đã lưu / Yêu thích',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: AnimatedBuilder(
        animation: userSession,
        builder: (context, _) {
          if (!userSession.isSignedIn) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 46, color: Color(0xFF0F5B49)),
                    const SizedBox(height: 12),
                    const Text(
                      'Đăng nhập để xem mục đã lưu',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Món ăn, danh lam và lịch trình yêu thích sẽ nằm ở đây.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _openAccount,
                      icon: const Icon(Icons.login),
                      label: const Text('Đăng nhập'),
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F5B49)),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              AnimatedBuilder(
                animation: favoritesStore,
                builder: (context, _) {
                  if (favoritesStore.isSyncing) {
                    return const LinearProgressIndicator(
                      minHeight: 2,
                      color: Color(0xFF0F5B49),
                    );
                  }
                  final error = favoritesStore.syncError;
                  if (error == null) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E1D5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(error),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: favoritesStore.isSyncing
                                ? null
                                : () {
                                    final token = userSession.token;
                                    if (token != null) {
                                      unawaited(
                                        favoritesStore
                                            .syncFromServer(token)
                                            .catchError((Object _) {}),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Đồng bộ lại'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: FavoriteKind.values.map((kind) {
                    final selected = kind == _selectedKind;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(kind.label),
                        selected: selected,
                        selectedColor: const Color(0xFF0F5B49),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() => _selectedKind = kind),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: favoritesStore,
                  builder: (context, _) {
                    final entries = favoritesStore.entries
                        .where((entry) => entry.kind == _selectedKind)
                        .toList();
                    if (entries.isEmpty) {
                      return Center(
                        child: Text(
                          'Chưa có ${_selectedKind.label.toLowerCase()} nào được lưu.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8E1D5)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: entry.data is TouristPlace ||
                                    entry.data is ItineraryPlan ||
                                    entry.data is ItineraryTemplate
                                ? () => _openEntry(entry)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: entry.imageUrl.isEmpty
                                        ? Container(
                                            width: 60,
                                            height: 60,
                                            color: const Color(0xFFECE8E1),
                                            child: Icon(_iconFor(entry.kind),
                                                color: const Color(0xFF0F5B49)),
                                          )
                                        : Image.network(
                                            entry.imageUrl,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 60,
                                              height: 60,
                                              color: const Color(0xFFECE8E1),
                                              child: Icon(_iconFor(entry.kind),
                                                  color:
                                                      const Color(0xFF0F5B49)),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          entry.subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: AppTranslations.translate('Bỏ yêu thích'),
                                    onPressed: () async {
                                      try {
                                        await favoritesStore.remove(entry.key);
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Không đồng bộ được yêu thích: $error',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.favorite_rounded,
                                        color: Color(0xFFB83B26)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
