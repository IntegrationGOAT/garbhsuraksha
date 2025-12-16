import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'backend_server_manager.dart';

class AnalysisResult {
  final String predictedLabel;
  final double confidence;
  final String status;
  final String message;
  final String recommendation;
  final Map<String, double> probabilities;
  final String gestationPeriod;

  AnalysisResult({
    required this.predictedLabel,
    required this.confidence,
    required this.status,
    required this.message,
    required this.recommendation,
    required this.probabilities,
    required this.gestationPeriod,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      predictedLabel: json['predicted_label'] ?? 'Unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'unknown',
      message: json['message'] ?? '',
      recommendation: json['recommendation'] ?? '',
      probabilities: Map<String, double>.from(
        (json['probabilities'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0.0).toDouble()),
        ),
      ),
      gestationPeriod: json['gestation_period'] ?? '',
    );
  }
}

class PredictionService {
  // Use centralized server URL from BackendServerManager
  static String get baseUrl => BackendServerManager.getServerUrl();

  /// Analyze audio file and get prediction
  static Future<AnalysisResult> analyzeAudio({
    required String audioFilePath,
    required String gestationPeriod,
    List<int>? audioBytes,
  }) async {
    try {
      print('\n🔬 ========== STARTING ANALYSIS ==========');
      print('📍 Server URL: $baseUrl');
      print('🤰 Gestation Period: $gestationPeriod');
      print('🎵 Audio File Path: $audioFilePath');

      final uri = Uri.parse('$baseUrl/analyze');

      var request = http.MultipartRequest('POST', uri);

      // Add gestation period
      request.fields['gestation_period'] = gestationPeriod;

      // Add audio file
      if (kIsWeb) {
        print('🌐 Web platform: Using audio bytes');
        // For web, use bytes directly
        if (audioBytes != null && audioBytes.isNotEmpty) {
          print('   Bytes available: ${audioBytes.length} bytes');
          request.files.add(
            http.MultipartFile.fromBytes(
              'audio_file',
              audioBytes,
              filename: 'recording.wav',
            ),
          );
        } else {
          throw Exception('Audio bytes not available for web platform');
        }
      } else {
        print('📱 Native platform: Using file path');
        // For mobile/desktop, use file path
        final file = File(audioFilePath);
        if (!await file.exists()) {
          throw Exception('Audio file not found: $audioFilePath');
        }

        final fileSize = await file.length();
        print('📦 File size: ${fileSize} bytes');

        // Extract filename safely without Platform.pathSeparator
        String filename = audioFilePath;
        if (audioFilePath.contains('/')) {
          filename = audioFilePath.split('/').last;
        } else if (audioFilePath.contains('\\')) {
          filename = audioFilePath.split('\\').last;
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            'audio_file',
            audioFilePath,
            filename: filename,
          ),
        );
      }

      print('📤 Sending request to server...');

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception(
            'Request timeout after 60 seconds.\n\n'
            'Please ensure:\n'
            '1. Backend server is running\n'
            '2. Server is accessible at $baseUrl\n'
            '3. No firewall is blocking the connection'
          );
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Response received');
      print('   Status Code: ${response.statusCode}');
      print('   Body Length: ${response.body.length} characters');

      if (response.statusCode == 200) {
        print('✅ Analysis successful!');
        final jsonData = json.decode(response.body);
        print('   Prediction: ${jsonData['predicted_label']}');
        print('   Confidence: ${jsonData['confidence']}');
        print('==========================================\n');
        return AnalysisResult.fromJson(jsonData);
      } else {
        print('❌ Server returned error status: ${response.statusCode}');
        print('   Response body: ${response.body}');
        print('==========================================\n');

        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['detail'] ?? 'Server error: ${response.statusCode}',
          );
        } catch (e) {
          throw Exception('Server error (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e) {
      print('❌ Error in analyzeAudio: $e');
      print('==========================================\n');
      rethrow;
    }
  }

  /// Check if the server is running
  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Server health check failed: $e');
      return false;
    }
  }
}

