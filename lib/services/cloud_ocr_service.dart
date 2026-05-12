import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Cloud AI Service untuk improve OCR results
/// Graceful fallback jika no internet / API error
class CloudOcrService {
  // Try models in order of availability for new API keys
  static const List<String> _geminiModels = [
    'gemini-pro', // Most available for new API keys
    'gemini-1.5-pro',
    'gemini-1.5-flash',
  ];
  
  final _connectivity = Connectivity();

  /// Check if device has internet connection
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('⚠️ Connectivity check error: $e');
      return false;
    }
  }

  /// Get Gemini API key dari SharedPreferences
  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key');
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY') {
      return null;
    }
    return apiKey;
  }

  /// Correct OCR text menggunakan Cloud AI (Gemini)
  /// Jika no internet atau error, return null (fallback to local)
  Future<String?> correctOCRWithCloudAI(String rawOCRText) async {
    // Check internet dulu
    if (!await hasInternetConnection()) {
      print('📡 No internet - skipping Cloud AI correction');
      return null;
    }

    // Check if API key configured
    final apiKey = await _getApiKey();
    if (apiKey == null) {
      print('🔑 Cloud AI API key not configured - skipping');
      return null;
    }

    try {
      print('🌐 Attempting Cloud AI correction via Gemini...');
      
      final prompt = '''
Kamu adalah expert di OCR correction untuk struk belanja Indonesia. 
Perbaiki text OCR berikut - hanya fix errors, jangan tambah/hapus data:

ORIGINAL OCR TEXT:
---
$rawOCRText
---

TASK:
1. Fix typos dan OCR errors (misal: 0→O, l→I, spacing issues)
2. Keep struktur asli (baris, format harga, dll)
3. Jangan ubah data jika sudah benar
4. Output HANYA teks yang sudah diperbaiki (no explanation)

CORRECTED TEXT:''';

      // Try models in order
      for (final model in _geminiModels) {
        try {
          final endpoint =
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

          final response = await http.post(
            Uri.parse('$endpoint?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.2,
                'maxOutputTokens': 2048,
              }
            }),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⏱️ Cloud AI timeout');
              return http.Response('timeout', 408);
            },
          );

          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            final content =
                decoded['candidates']?[0]?['content']?['parts']?[0]?['text'];

            if (content != null && content is String && content.isNotEmpty) {
              print('✅ Cloud AI correction successful (model: $model)');
              return content;
            } else {
              print('⚠️ Cloud AI returned empty response');
              return null;
            }
          } else if (response.statusCode == 404) {
            print('⚠️ Model $model not found (404) - trying next...');
            continue; // Try next model
          } else if (response.statusCode == 429) {
            print('⚠️ Cloud AI rate limit');
            return null;
          } else {
            print('⚠️ Cloud AI error (${response.statusCode}) with $model');
            continue; // Try next model
          }
        } catch (e) {
          print('❌ Error with model $model: $e');
          continue; // Try next model
        }
      }

      print('❌ All Gemini models failed - using local OCR result');
      return null;
    } catch (e) {
      print('❌ Cloud AI error: $e');
      return null;
    }
  }

  /// Validate Gemini API key (run once during setup)
  Future<bool> validateApiKey(String apiKey) async {
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY') {
      return false;
    }

    try {
      print('🔍 Validating API key...');

      // Try 1: List models endpoint (simpler, just checks auth)
      final listModelsUrl =
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';
      final listResponse = await http.get(
        Uri.parse(listModelsUrl),
      ).timeout(const Duration(seconds: 5));

      print('📡 List models response: ${listResponse.statusCode}');

      if (listResponse.statusCode == 200) {
        print('✅ API key valid (list models success)');
        // Also check which models are available
        try {
          final decoded = jsonDecode(listResponse.body);
          final models = decoded['models'] as List?;
          if (models != null) {
            final availableModels = models
                .map((m) => (m['name'] as String).split('/').last)
                .toList();
            print('Available models: $availableModels');
          }
        } catch (e) {
          print('Could not parse available models');
        }
        return true;
      } else if (listResponse.statusCode == 400) {
        print('❌ Bad request - check API key format');
        print('Response: ${listResponse.body}');
        return false;
      } else if (listResponse.statusCode == 401 || listResponse.statusCode == 403) {
        print('❌ Unauthorized - API key tidak valid atau API belum diaktifkan');
        print('Response: ${listResponse.body}');
        return false;
      }

      // Try 2: Generation endpoint (if list models fails)
      print('Trying generation endpoint with gemini-pro...');
      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'test'}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 5));

      print('📡 Generation response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ API key valid (generation success)');
        return true;
      } else {
        print('❌ API error: ${response.statusCode}');
        print('Response: ${response.body}');

        // Check error details
        try {
          final error = jsonDecode(response.body);
          final errorMessage =
              error['error']?['message'] ?? response.body;
          print('Error message: $errorMessage');
        } catch (e) {
          print('Could not parse error response');
        }

        return false;
      }
    } catch (e) {
      print('❌ Validation error: $e');
      return false;
    }
  }
}

