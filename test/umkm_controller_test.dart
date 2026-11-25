import 'dart:async';

import 'package:aisyiyah_smartlife/umkm/controllers/umkm_controller.dart';
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
class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final T _result;
  final bool _shouldThrow;

  FakePostgrestFilterBuilder(this._result, {bool shouldThrow = false})
      : _shouldThrow = shouldThrow;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    if (_shouldThrow) {
      return Future<T>.error(Exception('Network error'))
          .then(onValue, onError: onError);
    }
    return Future.value(_result).then(onValue, onError: onError);
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final PostgrestList _result;
  final bool _shouldThrow;

  FakeSupabaseQueryBuilder(this._result, {bool shouldThrow = false})
      : _shouldThrow = shouldThrow;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return FakePostgrestFilterBuilder<PostgrestList>(
      _result,
      shouldThrow: _shouldThrow,
    );
  }
}

void main() {
  late MockSupabaseClient mockSupabase;
  late UmkmController controller;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    mockSupabase = MockSupabaseClient();
    controller = UmkmController(supabaseClient: mockSupabase);
  });

  tearDown(() {
    Get.reset();
  });

  group('UmkmController - White-Box Unit Tests', () {
    test(
      'TC-01 (Positive): fetchUmkm menormalisasi jalur Ranting dan mengisi dropdown filter',
      () async {
        final fakeRows = [
          {
            'id': '1',
            'nama': 'Batik Aisyiyah',
            'deskripsi': 'Kerajinan batik',
            'relasi_ranting': {
              'ranting': 'Ranting Pandeyan',
              'cabang': {
                'cabang': 'Cabang Umbulharjo',
                'daerah': {
                  'daerah': 'Kota Yogyakarta',
                  'wilayah': {'provinsi': 'DIY'},
                },
              },
            },
            'relasi_cabang': null,
          },
        ];

        when(() => mockSupabase.from('umkm'))
            .thenAnswer((_) => FakeSupabaseQueryBuilder(fakeRows));

        await controller.fetchUmkm();

        expect(controller.loading.value, isFalse);
        expect(controller.umkmList.length, 1);
        expect(controller.umkmList.first['filter_ranting'], 'Ranting Pandeyan');
        expect(controller.umkmList.first['filter_cabang'], 'Cabang Umbulharjo');
        expect(controller.umkmList.first['filter_daerah'], 'Kota Yogyakarta');
        expect(controller.umkmList.first['filter_wilayah'], 'DIY');
        expect(controller.availableRanting, contains('Ranting Pandeyan'));
        expect(controller.searchResults.length, 1);
      },
    );

    test(
      'TC-02 (Branch): fetchUmkm menormalisasi jalur Cabang saat relasi_ranting null',
      () async {
        final fakeRows = [
          {
            'id': '2',
            'nama': 'Katering Sehat',
            'relasi_ranting': null,
            'relasi_cabang': {
              'nama': 'Cabang Kotagede',
              'daerah': {
                'nama': 'Kota Yogyakarta',
                'wilayah': {'nama': 'DIY'},
              },
            },
          },
        ];

        when(() => mockSupabase.from('umkm'))
            .thenAnswer((_) => FakeSupabaseQueryBuilder(fakeRows));

        await controller.fetchUmkm();

        expect(controller.loading.value, isFalse);
        expect(controller.umkmList.first['filter_ranting'], isNull);
        expect(controller.umkmList.first['filter_cabang'], 'Cabang Kotagede');
        expect(controller.umkmList.first['filter_daerah'], 'Kota Yogyakarta');
        expect(controller.umkmList.first['filter_wilayah'], 'DIY');
      },
    );

    test(
      'TC-03 (Negative): fetchUmkm menangani exception dan mematikan loading',
      () async {
        when(() => mockSupabase.from('umkm'))
            .thenAnswer((_) => FakeSupabaseQueryBuilder([], shouldThrow: true));

        await controller.fetchUmkm();

        expect(controller.loading.value, isFalse);
        expect(controller.umkmList, isEmpty);
      },
    );

    test(
      'TC-04 (Positive): updateFiltersAndSearch memfilter data berdasarkan query dan tingkatan',
      () {
        controller.umkmList.value = [
          {
            'nama': 'Warung Berkah',
            'deskripsi_singkat': 'Makanan halal',
            'filter_ranting': 'Pandeyan',
            'filter_cabang': 'Umbulharjo',
            'filter_daerah': 'Kota Yogyakarta',
            'filter_wilayah': 'DIY',
          },
          {
            'nama': 'Toko Busana Muslim',
            'deskripsi_singkat': 'Gamis dan hijab',
            'filter_ranting': 'Purbayan',
            'filter_cabang': 'Kotagede',
            'filter_daerah': 'Kota Yogyakarta',
            'filter_wilayah': 'DIY',
          },
        ];

        controller.updateFiltersAndSearch(
          query: 'warung',
          ranting: 'Pandeyan',
          cabang: 'Umbulharjo',
          daerah: 'Kota Yogyakarta',
          wilayah: 'DIY',
        );

        expect(controller.searchResults.length, 1);
        expect(controller.searchResults.first['nama'], 'Warung Berkah');
        expect(controller.hasActiveFilter, isTrue);
      },
    );

    test(
      'TC-05 (Logic): showEditButton dan hasActiveFilter mengevaluasi role & state dengan benar',
      () {
        controller.userRole.value = 'anggota';
        expect(controller.showEditButton, isFalse);
        expect(controller.hasActiveFilter, isFalse);

        controller.userRole.value = 'admin_ranting';
        expect(controller.showEditButton, isTrue);

        controller.userRole.value = 'admin_cabang';
        expect(controller.showEditButton, isTrue);
      },
    );
  });
}
