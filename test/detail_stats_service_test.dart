import 'dart:async';

import 'package:aisyiyah_smartlife/profile/service/DetailStats_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// TEST DOUBLE 1: MOCK (mocktail untuk SupabaseClient & GoTrueClient)
// ============================================================================
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

// ============================================================================
// TEST DOUBLE 2: FAKE (in-memory PostgrestFilterBuilder untuk RPC response)
// ============================================================================
class FakeRpcFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final T _result;
  final bool _shouldThrow;

  FakeRpcFilterBuilder(this._result, {bool shouldThrow = false})
      : _shouldThrow = shouldThrow;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    if (_shouldThrow) {
      return Future<T>.error(Exception('RPC failed'))
          .then(onValue, onError: onError);
    }
    return Future.value(_result).then(onValue, onError: onError);
  }
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late DetailStats_service service;

  const fakeUser = User(
    id: 'usr-profile-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    service = DetailStats_service(supabaseClient: mockSupabase);
  });

  group('DetailStats_service - White-Box Unit Tests', () {
    test(
      'TC-01 (Negative): Melempar Exception jika user belum login (currentUser == null)',
      () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        expect(
          () => service.fetchListItems('kegiatan'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('User not logged in'),
            ),
          ),
        );
      },
    );

    test(
      'TC-02 (Positive): fetchListItems memanggil RPC get_detail_list dan mengembalikan List<Map>',
      () async {
        when(() => mockAuth.currentUser).thenReturn(fakeUser);
        when(
          () => mockSupabase.rpc<List<dynamic>>(
            'get_detail_list',
            params: {
              'request_user_id': 'usr-profile-1',
              'target_type': 'umkm',
            },
          ),
        ).thenAnswer(
          (_) => FakeRpcFilterBuilder<List<dynamic>>([
            {'id': '1', 'nama': 'UMKM A'},
            {'id': '2', 'nama': 'UMKM B'},
          ]),
        );

        final result = await service.fetchListItems('umkm');

        expect(result.length, 2);
        expect(result.first['nama'], 'UMKM A');
        expect(result.last['nama'], 'UMKM B');
      },
    );

    test(
      'TC-03 (Negative): Melempar Exception terbungkus saat RPC gagal',
      () async {
        when(() => mockAuth.currentUser).thenReturn(fakeUser);
        when(
          () => mockSupabase.rpc<List<dynamic>>(
            'get_detail_list',
            params: any(named: 'params'),
          ),
        ).thenAnswer(
          (_) => FakeRpcFilterBuilder<List<dynamic>>([], shouldThrow: true),
        );

        expect(
          () => service.fetchListItems('donasi'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Gagal mengambil data:'),
            ),
          ),
        );
      },
    );
  });
}
