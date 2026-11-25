import 'dart:async';

import 'package:aisyiyah_smartlife/login/controllers/login_controller.dart';
import 'package:aisyiyah_smartlife/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// TEST DOUBLE 1: MOCK (menggunakan mocktail untuk SupabaseClient & GoTrueClient)
// ============================================================================
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

// ============================================================================
// TEST DOUBLE 2: FAKE (implementasi tiruan in-memory untuk query Postgrest DB)
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
  final Map<String, dynamic>? _profileResult;

  FakePostgrestFilterBuilder(this._profileResult);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    return FakePostgrestTransformBuilder<PostgrestMap?>(_profileResult);
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final Map<String, dynamic>? _profileResult;

  FakeSupabaseQueryBuilder(this._profileResult);

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return FakePostgrestFilterBuilder<PostgrestList>(_profileResult);
  }
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late LoginController controller;

  Widget createTestApp() {
    return GetMaterialApp(
      initialRoute: '/login',
      getPages: [
        GetPage(
          name: '/login',
          page: () => const Scaffold(body: Text('Login Page')),
        ),
        GetPage(
          name: Routes.HOME,
          page: () => const Scaffold(body: Text('Home Page')),
        ),
      ],
    );
  }

  setUp(() {
    Get.reset();
    Get.testMode = true;
    // TEST DOUBLE 2 (lanjutan): Fake SharedPreferences in-memory
    SharedPreferences.setMockInitialValues({});

    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();

    when(() => mockSupabase.auth).thenReturn(mockAuth);

    controller = LoginController(supabaseClient: mockSupabase);
  });

  tearDown(() {
    Get.closeAllSnackbars();
    Get.reset();
  });

  group('LoginController.handleLogin() - White-Box Unit Tests', () {
    testWidgets(
      'TC-01 (Negative): Input email atau password kosong menampilkan error dan berhenti (S1, S2, S3)',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestApp());
        controller.emailController.text = '';
        controller.passwordController.text = '';

        // Act
        await controller.handleLogin();
        await tester.pump();

        // Assert
        expect(controller.isLoading.value, isFalse);
        expect(find.text('Email dan password harus diisi'), findsOneWidget);
        verifyNever(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );

        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'TC-02 (Positive): Login berhasil, data profil tersimpan di SharedPreferences, navigasi ke HOME',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestApp());
        controller.emailController.text = 'admin@aisyiyah.id';
        controller.passwordController.text = 'password123';

        const fakeUser = User(
          id: 'usr-001',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        );

        when(
          () => mockAuth.signInWithPassword(
            email: 'admin@aisyiyah.id',
            password: 'password123',
          ),
        ).thenAnswer((_) async => AuthResponse(user: fakeUser));

        when(() => mockSupabase.from('profiles')).thenAnswer(
          (_) => FakeSupabaseQueryBuilder({
            'nama_depan': 'Siti',
            'nama_belakang': 'Walidah',
            'ranting_id': 'R01',
            'daerah_id': 'D01',
            'role': 'admin',
            'email': 'admin@aisyiyah.id',
          }),
        );

        // Act
        await controller.handleLogin();
        await tester.pumpAndSettle();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(controller.isLoading.value, isFalse);
        expect(prefs.getBool('isLoggedIn'), isTrue);
        expect(prefs.getString('email'), 'admin@aisyiyah.id');
        expect(prefs.getString('nama_pengguna'), 'Siti Walidah');
        expect(prefs.getString('role'), 'admin');
        expect(prefs.getString('ranting_id'), 'R01');
        expect(prefs.getString('daerah_id'), 'D01');
        expect(find.text('Home Page'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-03 (Negative): Auth berhasil merespons tetapi user == null melempar AuthException',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestApp());
        controller.emailController.text = 'ghost@aisyiyah.id';
        controller.passwordController.text = 'password123';

        when(
          () => mockAuth.signInWithPassword(
            email: 'ghost@aisyiyah.id',
            password: 'password123',
          ),
        ).thenAnswer((_) async => AuthResponse(user: null));

        // Act
        await controller.handleLogin();
        await tester.pump();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(controller.isLoading.value, isFalse);
        expect(prefs.getBool('isLoggedIn'), isNull);
        expect(
          find.text('Login gagal. User tidak ditemukan.'),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'TC-04 (Negative): User terautentikasi tetapi profile == null menampilkan error profil tidak ditemukan',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestApp());
        controller.emailController.text = 'noprofile@aisyiyah.id';
        controller.passwordController.text = 'password123';

        const fakeUser = User(
          id: 'usr-002',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        );

        when(
          () => mockAuth.signInWithPassword(
            email: 'noprofile@aisyiyah.id',
            password: 'password123',
          ),
        ).thenAnswer((_) async => AuthResponse(user: fakeUser));

        when(
          () => mockSupabase.from('profiles'),
        ).thenAnswer((_) => FakeSupabaseQueryBuilder(null));

        // Act
        await controller.handleLogin();
        await tester.pump();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(controller.isLoading.value, isFalse);
        expect(prefs.getBool('isLoggedIn'), isNull);
        expect(
          find.text(
            'Profil user tidak ditemukan. Pastikan data tabel profiles sudah terisi.',
          ),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'TC-05 (Negative): Kredensial salah ("Invalid login credentials") diterjemahkan ke bahasa Indonesia',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestApp());
        controller.emailController.text = 'admin@aisyiyah.id';
        controller.passwordController.text = 'wrongPassword';

        when(
          () => mockAuth.signInWithPassword(
            email: 'admin@aisyiyah.id',
            password: 'wrongPassword',
          ),
        ).thenThrow(const AuthException('Invalid login credentials'));

        // Act
        await controller.handleLogin();
        await tester.pump();

        // Assert
        expect(controller.isLoading.value, isFalse);
        expect(find.text('Email atau password salah.'), findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'TC-06 (Negative): Kesalahan sistem generik menampilkan pesan "Terjadi kesalahan sistem."',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestApp());
        controller.emailController.text = 'admin@aisyiyah.id';
        controller.passwordController.text = 'password123';

        when(
          () => mockAuth.signInWithPassword(
            email: 'admin@aisyiyah.id',
            password: 'password123',
          ),
        ).thenThrow(Exception('Database connection timeout'));

        // Act
        await controller.handleLogin();
        await tester.pump();

        // Assert
        expect(controller.isLoading.value, isFalse);
        expect(find.text('Terjadi kesalahan sistem.'), findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
      },
    );
  });
}
