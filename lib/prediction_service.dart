import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'backend_server_manager.dart';

class HeartRateData {
  final double averageFhr;
  final int beatCount;
  final double meanIbi;
  final double sdnn;
  final double rmssd;
  final double cv;
  final double ibiSkewness;
  final int abnormalBeats;
  final double meanFhr;
  final double medianFhr;
  final double minFhr;
  final double maxFhr;
  final double fhrRange;
  final double shortTermVariability;

  HeartRateData({
    required this.averageFhr,
    required this.beatCount,
    required this.meanIbi,
    required this.sdnn,
    required this.rmssd,
    required this.cv,
    required this.ibiSkewness,
    required this.abnormalBeats,
    required this.meanFhr,
    required this.medianFhr,
    required this.minFhr,
    required this.maxFhr,
    required this.fhrRange,
    required this.shortTermVariability,
  });

  factory HeartRateData.fromJson(Map<String, dynamic> json) {
    return HeartRateData(
      averageFhr: (json['average_fhr'] ?? 0.0).toDouble(),
      beatCount: json['beat_count'] ?? 0,
      meanIbi: (json['mean_ibi'] ?? 0.0).toDouble(),
      sdnn: (json['sdnn'] ?? 0.0).toDouble(),
      rmssd: (json['rmssd'] ?? 0.0).toDouble(),
      cv: (json['cv'] ?? 0.0).toDouble(),
      ibiSkewness: (json['ibi_skewness'] ?? 0.0).toDouble(),
      abnormalBeats: json['abnormal_beats'] ?? 0,
      meanFhr: (json['mean_fhr'] ?? 0.0).toDouble(),
      medianFhr: (json['median_fhr'] ?? 0.0).toDouble(),
      minFhr: (json['min_fhr'] ?? 0.0).toDouble(),
      maxFhr: (json['max_fhr'] ?? 0.0).toDouble(),
      fhrRange: (json['fhr_range'] ?? 0.0).toDouble(),
      shortTermVariability: (json['short_term_variability'] ?? 0.0).toDouble(),
    );
  }
}

class FhrAnalysis {
  final int gestationWeeks;
  final int normalRangeMin;
  final int normalRangeMax;
  final double measuredFhr;
  final double normalChance;
  final double bradycardiaChance;
  final double tachycardiaChance;
  final String fhrStatus;
  final String fhrClassification;
  final String severity;
  final int severityLevel;
  final String severityDescription;
  final String urgency;
  final String riskLevel;
  final double deviation;
  final double deviationPercentage;
  final String medicalConcern;
  final String recommendation;

  FhrAnalysis({
    required this.gestationWeeks,
    required this.normalRangeMin,
    required this.normalRangeMax,
    required this.measuredFhr,
    required this.normalChance,
    required this.bradycardiaChance,
    required this.tachycardiaChance,
    required this.fhrStatus,
    required this.fhrClassification,
    required this.severity,
    required this.severityLevel,
    required this.severityDescription,
    required this.urgency,
    required this.riskLevel,
    required this.deviation,
    required this.deviationPercentage,
    required this.medicalConcern,
    required this.recommendation,
  });

  factory FhrAnalysis.fromJson(Map<String, dynamic> json) {
    return FhrAnalysis(
      gestationWeeks: json['gestation_weeks'] ?? 0,
      normalRangeMin: json['normal_range_min'] ?? 0,
      normalRangeMax: json['normal_range_max'] ?? 0,
      measuredFhr: (json['measured_fhr'] ?? 0.0).toDouble(),
      normalChance: (json['normal_chance'] ?? 0.0).toDouble(),
      bradycardiaChance: (json['bradycardia_chance'] ?? 0.0).toDouble(),
      tachycardiaChance: (json['tachycardia_chance'] ?? 0.0).toDouble(),
      fhrStatus: json['fhr_status'] ?? '',
      fhrClassification: json['fhr_classification'] ?? '',
      severity: json['severity'] ?? '',
      severityLevel: json['severity_level'] ?? 0,
      severityDescription: json['severity_description'] ?? '',
      urgency: json['urgency'] ?? '',
      riskLevel: json['risk_level'] ?? '',
      deviation: (json['deviation'] ?? 0.0).toDouble(),
      deviationPercentage: (json['deviation_percentage'] ?? 0.0).toDouble(),
      medicalConcern: json['medical_concern'] ?? '',
      recommendation: json['recommendation'] ?? '',
    );
  }
}

class AnalysisResult {
  final String predictedLabel;
  final double confidence;
  final String status;
  final String message;
  final String recommendation;
  final Map<String, double> probabilities;
  final String gestationPeriod;
  final HeartRateData? heartRateData;
  final FhrAnalysis? fhrAnalysis;

  AnalysisResult({
    required this.predictedLabel,
    required this.confidence,
    required this.status,
    required this.message,
    required this.recommendation,
    required this.probabilities,
    required this.gestationPeriod,
    this.heartRateData,
    this.fhrAnalysis,
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
      heartRateData: json['heart_rate'] != null
          ? HeartRateData.fromJson(json['heart_rate'])
          : null,
      fhrAnalysis: json['fhr_analysis'] != null
          ? FhrAnalysis.fromJson(json['fhr_analysis'])
          : null,
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
      print('🔗 Full URL: $uri');

      // Send request with longer timeout for Railway cold starts
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120), // Increased to 2 minutes for Railway cold start
        onTimeout: () {
          throw Exception(
            'Request timeout after 120 seconds.\n\n'
            'The server may be waking up (Railway cold start).\n'
            'Please try again in a moment.\n\n'
            'Server URL: $baseUrl'
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

