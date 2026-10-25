class ItineraryStop {
  final String id;
  final String placeName;
  final String time;
  final String type;
  final int estimatedCost;

  const ItineraryStop({
    required this.id,
    required this.placeName,
    required this.time,
    required this.type,
    required this.estimatedCost,
  });
}

class ItineraryDay {
  final DateTime date;
  final List<ItineraryStop> stops;

  ItineraryDay({
    required this.date,
    List<ItineraryStop>? stops,
  }) : stops = stops ?? <ItineraryStop>[];
}

class ItineraryPlan {
  final String id;
  final String name;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final List<ItineraryDay> days;

  ItineraryPlan({
    String? id,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.days,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'type': 'itinerary_plan',
        'id': id,
        'name': name,
        'destination': destination,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'days': days
            .map((day) => {
                  'date': day.date.toIso8601String(),
                  'stops': day.stops
                      .map((stop) => {
                            'id': stop.id,
                            'placeName': stop.placeName,
                            'time': stop.time,
                            'type': stop.type,
                            'estimatedCost': stop.estimatedCost,
                          })
                      .toList(),
                })
            .toList(),
      };

  factory ItineraryPlan.fromJson(Map<String, dynamic> json) {
    final startDate = DateTime.tryParse('${json['startDate'] ?? ''}') ??
        DateTime.now();
    final rawDays = json['days'];
    final days = rawDays is List
        ? rawDays.whereType<Map>().toList().asMap().entries.map((entry) {
            final day = Map<String, dynamic>.from(entry.value);
            final dayDate = DateTime.tryParse('${day['date'] ?? ''}') ??
                startDate.add(Duration(days: entry.key));
            final rawStops = day['stops'];
            final stops = rawStops is List
                ? rawStops.whereType<Map>().map((rawStop) {
                    final stop = Map<String, dynamic>.from(rawStop);
                    return ItineraryStop(
                      id: '${stop['id'] ?? ''}',
                      placeName: '${stop['placeName'] ?? ''}',
                      time: '${stop['time'] ?? '09:00'}',
                      type: '${stop['type'] ?? ''}',
                      estimatedCost: int.tryParse(
                            '${stop['estimatedCost'] ?? 0}',
                          ) ??
                          0,
                    );
                  }).toList()
                : <ItineraryStop>[];
            return ItineraryDay(date: dayDate, stops: stops);
          }).toList()
        : <ItineraryDay>[];
    final planId = json['id']?.toString();
    return ItineraryPlan(
      id: planId == null || planId.isEmpty ? null : planId,
      name: '${json['name'] ?? ''}',
      destination: '${json['destination'] ?? ''}',
      startDate: startDate,
      endDate: DateTime.tryParse('${json['endDate'] ?? ''}') ?? startDate,
      days: days,
    );
  }

  int get totalDays => days.length;

  int get totalEstimatedCost => days.fold<int>(
        0,
        (total, day) => total + day.stops.fold<int>(
          0,
          (dayTotal, stop) => dayTotal + stop.estimatedCost,
        ),
      );
}

class ItineraryTemplate {
  final String name;
  final String destination;
  final String description;
  final int durationDays;
  final Map<int, List<ItineraryStop>> stopsByDay;

  const ItineraryTemplate({
    required this.name,
    required this.destination,
    required this.description,
    required this.durationDays,
    required this.stopsByDay,
  });

  int get estimatedCost => stopsByDay.values.fold<int>(
        0,
        (total, stops) => total + stops.fold<int>(
          0,
          (subtotal, stop) => subtotal + stop.estimatedCost,
        ),
      );
}

const List<ItineraryTemplate> sampleItineraryTemplates = [
  ItineraryTemplate(
    name: 'Hà Nội 3 ngày 2 đêm',
    destination: 'Hà Nội',
    description: 'Khám phá phố cổ, hồ Hoàn Kiếm và văn hóa ẩm thực thủ đô.',
    durationDays: 3,
    stopsByDay: {
      0: [
        ItineraryStop(
          id: 'hanoi-1-1',
          placeName: 'Hồ Hoàn Kiếm',
          time: '08:00',
          type: 'Tham quan',
          estimatedCost: 0,
        ),
        ItineraryStop(
          id: 'hanoi-1-2',
          placeName: 'Phố cổ Hà Nội',
          time: '10:00',
          type: 'Tham quan',
          estimatedCost: 50000,
        ),
        ItineraryStop(
          id: 'hanoi-1-3',
          placeName: 'Thưởng thức bún chả',
          time: '12:00',
          type: 'Ẩm thực',
          estimatedCost: 70000,
        ),
      ],
      1: [
        ItineraryStop(
          id: 'hanoi-2-1',
          placeName: 'Văn Miếu - Quốc Tử Giám',
          time: '08:30',
          type: 'Tham quan',
          estimatedCost: 70000,
        ),
        ItineraryStop(
          id: 'hanoi-2-2',
          placeName: 'Lăng Chủ tịch Hồ Chí Minh',
          time: '10:30',
          type: 'Tham quan',
          estimatedCost: 0,
        ),
        ItineraryStop(
          id: 'hanoi-2-3',
          placeName: 'Phở Hà Nội',
          time: '18:00',
          type: 'Ẩm thực',
          estimatedCost: 60000,
        ),
      ],
      2: [
        ItineraryStop(
          id: 'hanoi-3-1',
          placeName: 'Hoàng thành Thăng Long',
          time: '09:00',
          type: 'Tham quan',
          estimatedCost: 100000,
        ),
        ItineraryStop(
          id: 'hanoi-3-2',
          placeName: 'Mua đặc sản tại phố cổ',
          time: '14:00',
          type: 'Mua sắm',
          estimatedCost: 150000,
        ),
      ],
    },
  ),
  ItineraryTemplate(
    name: 'Di sản miền Trung 4 ngày 3 đêm',
    destination: 'Huế - Đà Nẵng - Hội An',
    description: 'Hành trình khám phá cố đô, biển Đà Nẵng và phố cổ Hội An.',
    durationDays: 4,
    stopsByDay: {
      0: [
        ItineraryStop(
          id: 'central-1-1',
          placeName: 'Đại Nội Huế',
          time: '08:00',
          type: 'Tham quan',
          estimatedCost: 200000,
        ),
        ItineraryStop(
          id: 'central-1-2',
          placeName: 'Thưởng thức bún bò Huế',
          time: '12:00',
          type: 'Ẩm thực',
          estimatedCost: 60000,
        ),
      ],
      1: [
        ItineraryStop(
          id: 'central-2-1',
          placeName: 'Lăng Khải Định',
          time: '08:30',
          type: 'Tham quan',
          estimatedCost: 150000,
        ),
        ItineraryStop(
          id: 'central-2-2',
          placeName: 'Đèo Hải Vân',
          time: '14:00',
          type: 'Thiên nhiên',
          estimatedCost: 0,
        ),
      ],
      2: [
        ItineraryStop(
          id: 'central-3-1',
          placeName: 'Bãi biển Mỹ Khê',
          time: '08:00',
          type: 'Thiên nhiên',
          estimatedCost: 0,
        ),
        ItineraryStop(
          id: 'central-3-2',
          placeName: 'Ngũ Hành Sơn',
          time: '14:00',
          type: 'Tham quan',
          estimatedCost: 40000,
        ),
      ],
      3: [
        ItineraryStop(
          id: 'central-4-1',
          placeName: 'Phố cổ Hội An',
          time: '09:00',
          type: 'Tham quan',
          estimatedCost: 120000,
        ),
        ItineraryStop(
          id: 'central-4-2',
          placeName: 'Thưởng thức cao lầu',
          time: '12:00',
          type: 'Ẩm thực',
          estimatedCost: 55000,
        ),
      ],
    },
  ),
  ItineraryTemplate(
    name: 'Khám phá TP. Hồ Chí Minh 2 ngày 1 đêm',
    destination: 'TP. Hồ Chí Minh',
    description: 'Dạo quanh trung tâm thành phố, công trình lịch sử và món ngon địa phương.',
    durationDays: 2,
    stopsByDay: {
      0: [
        ItineraryStop(
          id: 'hcm-1-1',
          placeName: 'Dinh Độc Lập',
          time: '08:30',
          type: 'Tham quan',
          estimatedCost: 65000,
        ),
        ItineraryStop(
          id: 'hcm-1-2',
          placeName: 'Nhà thờ Đức Bà và Bưu điện Thành phố',
          time: '10:30',
          type: 'Tham quan',
          estimatedCost: 0,
        ),
        ItineraryStop(
          id: 'hcm-1-3',
          placeName: 'Thưởng thức cơm tấm',
          time: '12:00',
          type: 'Ẩm thực',
          estimatedCost: 60000,
        ),
      ],
      1: [
        ItineraryStop(
          id: 'hcm-2-1',
          placeName: 'Bảo tàng Chứng tích Chiến tranh',
          time: '09:00',
          type: 'Tham quan',
          estimatedCost: 40000,
        ),
        ItineraryStop(
          id: 'hcm-2-2',
          placeName: 'Chợ Bến Thành',
          time: '14:00',
          type: 'Mua sắm',
          estimatedCost: 100000,
        ),
      ],
    },
  ),
];
