import 'package:http/http.dart' as http;

class BackendServerManager {
  static bool _isServerRunning = false;
  static int _startAttempts = 0;

  /// Production Railway server URL (GLOBAL SERVER ONLY)
  /// Railway automatically handles HTTPS and port forwarding
  static const String productionServerUrl = 'https://garbhsurakhsha.up.railway.app';

  /// Get the backend server URL
  static String getServerUrl() {
    // Always use Railway global server
    return productionServerUrl;
  }

  /// Check backend server connection
  static Future<bool> startServer() async {
    print('\n🚀 ========== CHECKING BACKEND SERVER ==========');

    final serverUrl = getServerUrl();
    print('🌐 Server URL: $serverUrl');

    // Check if remote server is available
    print('🔍 Checking server health...');
    final isHealthy = await isServerHealthy();

    if (isHealthy) {
      print('✅ Backend server is accessible and healthy!');
      _isServerRunning = true;
      _startAttempts = 0;
      return true;
    }

    print('❌ Could not reach backend server.');
    print('   Please check:');
    print('   1. Internet connection is active');
    print('   2. Server is deployed and running at: $serverUrl');
    print('   3. No firewall is blocking the connection');

    return false;
  }

  /// Check if the server is healthy
  static Future<bool> isServerHealthy() async {
    try {
      final url = getServerUrl();
      print('🔍 Health check: $url/health');
      print('   Attempting HTTP GET request...');

      final response = await http.get(
        Uri.parse('$url/health'),
      ).timeout(
        const Duration(seconds: 60), // Increased timeout for Railway cold start
        onTimeout: () {
          print('⏱️ Health check timed out after 60 seconds');
          throw Exception('Connection timeout');
        },
      );

      print('📡 Response received!');
      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');
      print('📋 Response headers: ${response.headers}');

      // Accept both 200 and other success codes
      final isHealthy = response.statusCode >= 200 && response.statusCode < 300;
      if (isHealthy) {
        print('✓ Server health check: OK');
      } else {
        print('✗ Server returned status: ${response.statusCode}');
      }
      return isHealthy;
    } catch (e, stackTrace) {
      print('✗ Server health check failed: $e');
      print('   Error type: ${e.runtimeType}');
      print('   Stack trace: $stackTrace');

      // Try a simpler check - just ping the root endpoint
      try {
        print('🔄 Attempting fallback health check on root endpoint...');
        final response = await http.get(
          Uri.parse(getServerUrl()),
        ).timeout(const Duration(seconds: 60));

        final isHealthy = response.statusCode >= 200 && response.statusCode < 500;
        print('📡 Root endpoint status: ${response.statusCode}');
        if (isHealthy) {
          print('✓ Server is accessible via root endpoint');
          return true;
        }
      } catch (fallbackError, fallbackStack) {
        print('✗ Fallback check also failed: $fallbackError');
        print('   Fallback stack: $fallbackStack');
      }

      return false;
    }
  }

  /// Stop the server (no-op for hosted backend)
  static Future<void> stopServer() async {
    // No need to stop hosted backend
    _isServerRunning = false;
    _startAttempts = 0;
  }

  /// Reset start attempts counter
  static void resetAttempts() {
    _startAttempts = 0;
  }

  /// Check server status
  static bool get isRunning => _isServerRunning;

  /// Get current start attempts
  static int get startAttempts => _startAttempts;
}

