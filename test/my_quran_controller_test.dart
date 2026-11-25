import 'package:aisyiyah_smartlife/my_quran/controllers/MyQuran_controller.dart';
import 'package:aisyiyah_smartlife/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// TEST DOUBLE 1: MOCK (mocktail untuk verifikasi pemanggilan callback action)
// ============================================================================
abstract class ActionHandler {
  void call();
}

class MockActionHandler extends Mock implements ActionHandler {}

void main() {
  late MyQuranController controller;
  late MockActionHandler mockAction;

  Widget createTestApp() {
    return GetMaterialApp(
      initialRoute: Routes.MY_QURAN,
      getPages: [
        GetPage(
          name: Routes.MY_QURAN,
          page: () => const Scaffold(body: Text('MyQuran Page')),
        ),
        GetPage(
          name: Routes.HOME,
          page: () => const Scaffold(body: Text('Home Page')),
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
    // TEST DOUBLE 2: FAKE (SharedPreferences in-memory)
    SharedPreferences.setMockInitialValues({});
    controller = MyQuranController();
    mockAction = MockActionHandler();
  });

  tearDown(() {
    Get.reset();
  });

  group('MyQuranController - White-Box Unit Tests', () {
    testWidgets(
      'TC-01 (Negative): runAction saat maintenance menampilkan snackbar dan tidak memanggil action',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        controller.isMaintenance.value = true;

        controller.runAction(mockAction.call);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Sedang Perbaikan'), findsOneWidget);
        verifyNever(() => mockAction());
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );

    test(
      'TC-02 (Positive): runAction saat tidak maintenance mengeksekusi action callback',
      () {
        controller.isMaintenance.value = false;

        controller.runAction(mockAction.call);

        verify(() => mockAction()).called(1);
      },
    );

    testWidgets(
      'TC-03 (Positive): appbarNavigate dengan isLoggedIn=true dan email ada mengarahkan ke HOME',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'isLoggedIn': true,
          'email': 'user@aisyiyah.org',
        });
        await tester.pumpWidget(createTestApp());

        controller.appbarNavigate();
        await tester.pumpAndSettle();

        expect(find.text('Home Page'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-04 (Branch): appbarNavigate dengan isLoggedIn=true tanpa email membersihkan SharedPreferences dan ke LOGIN',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'isLoggedIn': true,
          'customKey': 'shouldBeCleared',
        });
        await tester.pumpWidget(createTestApp());

        controller.appbarNavigate();
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('customKey'), isNull);
        expect(find.text('Login Page'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-05 (Negative): appbarNavigate dengan isLoggedIn=false tetap di halaman MyQuran',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({'isLoggedIn': false});
        await tester.pumpWidget(createTestApp());

        controller.appbarNavigate();
        await tester.pumpAndSettle();

        expect(find.text('MyQuran Page'), findsOneWidget);
      },
    );
  });
}
