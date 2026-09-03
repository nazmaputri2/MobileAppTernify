import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
// import 'dart:io' show Platform;
import 'package:google_sign_in/google_sign_in.dart';

class ApiService {
  // Ganti dengan IP/URL server kamu
  // Emulator Android  : http://10.0.2.2:8000/api
  // Device fisik      : http://192.168.x.x:8000/api
  // Production        : https://domain-kamu.com/api
 static String get baseUrl {
    // ⚠️  PENTING: Gunakan IP komputer di jaringan lokal, BUKAN localhost/127.0.0.1
    // 127.0.0.1 = localhost HP itu sendiri, bukan komputer kamu!
    //
    // Emulator Android : http://10.0.2.2:8000/api
    // HP Fisik (debug) : http://192.168.1.15:8000/api  ← IP komputer kamu
    // Production       : https://striking-liberation-copy-production.up.railway.app/api

    return "http://192.168.1.15:8000/api"; // HP Fisik
    // return "https://striking-liberation-copy-production.up.railway.app/api"; // Production
  }

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // ─────────────────────────────────────────────
  // TOKEN MANAGEMENT (persistent login)
  // ─────────────────────────────────────────────

  /// Simpan token & data user ke SharedPreferences
  static Future<void> saveSession(
    String token,
    Map<String, dynamic> user,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// Ambil token yang tersimpan
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Ambil data user yang tersimpan
  static Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Hapus session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Cek apakah user sudah login
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ─────────────────────────────────────────────
  // HELPER: build headers
  // ─────────────────────────────────────────────
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─────────────────────────────────────────────
  // REGISTER
  // ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String namaLengkap,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'nama_lengkap': namaLengkap,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // if (response.statusCode == 201 && data['success'] == true) {
      //   await saveSession(data['token'], data['user']);
      // }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  // ─────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        await saveSession(data['token'], data['user']);
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  static Future<Map<String, dynamic>> loginWithGoogle() async {
  try {
    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();

    final String? idToken = googleUser.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      return {
        'success': false,
        'message': 'ID Token Google tidak ditemukan',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/login/google'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'id_token': idToken,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && data['success'] == true) {
      await saveSession(data['token'], data['user']);
    }

    return data;
} on GoogleSignInException catch (e) {
  print('GOOGLE SIGN IN ERROR');
  print('Code: ${e.code}');
  print('Description: ${e.description}');
  print('Details: ${e.details}');

  return {
    'success': false,
    'message': 'Login Google gagal: ${e.code} - ${e.description}',
  };

  } catch (e) {
    return {
      'success': false,
      'message': 'Koneksi gagal: $e',
    };
  }
}

static Future<Map<String, dynamic>> forgotPasswordSendOtp({
  required String email,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password/send-otp'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email}),
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (e) {
    return {'success': false, 'message': 'Koneksi gagal: $e'};
  }
}

static Future<Map<String, dynamic>> forgotPasswordVerifyOtp({
  required String email,
  required String otp,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password/verify-otp'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email, 'otp': otp}),
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (e) {
    return {'success': false, 'message': 'Koneksi gagal: $e'};
  }
}

static Future<Map<String, dynamic>> forgotPasswordReset({
  required String email,
  required String otp,
  required String password,
  required String passwordConfirmation,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password/reset'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (e) {
    return {'success': false, 'message': 'Koneksi gagal: $e'};
  }
}




  // ─────────────────────────────────────────────
  // GET PROFILE
  // ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: await authHeaders(),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Perbarui data user lokal
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(data['user']));
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  // ─────────────────────────────────────────────
  // UPDATE PROFILE
  // ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateProfile({
    String? namaLengkap,
    String? email,
    String? noTelepon,
    String? namaPeternakan,
    String? lokasi,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (namaLengkap != null) body['nama_lengkap'] = namaLengkap;
      if (email != null) body['email'] = email;
      if (noTelepon != null) body['no_telepon'] = noTelepon;
      if (namaPeternakan != null) body['nama_peternakan'] = namaPeternakan;
      if (lokasi != null) body['lokasi'] = lokasi;

      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: await authHeaders(),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Perbarui data user lokal
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(data['user']));
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  // ─────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────
static Future<Map<String, dynamic>> logout() async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/logout'),
      headers: await authHeaders(),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    await clearSession();
    await GoogleSignIn.instance.signOut();

    return data;
  } catch (e) {
    await clearSession();
    await GoogleSignIn.instance.signOut();

    return {'success': false, 'message': 'Koneksi gagal: $e'};
  }
}
// ─────────────────────────────────────────────
// VALIDATE SESSION
// ─────────────────────────────────────────────
static Future<bool> validateSession() async {
  final token = await getToken();

  if (token == null || token.isEmpty) {
    return false;
  }

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/profile'),
      headers: await authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(data['user']));
        return true;
      }
    }

    if (response.statusCode == 401) {
      await clearSession();
      return false;
    }

    return false;
  } catch (_) {
    // Kalau koneksi gagal, tapi token masih ada, user tetap boleh masuk.
    // Ini cocok kalau aplikasi kamu punya mode offline.
    return true;
  }
}

  // ─────────────────────────────────────────────
  // DOMBA API
  // ─────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchDomba({
    String? search,
    String? jenisKelamin,
  }) async {
    final query = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    if (jenisKelamin != null && jenisKelamin.isNotEmpty) {
      query['jenis_kelamin'] = jenisKelamin;
    }

    final uri = Uri.parse('$baseUrl/domba').replace(queryParameters: query);

    final response = await http.get(uri, headers: await authHeaders());

    final decoded = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded['data'];

      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      return [];
    }

    throw Exception(decoded['message'] ?? 'Gagal mengambil data domba');
  }

  static Future<Map<String, dynamic>> createDomba(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/domba'),
      headers: await authHeaders(),
      body: jsonEncode(payload),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw Exception(decoded['message'] ?? 'Gagal menambahkan domba');
  }

  static Future<Map<String, dynamic>> updateDomba(
    String idDomba,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/domba/$idDomba'),
      headers: await authHeaders(),
      body: jsonEncode(payload),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw Exception(decoded['message'] ?? 'Gagal memperbarui domba');
  }

  static Future<void> deleteDomba(String idDomba) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/domba/$idDomba'),
      headers: await authHeaders(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(decoded['message'] ?? 'Gagal menghapus domba');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchBetina() async {
    final response = await http.get(
      Uri.parse('$baseUrl/domba/betina/list'),
      headers: await authHeaders(),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded['data'];

      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      return [];
    }

    throw Exception(decoded['message'] ?? 'Gagal mengambil data betina');
  }

  static Future<List<Map<String, dynamic>>> fetchJantan() async {
    final response = await http.get(
      Uri.parse('$baseUrl/domba/jantan/list'),
      headers: await authHeaders(),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded['data'];

      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      return [];
    }

    throw Exception(decoded['message'] ?? 'Gagal mengambil data jantan');
  }

  static Future<Map<String, dynamic>> fetchDombaStatistik() async {
    final response = await http.get(
      Uri.parse('$baseUrl/domba/statistik'),
      headers: await authHeaders(),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(decoded['data'] ?? {});
    }

    throw Exception(decoded['message'] ?? 'Gagal mengambil statistik domba');
  }

  /// GET /api/kandang/statistik
  static Future<Map<String, dynamic>> fetchKandangStatistik() async {
    final response = await http.get(
      Uri.parse('$baseUrl/kandang/statistik'),
      headers: await authHeaders(),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(decoded['data'] ?? {});
    }

    throw Exception(decoded['message'] ?? 'Gagal mengambil statistik kandang');
  }

  /// GET /api/scan-logs (count only) — returns total scan count
  static Future<int> fetchTotalScan() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/scan-logs').replace(queryParameters: {'per_page': '1'}),
        headers: await authHeaders(),
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Check root-level total (from ScanLogController)
        if (decoded['total'] != null) {
          return (decoded['total'] as num).toInt();
        }
        // Fallback: check meta.total
        final meta = decoded['meta'];
        if (meta != null && meta['total'] != null) {
          return (meta['total'] as num).toInt();
        }
        // Fallback: count data array
        final data = decoded['data'];
        if (data is List) return data.length;
        return 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }


    // ─────────────────────────────────────────────
  // SCAN LOG / RIWAYAT DIGITALISASI API
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> createScanLog({
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/scan-logs'),
        headers: await authHeaders(),
        body: jsonEncode(payload),
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Gagal menyimpan riwayat scan',
        'errors': decoded['errors'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi gagal: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchScanLogs({
    String? search,
    String filter = 'semua',
    int page = 1,
    int perPage = 10,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }

      if (filter != 'semua') {
        query['filter'] = filter;
      }

      if (dateFrom != null && dateFrom.isNotEmpty) {
        query['date_from'] = dateFrom;
      }

      if (dateTo != null && dateTo.isNotEmpty) {
        query['date_to'] = dateTo;
      }

      final uri = Uri.parse('$baseUrl/scan-logs').replace(
        queryParameters: query,
      );

      final response = await http.get(
        uri,
        headers: await authHeaders(),
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Gagal mengambil riwayat scan',
        'data': [],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi gagal: $e',
        'data': [],
      };
    }
  }

  static Future<Map<String, dynamic>> fetchScanLogDetail(String idScan) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/scan-logs/$idScan'),
      headers: await authHeaders(),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    return {
      'success': false,
      'message': decoded['message'] ?? 'Gagal mengambil detail scan',
    };
  } catch (e) {
    return {
      'success': false,
      'message': 'Koneksi gagal: $e',
    };
  }
}

static Future<Map<String, dynamic>> createDombaFromScan(
  Map<String, dynamic> payload,
) async {
  final response = await http.post(
    Uri.parse('$baseUrl/domba/from-scan'),
    headers: await authHeaders(),
    body: jsonEncode(payload),
  );

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return decoded;
  }

  throw Exception(decoded['message'] ?? 'Gagal menyimpan domba hasil scan');
}

static Future<List<Map<String, dynamic>>> fetchDombaBelumKandang() async {
  final response = await http.get(
    Uri.parse('$baseUrl/domba/belum-kandang'),
    headers: await authHeaders(),
  );

  final decoded = jsonDecode(response.body);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    final data = decoded['data'];

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }

  throw Exception(decoded['message'] ?? 'Gagal mengambil domba belum kandang');
}

static Future<Map<String, dynamic>> assignDombaToKandang({
  required String idKandang,
  required List<String> dombaIds,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/kandang/$idKandang/assign-domba'),
    headers: await authHeaders(),
    body: jsonEncode({
      'domba_ids': dombaIds,
    }),
  );

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return decoded;
  }

  throw Exception(decoded['message'] ?? 'Gagal memasukkan domba ke kandang');
}

static Future<Map<String, dynamic>> removeDombaFromKandang({
  required String idKandang,
  required List<String> dombaIds,
  required String reason,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/kandang/$idKandang/remove-domba'),
    headers: await authHeaders(),
    body: jsonEncode({
      'domba_ids': dombaIds,
      'reason': reason,
    }),
  );

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return decoded;
  }

  throw Exception(decoded['message'] ?? 'Gagal mengeluarkan domba dari kandang');
}

static Future<List<Map<String, dynamic>>> fetchSemuaDomba() async {
  final response = await http.get(
    Uri.parse('$baseUrl/kandang/semua-domba'),
    headers: await authHeaders(),
  );

  final decoded = jsonDecode(response.body);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    final data = decoded['data'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  throw Exception(decoded['message'] ?? 'Gagal mengambil data domba');
}

static Future<List<Map<String, dynamic>>> fetchDombaByKandang(
  String idKandang,
) async {
  final response = await http.get(
    Uri.parse('$baseUrl/kandang/$idKandang/domba'),
    headers: await authHeaders(),
  );

  final decoded = jsonDecode(response.body);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    final data = decoded['data'];

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }

  throw Exception(decoded['message'] ?? 'Gagal mengambil domba kandang');
}

  // ─────────────────────────────────────────────
  // REKAM MEDIS API
  // ─────────────────────────────────────────────

  /// POST /api/rekam-medis
static Future<Map<String, dynamic>> createRekamMedis(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rekam-medis'),
      headers: await authHeaders(),
      body: jsonEncode(payload),
    );
    
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    
    throw Exception(decoded['message'] ?? 'Gagal menyimpan rekam medis');
  }
  

  /// GET /api/rekam-medis?ear_tag=xxx
  static Future<List<Map<String, dynamic>>> fetchRekamMedisByEarTag(
    String earTag,
  ) async {
    final uri = Uri.parse('$baseUrl/rekam-medis').replace(
      queryParameters: {'ear_tag': earTag},
    );
    final response = await http.get(uri, headers: await authHeaders());
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded['data'];
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
    throw Exception(decoded['message'] ?? 'Gagal mengambil rekam medis');
  }

  /// GET /api/domba/{id}/rekam-medis
  static Future<List<Map<String, dynamic>>> fetchRekamMedisByDomba(
    String idDomba,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/domba/$idDomba/rekam-medis'),
      headers: await authHeaders(),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded['data'];
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
    throw Exception(decoded['message'] ?? 'Gagal mengambil rekam medis');
  }

  // ─────────────────────────────────────────────
  // PERKAWINAN API
  // ─────────────────────────────────────────────

  /// POST /api/perkawinan
static Future<Map<String, dynamic>> createPerkawinan(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/perkawinan'),
      headers: await authHeaders(),
      body: jsonEncode(payload),
    );
    
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    
    throw Exception(decoded['message'] ?? 'Gagal menyimpan data perkawinan');
  }
  

  /// GET /api/perkawinan?ear_tag=xxx
  static Future<List<Map<String, dynamic>>> fetchPerkawinanByEarTag(
    String earTag,
  ) async {
    final uri = Uri.parse('$baseUrl/perkawinan').replace(
      queryParameters: {'ear_tag': earTag},
    );
    final response = await http.get(uri, headers: await authHeaders());
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded['data'];
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
    throw Exception(decoded['message'] ?? 'Gagal mengambil data perkawinan');
  }

  /// GET /api/domba/{id}/perkawinan
  static Future<List<Map<String, dynamic>>> fetchPerkawinanByDomba(
    String idDomba,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/domba/$idDomba/perkawinan'),
      headers: await authHeaders(),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded['data'];
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
    throw Exception(decoded['message'] ?? 'Gagal mengambil data perkawinan');
  }

  /// PUT /api/perkawinan/{id}
  static Future<Map<String, dynamic>> updatePerkawinan(
    int id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/perkawinan/$id'),
        headers: await authHeaders(),
        body: jsonEncode(payload),
      );
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      return {'success': false, 'message': decoded['message'] ?? 'Gagal memperbarui data perkawinan'};
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }
}
