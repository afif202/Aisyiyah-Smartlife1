abstract class Routes {
  Routes._();

  // ==== INITIAL ROUTE =====
  static const SPLASHSCREEN = _Paths.SPLASHSCREEN;

  //===== AUTH =====
  static const LOGIN = _Paths.LOGIN;
  static const SIGNUP = _Paths.SIGNUP;

  //===== HomePage =====
  static const HOME = _Paths.HOME;

  // ===== Menu Feature =====
  static const JADWALKEGIATAN = _Paths.JADWALKEGIATAN;
  static const MY_QURAN = _Paths.MY_QURAN;
  static const UMKM = _Paths.UMKM;
  static const DETAILDONASI = _Paths.DETAILDONASI;
  static const RIWAYATDONASI = _Paths.RIWAYATDONASI;
  static const DONASI = _Paths.DONASI;
  static const PROFILE = _Paths.PROFILE;
}

abstract class _Paths {
  _Paths._();

  static const SPLASHSCREEN = "/splash_screen/";
  static const LOGIN = "/login";
  static const SIGNUP = "/signup";
  static const HOME = "/home";
  static const JADWALKEGIATAN = "/jadwalkegiatan";
  static const MY_QURAN = "/my-quran";
  static const UMKM = "/umkm";
  static const DETAILDONASI = "/donasi/detail/:id";
  static const RIWAYATDONASI = "/donasi/riwayat";
  static const DONASI = "/donasi";
  static const PROFILE = "/profile";
}
