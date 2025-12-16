import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:process_run/shell.dart';
import 'package:http/http.dart' as http;

class BackendServerManager {
  static Process? _serverProcess;
  static bool _isServerRunning = false;
  static Shell? _shell;
  static int _startAttempts = 0;
  static const int _maxStartAttempts = 3;

  /// Start the Python backend server automatically
  static Future<bool> startServer() async {
    print('\n🚀 ========== STARTING BACKEND SERVER ==========');

    // Don't start server on web or mobile (Android/iOS)
    if (kIsWeb) {
      print('⚠️  Web platform - server should be started manually on host machine');
      print('   Run: cd lib/backend && python api_server.py');
      return false;
    }

    // Mobile platforms cannot run Python server directly
    if (Platform.isAndroid || Platform.isIOS) {
      print('📱 Mobile platform detected: ${Platform.operatingSystem}');
      print('⚠️  Cannot start Python server on mobile devices');
      print('   Options:');
      print('   1. Run server on your computer: cd lib/backend && python api_server.py');
      print('   2. Deploy server to cloud (e.g., Railway, Heroku, AWS)');
      print('   3. Update baseUrl in prediction_service.dart to your server URL');

      // Check if remote server is available
      final isRemoteAvailable = await isServerHealthy();
      if (isRemoteAvailable) {
        print('✅ Remote server is accessible!');
        _isServerRunning = true;
        return true;
      }

      print('❌ No remote server found. Please start the backend server.');
      return false;
    }

    // Desktop platforms (Windows, macOS, Linux) can try to start the server
    print('💻 Desktop platform: ${Platform.operatingSystem}');

    // Check if server is already running
    if (await isServerHealthy()) {
      print('✅ Server is already running and healthy!');
      _isServerRunning = true;
      _startAttempts = 0;
      return true;
    }

    // Limit start attempts to avoid infinite loops
    if (_startAttempts >= _maxStartAttempts) {
      print('❌ Maximum start attempts reached ($_maxStartAttempts)');
      print('   Please start the server manually:');
      print('   1. Open terminal');
      print('   2. cd lib/backend');
      print('   3. python api_server.py');
      return false;
    }

    _startAttempts++;
    print('📋 Start attempt $_startAttempts of $_maxStartAttempts');

    try {
      // Get the path to the backend folder
      final backendPath = _getBackendPath();
      print('📂 Backend path: $backendPath');

      // Check if backend folder exists
      final backendDir = Directory(backendPath);
      if (!await backendDir.exists()) {
        print('❌ Backend folder not found at: $backendPath');
        return false;
      }

      // Check if api_server.py exists
      final apiServerFile = File('$backendPath${Platform.pathSeparator}api_server.py');
      if (!await apiServerFile.exists()) {
        print('❌ api_server.py not found at: ${apiServerFile.path}');
        return false;
      }

      // Check for model.onnx
      final modelFile = File('$backendPath${Platform.pathSeparator}model.onnx');
      if (!await modelFile.exists()) {
        print('⚠️  Warning: model.onnx not found at: ${modelFile.path}');
      }

      // Determine Python command (python or python3)
      String pythonCmd = await _findPythonCommand();
      print('🐍 Using Python command: $pythonCmd');

      // Check Python version
      try {
        final versionResult = await Process.run(pythonCmd, ['--version']);
        print('   Version: ${versionResult.stdout.toString().trim()}');
      } catch (e) {
        print('⚠️  Could not get Python version: $e');
      }

      print('⚙️  Starting server process...');

      // Start the server in background
      if (Platform.isWindows) {
        // On Windows, launch the START_SERVER.bat in a new window
        // First check if START_SERVER.bat exists in project root
        final projectRoot = Directory.current.path;
        final batchFile = File('$projectRoot${Platform.pathSeparator}START_SERVER.bat');

        if (await batchFile.exists()) {
          print('📜 Found START_SERVER.bat - launching in new window...');

          // Launch batch file in a new command prompt window
          _serverProcess = await Process.start(
            'cmd',
            ['/c', 'start', 'cmd', '/k', batchFile.path],
            workingDirectory: projectRoot,
            mode: ProcessStartMode.detached,
          );

          print('✅ Server window opened!');
        } else {
          print('⚠️  START_SERVER.bat not found, starting Python directly...');

          // Fallback: Start Python directly in detached mode
          _serverProcess = await Process.start(
            'cmd',
            ['/c', 'start', 'cmd', '/k', 'cd', backendPath, '&&', pythonCmd, 'api_server.py'],
            workingDirectory: backendPath,
            mode: ProcessStartMode.detached,
          );
        }

      } else {
        // On Unix-like systems (macOS, Linux)
        _serverProcess = await Process.start(
          pythonCmd,
          ['api_server.py'],
          workingDirectory: backendPath,
          runInShell: true,
        );

        // Listen to output
        _serverProcess!.stdout.listen((data) {
          print('📤 Server stdout: ${String.fromCharCodes(data)}');
        });

        _serverProcess!.stderr.listen((data) {
          print('❌ Server stderr: ${String.fromCharCodes(data)}');
        });
      }

      print('⏳ Server process started (PID: ${_serverProcess!.pid})');
      print('   Waiting for server to be ready...');

      // Wait for server to be ready (max 45 seconds with detailed progress)
      for (int i = 0; i < 45; i++) {
        await Future.delayed(const Duration(seconds: 1));

        if (await isServerHealthy()) {
          print('✅ Server is ready and healthy!');
          print('================================================\n');
          _isServerRunning = true;
          _startAttempts = 0;
          return true;
        }

        // Show progress every 5 seconds
        if ((i + 1) % 5 == 0) {
          print('⏳ Still waiting... ${i + 1}s / 45s');
        }
      }

      print('❌ Server did not respond within 45 seconds');
      print('   The server may still be starting. Check manually:');
      print('   http://localhost:8000/health');

      // Try one more time
      if (await isServerHealthy()) {
        print('✅ Server became ready!');
        _isServerRunning = true;
        _startAttempts = 0;
        return true;
      }

      print('================================================\n');
      return false;

    } catch (e, stackTrace) {
      print('❌ Error starting server: $e');
      print('   Stack trace: $stackTrace');
      print('================================================\n');
      return false;
    }
  }


  /// Check if the server is healthy
  static Future<bool> isServerHealthy() async {
    try {
      final url = getServerUrl();
      final response = await http.get(
        Uri.parse('$url/health'),
      ).timeout(const Duration(seconds: 3));

      final isHealthy = response.statusCode == 200;
      if (isHealthy) {
        // print('✓ Server health check: OK');
      }
      return isHealthy;
    } catch (e) {
      // Silently fail for health checks
      return false;
    }
  }

  /// Stop the server
  static Future<void> stopServer() async {
    if (_serverProcess != null) {
      print('🛑 Stopping server...');
      _serverProcess!.kill();
      _serverProcess = null;
      _isServerRunning = false;
      _startAttempts = 0;
      print('✅ Server stopped');
    }
  }

  /// Reset start attempts counter
  static void resetAttempts() {
    _startAttempts = 0;
  }

  /// Get the backend server URL based on platform
  static String getServerUrl() {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      // For Android emulator: 10.0.2.2 maps to host machine's localhost
      return 'http://10.0.2.2:8000';
    } else if (Platform.isIOS) {
      // For iOS simulator: localhost works
      return 'http://localhost:8000';
    } else {
      // Desktop platforms
      return 'http://localhost:8000';
    }
  }

  /// Get the backend folder path
  static String _getBackendPath() {
    // Get the current working directory
    final currentDir = Directory.current.path;

    // The backend is at lib/backend
    if (currentDir.contains('lib')) {
      return '$currentDir${Platform.pathSeparator}backend';
    } else {
      return '$currentDir${Platform.pathSeparator}lib${Platform.pathSeparator}backend';
    }
  }

  /// Find available Python command
  static Future<String> _findPythonCommand() async {
    // Try different Python commands
    final commands = ['python', 'python3', 'py'];

    for (final cmd in commands) {
      try {
        final result = await Process.run(cmd, ['--version']);
        if (result.exitCode == 0) {
          return cmd;
        }
      } catch (e) {
        // Command not found, try next
      }
    }

    // Default to python
    print('⚠️  Could not verify Python installation, using default: python');
    return 'python';
  }

  /// Check server status
  static bool get isRunning => _isServerRunning;

  /// Get current start attempts
  static int get startAttempts => _startAttempts;
}



