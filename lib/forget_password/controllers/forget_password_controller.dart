import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgetPasswordController extends GetxController {
  final SupabaseClient supabase;

  ForgetPasswordController({SupabaseClient? supabaseClient})
      : supabase = supabaseClient ?? Supabase.instance.client;

  final phoneController = TextEditingController();
  final isLoading = false.obs;
  final otpSent = false.obs;

  Future<void> sendOtpToWa() async {
    // S1: Ambil dan bersihkan spasi pada input nomor WhatsApp
    final phone = phoneController.text.trim();

    // S2: Validasi apakah nomor WhatsApp kosong
    if (phone.isEmpty) {
      // S3: Tampilkan snackbar peringatan nomor WhatsApp wajib diisi
      Get.snackbar("Peringatan", "Nomor WhatsApp wajib diisi",
          backgroundColor: Colors.orange, colorText: Colors.white);
      // S4: Hentikan eksekusi pengiriman OTP
      return;
    }

    // S5: Validasi format nomor WhatsApp (10-15 digit angka)
    if (!RegExp(r'^[0-9]{10,15}$').hasMatch(phone)) {
      // S6: Tampilkan snackbar error format nomor tidak valid
      Get.snackbar("Error", "Format nomor WhatsApp tidak valid",
          backgroundColor: Colors.red, colorText: Colors.white);
      // S7: Hentikan eksekusi pengiriman OTP
      return;
    }

    // S8: Set status loading menjadi true
    isLoading.value = true;

    try {
      // S9: Cek apakah nomor WhatsApp terdaftar pada tabel 'profiles'
      final userProfile = await supabase
          .from('profiles')
          .select('id, no_telepon')
          .eq('no_telepon', phone)
          .maybeSingle();

      // S10: Evaluasi apakah data user tidak ditemukan
      if (userProfile == null) {
        // S11: Tampilkan snackbar error nomor tidak terdaftar dan hentikan proses
        Get.snackbar("Gagal", "Nomor WhatsApp tidak terdaftar",
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }

      // S12: Kirim OTP ke WhatsApp melalui Supabase Edge Function 'send-otp-wa'
      final res = await supabase.functions.invoke(
        'send-otp-wa',
        body: {'phone': phone, 'user_id': userProfile['id']},
      );

      // S13: Evaluasi apakah status response dari server gagal (!= 200)
      if (res.status != 200) {
        // S14: Lempar exception kegagalan pengiriman OTP
        throw Exception("Gagal mengirim OTP ke WhatsApp");
      }

      // S15: Tandai otpSent menjadi true dan tampilkan snackbar sukses
      otpSent.value = true;
      Get.snackbar("Sukses", "Kode OTP berhasil dikirim ke WhatsApp",
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      // S16: Tampilkan snackbar error jika terjadi kegagalan sistem/jaringan
      Get.snackbar("Error", "Terjadi kesalahan: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      // S17: Kembalikan status loading menjadi false
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }
}
