import '../models/food.dart';
import '../models/phrase.dart';
import '../models/restaurant.dart';
import '../models/tourist_place.dart';

final foods = [
  Food(
    id: 'pho',
    name: 'Pho',
    description: 'A famous Vietnamese noodle soup with beef or chicken.',
    imageUrl: 'assets/images/pho.jpg',
  ),
  Food(
    id: 'banh-mi',
    name: 'Banh Mi',
    description: 'A Vietnamese sandwich with meat, vegetables and herbs.',
    imageUrl: 'assets/images/banh_mi.jpg',
  ),
  Food(
    id: 'com-tam',
    name: 'Com Tam',
    description:
        'Broken rice served with grilled pork and Vietnamese side dishes.',
    imageUrl: 'assets/images/com_tam.jpg',
  ),
  Food(
    id: 'goi-cuon',
    name: 'Goi Cuon',
    description: 'Fresh Vietnamese spring rolls with vegetables and shrimp.',
    imageUrl: 'assets/images/goi_cuon.jpg',
  ),
];

final phrases = [
  Phrase(
    id: 'hello',
    vietnamese: 'Xin chào',
    pronunciation: 'sin chow',
    english: 'Hello',
    explanation: 'A friendly greeting used when meeting someone.',
  ),
  Phrase(
    id: 'thank-you',
    vietnamese: 'Cảm ơn',
    pronunciation: 'kahm uhn',
    english: 'Thank you',
    explanation: 'A polite way to show gratitude.',
  ),
  Phrase(
    id: 'please',
    vietnamese: 'Làm ơn',
    pronunciation: 'lahm uhn',
    english: 'Please',
    explanation: 'A polite expression used when making a request.',
  ),
  Phrase(
    id: 'how-much',
    vietnamese: 'Cái này bao nhiêu tiền?',
    pronunciation: 'guy nay bow nyew tee-en',
    english: 'How much is this?',
    explanation: 'Use this question when asking the price of something.',
  ),
  Phrase(
    id: 'goodbye',
    vietnamese: 'Tạm biệt',
    pronunciation: 'tahm bee-et',
    english: 'Goodbye',
    explanation: 'A common way to say goodbye.',
  ),
];

final touristPlaces = [
  TouristPlace(
    id: 'independence-palace',
    name: 'Independence Palace',
    imageUrl: 'assets/images/Independence Palace.jpg',
    history:
        'A historic landmark associated with the reunification of Vietnam.',
    culture: 'A preserved example of 20th-century Vietnamese architecture.',
    address: 'Ben Thanh Ward, District 1, Ho Chi Minh City',
    latitude: 10.7770,
    longitude: 106.6953,
  ),
  TouristPlace(
    id: 'war-remnants-museum',
    name: 'War Remnants Museum',
    imageUrl: 'assets/images/war-remnants-museum_standard.jpg',
    history: 'A museum documenting the effects of war in Vietnam.',
    culture: 'Exhibits include historical photographs and military artifacts.',
    address: 'Vo Van Tan Street, District 3, Ho Chi Minh City',
    latitude: 10.7798,
    longitude: 106.6920,
  ),
  TouristPlace(
    id: 'ben-thanh-market',
    name: 'Ben Thanh Market',
    imageUrl: 'assets/images/Ben_Thanh.jpg',
    history: 'A long-running central market and city landmark.',
    culture: 'Visitors can browse local food, produce, clothing, and crafts.',
    address: 'Le Loi Street, Ben Thanh Ward, Ho Chi Minh City',
    latitude: 10.7725,
    longitude: 106.6980,
  ),
];

final restaurants = [
  Restaurant(
    id: 'pho-restaurant-1',
    name: 'Pho Saigon Restaurant',
    address: 'District 1, Ho Chi Minh City',
    foodId: 'pho',
    latitude: 10.7765,
    longitude: 106.7009,
    imageUrl: 'assets/images/pho_shop.jpg',
    rating: 4.5,
  ),
  Restaurant(
    id: 'pho-restaurant-2',
    name: 'Traditional Pho House',
    address: 'District 3, Ho Chi Minh City',
    foodId: 'pho',
    latitude: 10.7831,
    longitude: 106.6847,
    imageUrl: 'assets/images/pho_shop.jpg',
    rating: 4.3,
  ),
  Restaurant(
    id: 'banh-mi-restaurant-1',
    name: 'Banh Mi  Huynh Hoa',
    address: 'District 1, Ho Chi Minh City',
    foodId: 'banh-mi',
    latitude: 10.7688,
    longitude: 106.6915,
    imageUrl: 'assets/images/banh_mi_shop.jpg',
    rating: 4.6,
  ),
  Restaurant(
    id: 'com-tam-restaurant-1',
    name: 'Com Tam Cali',
    address: 'District 1, Ho Chi Minh City',
    foodId: 'com-tam',
    latitude: 10.7758,
    longitude: 106.7004,
    imageUrl: 'assets/images/com_tam_shop.jpg',
    rating: 4.2,
  ),
  Restaurant(
    id: 'goi-cuon-restaurant-1',
    name: 'Fresh Spring Roll Restaurant',
    address: 'District 3, Ho Chi Minh City',
    foodId: 'goi-cuon',
    latitude: 10.7825,
    longitude: 106.6872,
    imageUrl: 'assets/images/goi_cuon_shop.jpg',
    rating: 4.4,
  ),
];
