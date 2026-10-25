import 'package:flutter/foundation.dart';

import '../models/food.dart';
import '../models/lichtrinh.dart';
import '../models/restaurant.dart';
import '../models/tourist_place.dart';
import 'auth_api_service.dart';

enum FavoriteKind { place, food, restaurant, itinerary }

extension FavoriteKindLabel on FavoriteKind {
  String get label => switch (this) {
        FavoriteKind.place => 'Danh lam',
        FavoriteKind.food => 'Món ăn',
        FavoriteKind.restaurant => 'Quán ăn',
        FavoriteKind.itinerary => 'Lịch trình',
      };
}

class FavoriteEntry {
  final String id;
  final FavoriteKind kind;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Object data;

  const FavoriteEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.data,
  });

  String get key => '${kind.name}:$id';

  Map<String, dynamic> toApiJson() => {
        'kind': kind.name,
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        if (data is ItineraryPlan) 'metadata': (data as ItineraryPlan).toJson(),
      };

  factory FavoriteEntry.fromApiJson(
    Map<String, dynamic> json, {
    Object? retainedData,
  }) {
    final kindName = (json['kind'] ?? json['item_type'] ?? '').toString();
    final kind = FavoriteKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => FavoriteKind.place,
    );
    final id = (json['id'] ?? json['item_id'] ?? '').toString();
    final title = (json['title'] ?? '').toString();
    final subtitle = (json['subtitle'] ?? '').toString();
    final imageUrl = (json['imageUrl'] ?? json['image_url'] ?? '').toString();
    final metadata = json['metadata'];
    final savedPlan = kind == FavoriteKind.itinerary &&
            metadata is Map && metadata['type'] == 'itinerary_plan'
        ? ItineraryPlan.fromJson(Map<String, dynamic>.from(metadata))
        : null;
    return FavoriteEntry(
      id: id,
      kind: kind,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      data: retainedData ??
          savedPlan ??
          (kind == FavoriteKind.place
              ? TouristPlace(
                  id: id,
                  name: title,
                  imageUrl: imageUrl,
                  history: '',
                  culture: '',
                  address: subtitle,
                  latitude: null,
                  longitude: null,
                )
              : json),
    );
  }

  factory FavoriteEntry.forFood(Food food) => FavoriteEntry(
        id: food.id.toString(),
        kind: FavoriteKind.food,
        title: food.name,
        subtitle: '${food.province} · ${food.priceRange}',
        imageUrl: food.imageUrl,
        data: food,
      );

  factory FavoriteEntry.forPlace(TouristPlace place) => FavoriteEntry(
        id: place.id,
        kind: FavoriteKind.place,
        title: place.name,
        subtitle: place.address.isEmpty ? place.province : place.address,
        imageUrl: place.imageUrl,
        data: place,
      );

  factory FavoriteEntry.forRestaurant(Restaurant restaurant) => FavoriteEntry(
        id: restaurant.id,
        kind: FavoriteKind.restaurant,
        title: restaurant.name,
        subtitle: restaurant.address,
        imageUrl: restaurant.imageUrl,
        data: restaurant,
      );

  factory FavoriteEntry.forFoodSpot(FoodSpot spot) => FavoriteEntry(
        id: 'food-spot:' + spot.id.toString(),
        kind: FavoriteKind.restaurant,
        title: spot.spotName,
        subtitle: spot.address,
        imageUrl: '',
        data: spot,
      );

  factory FavoriteEntry.forTemplate(ItineraryTemplate template) =>
      FavoriteEntry(
        id: 'template:${template.name}:${template.destination}',
        kind: FavoriteKind.itinerary,
        title: template.name,
        subtitle: '${template.destination} · ${template.durationDays} ngày',
        imageUrl: '',
        data: template,
      );

  factory FavoriteEntry.forPlan(ItineraryPlan plan) {
    return FavoriteEntry(
      id: 'plan:${plan.id}',
      kind: FavoriteKind.itinerary,
      title: plan.name,
      subtitle: '${plan.destination} · ${plan.totalDays} ngày',
      imageUrl: '',
      data: plan,
    );
  }
}

class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();

  static final FavoritesStore instance = FavoritesStore._();
  final Map<String, FavoriteEntry> _entries = <String, FavoriteEntry>{};
  bool _isSyncing = false;
  String? _syncError;

  List<FavoriteEntry> get entries => List.unmodifiable(_entries.values);
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;

  bool contains(String key) => _entries.containsKey(key);

  Future<void> add(FavoriteEntry entry) async {
    final token = userSession.token;
    if (!userSession.isSignedIn || token == null || token.isEmpty) {
      throw const AuthApiException('Vui lòng đăng nhập để lưu mục yêu thích.');
    }

    final api = AuthApiService();
    try {
      await api.saveFavorite(token: token, favorite: entry.toApiJson());
    } finally {
      api.close();
    }
    _entries[entry.key] = entry;
    notifyListeners();
  }

  Future<void> remove(String key) async {
    final entry = _entries[key];
    if (entry == null) return;

    final token = userSession.token;
    if (!userSession.isSignedIn || token == null || token.isEmpty) {
      throw const AuthApiException('Vui lòng đăng nhập để xóa mục yêu thích.');
    }

    final api = AuthApiService();
    try {
      await api.deleteFavorite(
        token: token,
        kind: entry.kind.name,
        id: entry.id,
      );
    } finally {
      api.close();
    }
    if (_entries.remove(key) != null) notifyListeners();
  }

  Future<void> syncFromServer(String token) async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    final api = AuthApiService();
    try {
      final remoteEntries = await api.getFavorites(token: token);
      if (userSession.token != token || !userSession.isSignedIn) return;
      final previous = Map<String, FavoriteEntry>.from(_entries);
      _entries
        ..clear()
        ..addEntries(remoteEntries.map((json) {
          final entry = FavoriteEntry.fromApiJson(json);
          final local = previous[entry.key];
          return MapEntry(
            entry.key,
            FavoriteEntry.fromApiJson(json, retainedData: local?.data),
          );
        }));
      notifyListeners();
    } catch (error) {
      _syncError = error.toString();
      rethrow;
    } finally {
      api.close();
      _isSyncing = false;
      notifyListeners();
    }
  }

  void clearLocal() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }
}

class UserSession extends ChangeNotifier {
  UserSession._();

  static final UserSession instance = UserSession._();
  String? _email;
  String? _username;
  String? _fullName;
  String? _nationality;
  String? _avatarUrl;
  String? _token;

  bool get isSignedIn => _email != null;
  String? get email => _email;
  String? get username => _username;
  String? get fullName => _fullName;
  String? get nationality => _nationality;
  String? get avatarUrl => _avatarUrl;
  String? get token => _token;

  void signIn(
    String email, {
    String? token,
    String? username,
    String? fullName,
    String? nationality,
    String? avatarUrl,
  }) {
    _email = email;
    _token = token;
    _username = username;
    _fullName = fullName;
    _nationality = nationality;
    _avatarUrl = avatarUrl;
    notifyListeners();
  }

  void updateProfile({
    required String email,
    required String username,
    required String fullName,
    required String nationality,
    required String avatarUrl,
  }) {
    _email = email;
    _username = username;
    _fullName = fullName;
    _nationality = nationality;
    _avatarUrl = avatarUrl;
    notifyListeners();
  }

  void signOut() {
    _email = null;
    _username = null;
    _fullName = null;
    _nationality = null;
    _avatarUrl = null;
    _token = null;
    favoritesStore.clearLocal();
    notifyListeners();
  }
}

final favoritesStore = FavoritesStore.instance;
final userSession = UserSession.instance;
