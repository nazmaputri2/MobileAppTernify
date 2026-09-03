import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// API Configuration
/// Ubah URL di bawah sesuai dengan server FastAPI Anda
class ApiConfig {
  // Ubah 192.168.1.100 dengan IP address atau hostname server Anda
  // Untuk testing lokal: http://localhost:8000
  // Untuk production: http://your-server.com atau https://your-server.com

  static String get baseURL {
    // ⚠️  PENTING: Gunakan IP komputer di jaringan lokal, BUKAN localhost/127.0.0.1
    // 127.0.0.1 = localhost HP itu sendiri, bukan komputer kamu!
    //
    // HP Fisik (debug) : http://192.168.1.15:8001  ← IP komputer kamu
    // Production       : https://mobileappternify-production.up.railway.app

    return "http://192.168.1.9:8001"; // HP Fisik
    // return "https://mobileappternify-production.up.railway.app"; // Production
  }

  // Timeout configuration (dalam seconds)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;

  // Endpoint paths
  static const String scanEndpoint = "/api/v1/scan";
  static const String healthEndpoint = "/health";

  /// Method untuk update URL secara dinamis (jika diperlukan)
  static String getFullURL(String endpoint) {
    return baseURL + endpoint;
  }
}
