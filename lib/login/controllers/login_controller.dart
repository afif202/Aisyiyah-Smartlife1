import 'package:aisyiyah_smartlife/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class LoginController extends GetxController {
  final SupabaseClient supabase;

  LoginController({SupabaseClient? supabaseClient})
      : supabase = supabaseClient ?? Supabase.instance.client;

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> handleLogin() async {
    // S1: Validasi apakah input email atau password kosong
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      // S2: Tampilkan snackbar peringatan kolom input harus diisi
      Get.snackbar("Error", "Email dan password harus diisi", backgroundColor: Colors.red, colorText: Colors.white);
      // S3: Return / hentikan eksekusi method login
      return;
    }

    // S4: Set state loading menjadi true
    isLoading.value = true;

    try {
      // S5: Panggil API Supabase Auth signInWithPassword
      final response = await supabase.auth.signInWithPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim()
      );

      // S6: Evaluasi apakah user dari response bernilai null
      if (response.user == null) {
        // S7: Lempar AuthException jika user tidak ditemukan
        throw const AuthException("Login gagal. User tidak ditemukan.");
      }

      // S8: Query data profile dari tabel 'profiles' berdasarkan ID user
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      // S9: Evaluasi apakah data profile pengguna bernilai null
      if (profile == null) {
        // S10: Lempar AuthException jika profil belum terdaftar
        throw const AuthException("Profil user tidak ditemukan. Pastikan data tabel profiles sudah terisi.");
      }

      // S11: Olah dan gabungkan nama depan serta nama belakang
      String fullName = "${profile['nama_depan']} ${profile['nama_belakang'] ?? ''}".trim();

      // S12: Ekstrak ranting_id dari data profile
      String rantingId = profile['ranting_id']?.toString() ?? '';

      // S13: Ekstrak daerah_id dari data profile
      String daerahId = profile['daerah_id']?.toString() ?? '';

      // S14: Ekstrak role pengguna dari profile
      String role = profile['role']?.toString() ?? 'anggota';

      // S15: Ekstrak email pengguna dari profile
      String email = profile['email']?.toString() ?? '';

      // S16: Simpan sesi login pengguna ke SharedPreferences
      await _saveLoginStatus(email, fullName, role, rantingId, daerahId);

      // S17: Navigasi dan alihkan layar ke beranda utama (Routes.HOME)
      Get.offAllNamed(Routes.HOME);

    } on AuthException catch (e) {
      // S18: Ekstrak pesan kesalahan dari AuthException
      String message = e.message;

      // S19: Evaluasi apakah error berisi pesan invalid login credentials
      if (message.contains("Invalid login credentials")) {
        // S20: Format pesan error kredensial tidak valid ke bahasa Indonesia
        message = "Email atau password salah.";
      }

      // S21: Tampilkan snackbar kegagalan autentikasi dengan pesan yang sesuai
      Get.snackbar("Gagal Login", message, backgroundColor: Colors.redAccent, colorText: Colors.white);
    } catch (e) {
      // S22: Cetak log kesalahan ke console
      print("Error Login");

      // S23: Tampilkan snackbar kesalahan sistem generik
      Get.snackbar("Error", "Terjadi kesalahan sistem.", backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      // S24: Kembalikan status loading menjadi false
      isLoading.value = false;
    }
  }


  Future<void> _saveLoginStatus(String email, String namaLengkap, String role, String rantingId, String daerahId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('email', email);

    await prefs.setString('nama_pengguna', namaLengkap);
    await prefs.setString('role', role);

    //Yang disimpan sekarang adalah ID (UUID), bukan nama tempat.
    await prefs.setString('ranting_id', rantingId);
    await prefs.setString('daerah_id', daerahId);
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void navigateToSignUp() {
    Get.toNamed('/signup');
  }

  //untuk mode tamu
  void navigateToMyQuran() {
    loginWithGuestMode();
    Get.toNamed(Routes.MY_QURAN );
  }
  void loginWithGuestMode()async{
    SharedPreferences sp =await SharedPreferences.getInstance();
    sp.setBool("isLoggedIn", true);


  }


  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}