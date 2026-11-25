import 'dart:async';

import 'package:aisyiyah_smartlife/umkm/controllers/detailUmkm_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// TEST DOUBLE 1: MOCK (mocktail untuk SupabaseClient)
// ============================================================================
class MockSupabaseClient extends Mock implements SupabaseClient {}

// ============================================================================
// TEST DOUBLE 2: FAKE (in-memory Postgrest query builder untuk tabel umkm)
// ============================================================================
class FakePostgrestTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  final T _result;

  FakePostgrestTransformBuilder(this._result);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future.value(_result).then(onValue, onError: onError);
  }
}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final List<Map<String, dynamic>> _rows;
  String? _filterId;

  FakePostgrestFilterBuilder(this._rows);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    if (column == 'id') {
      _filterId = value.toString();
    }
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    PostgrestMap? match;
    for (final row in _rows) {
      if (row['id']?.toString() == _filterId) {
        match = row;
        break;
      }
    }
    return FakePostgrestTransformBuilder<PostgrestMap?>(match);
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final List<Map<String, dynamic>> _rows;

  FakeSupabaseQueryBuilder(this._rows);

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return FakePostgrestFilterBuilder<PostgrestList>(_rows);
  }
}

void main() {
  late MockSupabaseClient mockSupabase;
  late DetailUmkmController controller;

  final fakeDbRows = <Map<String, dynamic>>[
    {
      'id': 'umkm-101',
      'nama': 'Keripik Tempe Aisyiyah',
      'deskripsi': 'Oleh-oleh khas daerah',
      'maps_link': 'https://maps.google.com/?q=-7.8,110.3',
    },
  ];

  setUp(() {
    Get.reset();
    Get.testMode = true;
    mockSupabase = MockSupabaseClient();
    controller = DetailUmkmController(supabaseClient: mockSupabase);
  });

  tearDown(() {
    Get.reset();
  });

  group('DetailUmkmController - White-Box Unit Tests', () {
    test(
      'TC-01 (Positive): loadDetail mengambil data UMKM sesuai ID dan mematikan loading',
      () async {
        controller.id = 'umkm-101';
        when(() => mockSupabase.from('umkm'))
            .thenAnswer((_) => FakeSupabaseQueryBuilder(fakeDbRows));

        await controller.loadDetail();

        expect(controller.loading.value, isFalse);
        expect(controller.data.value, isNotNull);
        expect(controller.data.value!['nama'], 'Keripik Tempe Aisyiyah');
        expect(
          controller.data.value!['maps_link'],
          'https://maps.google.com/?q=-7.8,110.3',
        );
      },
    );

    test(
      'TC-02 (Negative): loadDetail mengembalikan null jika ID tidak ditemukan',
      () async {
        controller.id = 'tidak-ada';
        when(() => mockSupabase.from('umkm'))
            .thenAnswer((_) => FakeSupabaseQueryBuilder(fakeDbRows));

        await controller.loadDetail();

        expect(controller.loading.value, isFalse);
        expect(controller.data.value, isNull);
      },
    );

    test(
      'TC-03 (Positive): onInit mengambil parameter id dan memuat detail secara otomatis',
      () async {
        Get.parameters = {'id': 'umkm-101'};
        when(() => mockSupabase.from('umkm'))
            .thenAnswer((_) => FakeSupabaseQueryBuilder(fakeDbRows));

        controller.onInit();
        await Future<void>.delayed(Duration.zero);

        expect(controller.id, 'umkm-101');
        expect(controller.data.value?['id'], 'umkm-101');
        expect(controller.loading.value, isFalse);
      },
    );
  });
}
