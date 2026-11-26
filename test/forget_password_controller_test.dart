import 'dart:async';

import 'package:aisyiyah_smartlife/forget_password/controllers/forget_password_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// TEST DOUBLE 1: MOCK (mocktail untuk SupabaseClient & FunctionsClient)
// ============================================================================
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

// ============================================================================
// TEST DOUBLE 2: FAKE (in-memory Postgrest query builder untuk tabel profiles)
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
  final PostgrestMap? _result;

  FakePostgrestFilterBuilder(this._result);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    return FakePostgrestTransformBuilder<PostgrestMap?>(_result);
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final PostgrestMap? _result;

  FakeSupabaseQueryBuilder(this._result);

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return FakePostgrestFilterBuilder<PostgrestList>(_result);
  }
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockFunctionsClient mockFunctions;
  late ForgetPasswordController controller;

  Widget createTestApp() {
    return const GetMaterialApp(
      home: Scaffold(body: Text('Forget Password Page')),
    );
  }

  setUp(() {
    Get.reset();
    Get.testMode = true;
    mockSupabase = MockSupabaseClient();
    mockFunctions = MockFunctionsClient();

    when(() => mockSupabase.functions).thenReturn(mockFunctions);
    controller = ForgetPasswordController(supabaseClient: mockSupabase);
  });

  tearDown(() {
    Get.reset();
  });

  group('ForgetPasswordController.sendOtpToWa() - White-Box Unit Tests', () {
    testWidgets(
      'TC-01 (Negative): Nomor WhatsApp kosong menampilkan snackbar Peringatan',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        controller.phoneController.text = '';

        await controller.sendOtpToWa();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Nomor WhatsApp wajib diisi'), findsOneWidget);
        expect(controller.otpSent.value, isFalse);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'TC-02 (Negative): Format nomor WhatsApp tidak valid menampilkan snackbar Error',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        controller.phoneController.text = '0812abc';

        await controller.sendOtpToWa();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Format nomor WhatsApp tidak valid'), findsOneWidget);
        expect(controller.otpSent.value, isFalse);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'TC-03 (Negative): Nomor WhatsApp tidak terdaftar di profiles menampilkan snackbar Gagal',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        controller.phoneController.text = '081234567890';

        when(() => mockSupabase.from('profiles'))
            .thenAnswer((_) => FakeSupabaseQueryBuilder(null));

        await controller.sendOtpToWa();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Nomor WhatsApp tidak terdaftar'), findsOneWidget);
        expect(controller.isLoading.value, isFalse);
        expect(controller.otpSent.value, isFalse);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'TC-04 (Negative): Edge Function mengembalikan status != 200 menampilkan snackbar Error',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        controller.phoneController.text = '081234567890';

        when(() => mockSupabase.from('profiles')).thenAnswer(
          (_) => FakeSupabaseQueryBuilder({
            'id': 'usr-1',
            'no_telepon': '081234567890',
          }),
        );
        when(
          () => mockFunctions.invoke(
            'send-otp-wa',
            body: {'phone': '081234567890', 'user_id': 'usr-1'},
          ),
        ).thenAnswer((_) async => FunctionResponse(status: 500, data: {}));

        await controller.sendOtpToWa();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.textContaining('Gagal mengirim OTP ke WhatsApp'),
          findsOneWidget,
        );
        expect(controller.otpSent.value, isFalse);
        expect(controller.isLoading.value, isFalse);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'TC-05 (Positive): Nomor terdaftar dan status 200 mengirim OTP ke WA dan set otpSent=true',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        controller.phoneController.text = '081234567890';

        when(() => mockSupabase.from('profiles')).thenAnswer(
          (_) => FakeSupabaseQueryBuilder({
            'id': 'usr-1',
            'no_telepon': '081234567890',
          }),
        );
        when(
          () => mockFunctions.invoke(
            'send-otp-wa',
            body: {'phone': '081234567890', 'user_id': 'usr-1'},
          ),
        ).thenAnswer(
          (_) async => FunctionResponse(status: 200, data: {'sent': true}),
        );

        await controller.sendOtpToWa();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(controller.otpSent.value, isTrue);
        expect(controller.isLoading.value, isFalse);
        expect(find.text('Kode OTP berhasil dikirim ke WhatsApp'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );
  });
}
