import 'dart:convert';
import 'dart:io';

import 'package:backend/utils/tourist_province.dart';
import 'package:test/test.dart';

void main() {
  test('assigns a province to every crawled place', () {
    final places = jsonDecode(
      File('assets/data/places.json').readAsStringSync(),
    ) as List<dynamic>;

    for (final place in places.cast<Map<String, dynamic>>()) {
      expect(
        resolveTouristProvince(
          name: place['name'] as String,
          address: place['address'] as String,
          province: place['province'] as String?,
        ),
        isNotNull,
        reason: 'Province was not resolved for ${place['name']}',
      );
    }
  });

  test('corrects known geocoder province mismatches', () {
    expect(
      resolveTouristProvince(
        name: 'Chùa Hương',
        address: 'Xã Yên Mỹ, Tỉnh Hưng Yên',
      ),
      'Hà Nội',
    );
    expect(
      resolveTouristProvince(
        name: 'Tam Đảo',
        address: 'Xã Đại Từ, Tỉnh Thái Nguyên',
      ),
      'Phú Thọ',
    );
    expect(
      resolveTouristProvince(
        name: 'Ghềnh Đá Đĩa',
        address: 'Phường Đông Ngạc, Thành phố Hà Nội',
      ),
      'Đắk Lắk',
    );
    expect(
      resolveTouristProvince(
        name: 'Công viên văn hóa Đầm Sen',
        address: 'Đường Hòa Bình, Quận 11, Thành phố Hồ Chí Minh',
      ),
      'TP. Hồ Chí Minh',
    );
    expect(
      resolveTouristProvince(
        name: 'Independence Palace',
        address: 'Ben Thanh Ward, District 1, Ho Chi Minh City',
      ),
      'TP. Hồ Chí Minh',
    );
  });

  test('does not guess a province from an unrecognized location', () {
    expect(
      resolveTouristProvince(name: 'Unknown place', address: 'Vietnam'),
      isNull,
    );
  });
}
