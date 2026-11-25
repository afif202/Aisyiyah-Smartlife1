import 'dart:async';

import 'package:aisyiyah_smartlife/donasi/controllers/FormDonasi_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// TEST DOUBLE 1: MOCK (mocktail untuk SupabaseClient & GoTrueClient)
// ============================================================================
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

// ============================================================================
// TEST DOUBLE 2: FAKE (in-memory query builder untuk insert/update donasi_rk)
// ============================================================================
class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final List<Map<String, dynamic>> _store;
  final bool _shouldThrow;
  final Map<String, dynamic>? _pendingUpdate;

  FakePostgrestFilterBuilder(
    this._store, {
    bool shouldThrow = false,
    Map<String, dynamic>? pendingUpdate,
  })  : _shouldThrow = shouldThrow,
        _pendingUpdate = pendingUpdate;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    if (_pendingUpdate != null) {
      for (final item in _store) {
        if (item[column] == value) {
          item.addAll(_pendingUpdate);
        }
      }
    }
    return this;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    if (_shouldThrow) {
      return Future<T>.error(Exception('DB write failed'))
          .then(onValue, onError: onError);
    }
    return Future.value(<Map<String, dynamic>>[] as T)
        .then(onValue, onError: onError);
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final List<Map<String, dynamic>> store;
  final bool shouldThrow;
  bool insertCalled = false;
  bool updateCalled = false;

  FakeSupabaseQueryBuilder(this.store, {this.shouldThrow = false});

  @override
  PostgrestFilterBuilder<dynamic> insert(
    Object values, {
    bool defaultToNull = true,
  }) {
    insertCalled = true;
    if (!shouldThrow && values is Map<String, dynamic>) {
      store.add(Map<String, dynamic>.from(values));
    }
    return FakePostgrestFilterBuilder<dynamic>(store, shouldThrow: shouldThrow);
  }

  @override
  PostgrestFilterBuilder<dynamic> update(
    Map<dynamic, dynamic> values, {
    bool defaultToNull = true,
  }) {
    updateCalled = true;
    return FakePostgrestFilterBuilder<dynamic>(
      store,
      shouldThrow: shouldThrow,
      pendingUpdate: Map<String, dynamic>.from(values),
    );
  }
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late FormDonasi_controller controller;

  const fakeUser = User(
    id: 'usr-donasi-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );

  Widget createTestApp() {
    return GetMaterialApp(
      initialRoute: '/list',
      getPages: [
        GetPage(
          name: '/list',
          page: () => const Scaffold(body: Text('List Donasi')),
        ),
        GetPage(
          name: '/form',
          page: () => const Scaffold(body: Text('Form Donasi')),
        ),
      ],
    );
  }

  setUp(() {
    Get.reset();
    Get.testMode = true;
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    controller = FormDonasi_controller(supabaseClient: mockSupabase);
  });

  tearDown(() {
    Get.reset();
  });

  group('FormDonasi_controller - White-Box Unit Tests', () {
    test('TC-01 (Positive): initFormData mengisi semua field dan editId saat mode edit', () {
      controller.initFormData({
        'id': 'don-99',
        'nama': 'Bantuan Banjir',
        'deskripsi': 'Untuk korban banjir',
        'nominal': 50000,
        'fix_amount': true,
        'gambar': 'https://example.com/img.png',
      });

      expect(controller.editId, 'don-99');
      expect(controller.namaController.text, 'Bantuan Banjir');
      expect(controller.deskripsiController.text, 'Untuk korban banjir');
      expect(controller.nominalController.text, '50000');
      expect(controller.fixAmount.value, isTrue);
      expect(controller.currentImageUrl.value, 'https://example.com/img.png');
    });

    test('TC-02 (Guard): saveDonasi langsung berhenti jika isLoading masih true', () async {
      controller.isLoading.value = true;
      controller.namaController.text = 'Donasi A';

      await controller.saveDonasi();

      verifyNever(() => mockAuth.currentUser);
    });

    testWidgets(
      'TC-03 (Negative): Nama donasi kosong menampilkan snackbar Peringatan',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        controller.namaController.text = '';

        await controller.saveDonasi();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Nama donasi wajib diisi'), findsOneWidget);
        expect(controller.isLoading.value, isFalse);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'TC-04 (Negative): User belum login menampilkan snackbar Sesi berakhir',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        controller.namaController.text = 'Donasi Pendidikan';
        when(() => mockAuth.currentUser).thenReturn(null);

        await controller.saveDonasi();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Sesi berakhir, silakan login kembali'), findsOneWidget);
        expect(controller.isLoading.value, isFalse);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'TC-05 (Positive): Mode insert menyimpan data baru ke Fake DB dan kembali',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        Get.toNamed('/form');
        await tester.pumpAndSettle();

        final fakeStore = <Map<String, dynamic>>[];
        final fakeQuery = FakeSupabaseQueryBuilder(fakeStore);

        controller.namaController.text = 'Infaq Jumat';
        controller.deskripsiController.text = 'Program rutin';
        controller.nominalController.text = '25000';
        controller.fixAmount.value = true;

        when(() => mockAuth.currentUser).thenReturn(fakeUser);
        when(() => mockSupabase.from('donasi_rk')).thenAnswer((_) => fakeQuery);

        await controller.saveDonasi();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(fakeQuery.insertCalled, isTrue);
        expect(fakeStore.length, 1);
        expect(fakeStore.first['nama'], 'Infaq Jumat');
        expect(fakeStore.first['nominal'], 25000.0);
        expect(controller.isLoading.value, isFalse);
        expect(find.text('List Donasi'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-06 (Positive): Mode edit memperbarui data existing di Fake DB',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        Get.toNamed('/form');
        await tester.pumpAndSettle();

        final fakeStore = <Map<String, dynamic>>[
          {'id': 'don-1', 'nama': 'Lama', 'nominal': 10000.0}
        ];
        final fakeQuery = FakeSupabaseQueryBuilder(fakeStore);

        controller.initFormData({
          'id': 'don-1',
          'nama': 'Program Baru',
          'deskripsi': 'Update',
          'nominal': 75000,
          'fix_amount': false,
        });

        when(() => mockAuth.currentUser).thenReturn(fakeUser);
        when(() => mockSupabase.from('donasi_rk')).thenAnswer((_) => fakeQuery);

        await controller.saveDonasi();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(fakeQuery.updateCalled, isTrue);
        expect(fakeStore.first['nama'], 'Program Baru');
        expect(controller.isLoading.value, isFalse);
      },
    );

    testWidgets(
      'TC-07 (Negative): Exception dari database menampilkan snackbar Error',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        final fakeQuery = FakeSupabaseQueryBuilder([], shouldThrow: true);

        controller.namaController.text = 'Donasi Error';
        when(() => mockAuth.currentUser).thenReturn(fakeUser);
        when(() => mockSupabase.from('donasi_rk')).thenAnswer((_) => fakeQuery);

        await controller.saveDonasi();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.textContaining('Gagal menyimpan data:'), findsOneWidget);
        expect(controller.isLoading.value, isFalse);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );
  });
}
