import 'dart:async';

import 'package:aisyiyah_smartlife/routes/app_routes.dart';
import 'package:aisyiyah_smartlife/signup/controllers/signup_controller.dart';
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
// TEST DOUBLE 2: FAKE (in-memory query builder untuk tabel wilayah/register)
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
  final dynamic _result;

  FakePostgrestFilterBuilder(this._result);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    return FakePostgrestTransformBuilder<T>(_result as T);
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    return FakePostgrestTransformBuilder<PostgrestMap?>(
      _result as PostgrestMap?,
    );
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final dynamic _result;

  FakeSupabaseQueryBuilder(this._result);

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return FakePostgrestFilterBuilder<PostgrestList>(_result);
  }
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late SignUp_controller controller;

  Widget createTestApp() {
    return GetMaterialApp(
      initialRoute: Routes.SIGNUP,
      getPages: [
        GetPage(
          name: Routes.SIGNUP,
          page: () => const Scaffold(body: Text('SignUp Page')),
        ),
        GetPage(
          name: Routes.LOGIN,
          page: () => const Scaffold(body: Text('Login Page')),
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
    controller = SignUp_controller(supabaseClient: mockSupabase);
  });

  tearDown(() {
    Get.reset();
  });

  void fillValidForm() {
    controller.firstNameController.text = 'Siti';
    controller.lastNameController.text = 'Aminah';
    controller.emailController.text = 'siti@aisyiyah.org';
    controller.phoneController.text = '08123456789';
    controller.passwordController.text = 'rahasia123';
    controller.confirmPasswordController.text = 'rahasia123';
    controller.selectedWilayahId.value = 'w1';
    controller.selectedDaerahId.value = 'd1';
    controller.selectedCabangId.value = 'c1';
    controller.selectedRantingId.value = 'r1';
  }

  group('SignUp_controller - White-Box Unit Tests', () {
    testWidgets(
      'TC-01 (Negative): Data wajib kosong menampilkan snackbar Data Belum Lengkap',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await controller.handleSignUp();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(controller.isLoading.value, isFalse);
        expect(find.text('Data Belum Lengkap'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'TC-02 (Negative): Konfirmasi password tidak cocok menampilkan snackbar Error',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        fillValidForm();
        controller.confirmPasswordController.text = 'berbeda123';

        await controller.handleSignUp();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(controller.isLoading.value, isFalse);
        expect(find.text('Konfirmasi password tidak cocok.'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'TC-03 (Negative): Email tidak ada di whitelist register melempar ERR:SignV104',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        fillValidForm();

        when(
          () => mockSupabase.from('register'),
        ).thenAnswer((_) => FakeSupabaseQueryBuilder(null));

        await controller.handleSignUp();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(controller.isLoading.value, isFalse);
        expect(find.text('Email Tertolak (ERR:SignV104)'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'TC-04 (Negative): AuthException saat signUp menampilkan snackbar Gagal Registrasi',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        fillValidForm();

        when(
          () => mockSupabase.from('register'),
        ).thenAnswer((_) => FakeSupabaseQueryBuilder({'email': 'siti@aisyiyah.org'}));
        when(
          () => mockAuth.signUp(
            email: 'siti@aisyiyah.org',
            password: 'rahasia123',
            data: any(named: 'data'),
          ),
        ).thenThrow(const AuthException('User already registered'));

        await controller.handleSignUp();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(controller.isLoading.value, isFalse);
        expect(find.text('User already registered'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'TC-05 (Positive): Registrasi valid menavigasi ke halaman Login',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        fillValidForm();

        when(
          () => mockSupabase.from('register'),
        ).thenAnswer((_) => FakeSupabaseQueryBuilder({'email': 'siti@aisyiyah.org'}));
        when(
          () => mockAuth.signUp(
            email: 'siti@aisyiyah.org',
            password: 'rahasia123',
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => AuthResponse());

        await controller.handleSignUp();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(controller.isLoading.value, isFalse);
        expect(find.text('Login Page'), findsOneWidget);
      },
    );

    test('TC-06 (Positive): Fetch cascading wilayah/daerah/cabang/ranting mengisi list', () async {
      when(() => mockSupabase.from('wilayah')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder([
          {'id': 'w1', 'provinsi': 'DI Yogyakarta'},
        ]),
      );
      when(() => mockSupabase.from('daerah')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder([
          {'id': 'd1', 'daerah': 'Kota Yogyakarta'},
        ]),
      );
      when(() => mockSupabase.from('cabang')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder([
          {'id': 'c1', 'cabang': 'Umbulharjo'},
        ]),
      );
      when(() => mockSupabase.from('ranting')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder([
          {'id': 'r1', 'ranting': 'Pandeyan'},
        ]),
      );

      await controller.fetchWilayah();
      await controller.fetchDaerah('w1');
      await controller.fetchCabang('d1');
      await controller.fetchRanting('c1');

      expect(controller.wilayahList.length, 1);
      expect(controller.daerahList.first['daerah'], 'Kota Yogyakarta');
      expect(controller.cabangList.first['cabang'], 'Umbulharjo');
      expect(controller.rantingList.first['ranting'], 'Pandeyan');
      expect(controller.isRegionLoading.value, isFalse);
    });
  });
}
