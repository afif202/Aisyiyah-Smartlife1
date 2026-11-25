import 'dart:async';

import 'package:aisyiyah_smartlife/jadwalKegiatan/controllers/DetailKegiatan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// TEST DOUBLE 1: MOCK (mocktail untuk SupabaseClient)
// ============================================================================
class MockSupabaseClient extends Mock implements SupabaseClient {}

// ============================================================================
// TEST DOUBLE 2: FAKE (in-memory Postgrest query builder untuk tabel kegiatan)
// ============================================================================
class FakePostgrestTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  final T? _result;
  final bool _shouldThrow;

  FakePostgrestTransformBuilder(this._result, {bool shouldThrow = false})
      : _shouldThrow = shouldThrow;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    if (_shouldThrow) {
      return Future<T>.error(Exception('Kegiatan not found'))
          .then(onValue, onError: onError);
    }
    return Future.value(_result as T).then(onValue, onError: onError);
  }
}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final PostgrestMap? _result;
  final bool _shouldThrow;

  FakePostgrestFilterBuilder(this._result, {bool shouldThrow = false})
      : _shouldThrow = shouldThrow;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestMap> single() {
    return FakePostgrestTransformBuilder<PostgrestMap>(
      _result,
      shouldThrow: _shouldThrow,
    );
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final PostgrestMap? _result;
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
  late DetailKegiatanController controller;

  final fakeKegiatanRow = <String, dynamic>{
    'id': 'keg-1',
    'nama': 'Pengajian Akbar',
    'tipe': 'cabang',
    'tanggal': '2026-12-01T09:00:00Z',
    'deskripsi': 'Kajian rutin bulanan',
    'lokasi': 'Masjid Al-Falah',
    'frekuensi_ulang': 'monthly',
    'wilayah': {'nama': 'DIY'},
    'daerah': {'nama': 'Kota Yogyakarta'},
    'cabang': {'nama': 'Umbulharjo'},
    'ranting': null,
  };

  Widget createTestApp() {
    return const GetMaterialApp(
      home: Scaffold(body: Text('Detail Kegiatan Page')),
    );
  }

  setUp(() {
    Get.reset();
    Get.testMode = true;
    mockSupabase = MockSupabaseClient();
    controller = DetailKegiatanController(supabaseClient: mockSupabase);
  });

  tearDown(() {
    Get.reset();
  });

  group('DetailKegiatanController - White-Box Unit Tests', () {
    test(
      'TC-01 (Positive): fetchDetailKegiatan mem-parsing KegiatanModel dan mematikan isLoading',
      () async {
        when(() => mockSupabase.from('kegiatan'))
            .thenAnswer((_) => FakeSupabaseQueryBuilder(fakeKegiatanRow));

        await controller.fetchDetailKegiatan('keg-1');

        expect(controller.isLoading.value, isFalse);
        expect(controller.getOne_kegiatan.value, isNotNull);
        expect(controller.getOne_kegiatan.value!.nama, 'Pengajian Akbar');
        expect(controller.getOne_kegiatan.value!.cabangNama, 'Umbulharjo');
        expect(controller.getOne_kegiatan.value!.frekuensiUlang, 'monthly');
      },
    );

    testWidgets(
      'TC-02 (Negative): fetchDetailKegiatan gagal menampilkan snackbar Error',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        when(() => mockSupabase.from('kegiatan')).thenAnswer(
          (_) => FakeSupabaseQueryBuilder(null, shouldThrow: true),
        );

        await controller.fetchDetailKegiatan('invalid-id');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(controller.isLoading.value, isFalse);
        expect(controller.getOne_kegiatan.value, isNull);
        expect(find.text('Gagal memuat detail kegiatan'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'TC-03 (Positive): onInit mengambil Get.arguments dan memuat detail otomatis',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: '/list',
            getPages: [
              GetPage(
                name: '/list',
                page: () => const Scaffold(body: Text('List')),
              ),
              GetPage(
                name: '/detail',
                page: () => const Scaffold(body: Text('Detail')),
              ),
            ],
          ),
        );

        when(() => mockSupabase.from('kegiatan'))
            .thenAnswer((_) => FakeSupabaseQueryBuilder(fakeKegiatanRow));

        Get.toNamed('/detail', arguments: 'keg-1');
        await tester.pumpAndSettle();

        controller.onInit();
        await tester.pumpAndSettle();

        expect(controller.getOne_kegiatan.value?.id, 'keg-1');
        expect(controller.isLoading.value, isFalse);
      },
    );
  });
}
