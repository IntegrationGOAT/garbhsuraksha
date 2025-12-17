import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'prediction_service.dart';
import 'backend_server_manager.dart';
import 'package:translator/translator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GarbhSuraksha(),
    );
  }
}

class GarbhSuraksha extends StatefulWidget {
  const GarbhSuraksha({super.key});

  @override
  State<GarbhSuraksha> createState() => _GarbhSurakshaState();
}

class _GarbhSurakshaState extends State<GarbhSuraksha>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _gestationController = TextEditingController();
  String _gestationPeriod = "";
  String _errorMessage = "";

  // Audio related variables
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioFilePath;
  String? _audioFileName;
  List<int>? _audioFileBytes;
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  // Analysis related variables
  bool _isAnalyzing = false;
  AnalysisResult? _analysisResult;

  // Translation variables
  final GoogleTranslator _translator = GoogleTranslator();
  String _selectedLanguageCode = 'en';
  String _selectedLanguageName = 'English';
  final Map<String, String> _translationCache = {};
  final Map<String, Future<String>> _translationFutures = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start loading screen, server, and then show app
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    print('\n🏥 ========== GARBHSURAKSHA APP STARTING ==========');

    // Show loading screen for at least 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    // Check hosted backend server connection
    print('🌐 Connecting to hosted backend server...');
    print('   Server URL: ${BackendServerManager.getServerUrl()}');

    final serverAvailable = await BackendServerManager.startServer();

    if (serverAvailable) {
      print('✅ Backend server is accessible!');
    } else {
      print('⚠️  Could not connect to backend server');
      print('   The app will still load, but analysis features may not work');
      print('   Please check your internet connection');
    }

    print('=================================================\n');

    // Complete loading animation
    _animationController.forward().then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _gestationController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();

    // Stop backend server when app closes
    if (!kIsWeb) {
      BackendServerManager.stopServer();
    }

    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Web recording may have limited support. Please use upload instead.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      if (await Permission.microphone.request().isGranted) {
        final path = kIsWeb
            ? 'recording_${DateTime.now().millisecondsSinceEpoch}.wav'
            : '${Directory.systemTemp.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            numChannels: 1,
            sampleRate: 16000,
          ),
          path: path,
        );

        if (mounted) {
          setState(() {
            _isRecording = true;
            _recordingDuration = 0;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording started!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted && _isRecording) {
            setState(() {
              _recordingDuration++;
            });
          }

          // Auto-stop at 30 seconds
          if (_recordingDuration >= 30) {
            _stopRecording();
            timer.cancel();
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error starting recording: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingDuration = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();

      if (mounted && path != null) {
        // Extract filename from path
        String fileName = path.split('/').last.split('\\').last;
        if (fileName.isEmpty) {
          fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';
        }

        setState(() {
          _isRecording = false;
          _audioFilePath = path;
          _audioFileName = fileName;
          _recordingDuration = 0;
        });

        print('Recording stopped - Path: $path, FileName: $fileName');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording stopped successfully!\n$fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        throw Exception('Recording path is null');
      }
    } catch (e) {
      print('Error stopping recording: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingDuration = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadAudioFile() async {
    if (_audioFilePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No audio file available to download'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final fileName = _audioFileName ?? 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Web downloads are saved to your browser\'s download folder automatically.',
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // First check if source file exists
      final sourceFile = File(_audioFilePath!);
      if (!await sourceFile.exists()) {
        throw Exception('Audio file not found. Please record again.');
      }

      // Read the file bytes
      final fileBytes = await sourceFile.readAsBytes();

      // Use saveFile which works on all platforms and handles permissions automatically
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Audio File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['wav'],
        bytes: fileBytes,
      );

      if (outputPath == null) {
        // User cancelled the save dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download cancelled'),
              backgroundColor: Colors.grey,
            ),
          );
        }
        return;
      }

      // On some platforms, saveFile already writes the file
      // On others, we need to write it ourselves
      try {
        final outputFile = File(outputPath);
        if (!await outputFile.exists()) {
          await outputFile.writeAsBytes(fileBytes);
        }
      } catch (e) {
        print('File already saved by picker: $e');
        // This is expected on some platforms - the file is already saved
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Audio saved successfully!\n$fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Download error: $e');
      if (mounted) {
        String errorMsg = 'Failed to save file';

        if (e.toString().contains('Permission denied')) {
          errorMsg = 'Permission denied. Please try a different location.';
        } else if (e.toString().contains('not found')) {
          errorMsg = 'Audio file not found. Please record again.';
        } else {
          errorMsg = 'Failed to save: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3',
          'wav',
          'm4a',
          'aac',
          'ogg',
          'flac',
          '3gp',
          'amr',
        ],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.single;

        final fileName = pickedFile.name.toLowerCase();
        final validExtensions = [
          'mp3',
          'wav',
          'm4a',
          'aac',
          'ogg',
          'flac',
          '3gp',
          'amr',
        ];
        final hasValidExtension = validExtensions.any(
          (ext) => fileName.endsWith('.$ext'),
        );

        if (!hasValidExtension) {
          throw Exception(
            'Invalid file type. Please select an audio file (.mp3, .wav, .m4a, etc.)',
          );
        }

        if (kIsWeb) {
          if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
            setState(() {
              _audioFileBytes = pickedFile.bytes!;
              _audioFileName = pickedFile.name;
              _audioFilePath = pickedFile.name;
            });

            print('✓ File loaded for web: ${pickedFile.name}');
            print('✓ File size: ${pickedFile.bytes!.length} bytes');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✓ Selected: ${pickedFile.name} (${(pickedFile.bytes!.length / 1024).toStringAsFixed(1)} KB)',
                  ),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            throw Exception('No file data available for web platform');
          }
          return; // Exit early for web
        }

        // For mobile/desktop: Copy to temp directory
        try {
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final tempFileName = pickedFile.name;
          final tempFile = File(
            '${tempDir.path}/upload_$timestamp\_$tempFileName',
          );

          // Priority: Use bytes (loaded via withData: true)
          if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
            // Method 1: Use bytes - Most reliable for Android
            await tempFile.writeAsBytes(pickedFile.bytes!);
            print(
              '✓ File loaded using bytes method (${pickedFile.bytes!.length} bytes)',
            );
          } else if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
            // Method 2: Fallback to path copy for desktop/older Android
            final sourceFile = File(pickedFile.path!);
            if (await sourceFile.exists()) {
              final bytes = await sourceFile.readAsBytes();
              await tempFile.writeAsBytes(bytes);
              print('✓ File loaded from path: ${pickedFile.path}');
            } else {
              throw Exception(
                'Source file not accessible at: ${pickedFile.path}',
              );
            }
          } else {
            throw Exception(
              'No file data available. Please try a different file.',
            );
          }

          // Verify the file was created and has content
          if (await tempFile.exists()) {
            final fileSize = await tempFile.length();
            print('✓ Temp file created: ${tempFile.path}');
            print(
              '✓ File size: $fileSize bytes (${(fileSize / 1024).toStringAsFixed(2)} KB)',
            );

            if (fileSize > 0) {
              setState(() {
                _audioFilePath = tempFile.path;
                _audioFileName = tempFileName;
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✓ Selected: $tempFileName (${(fileSize / 1024).toStringAsFixed(1)} KB)',
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } else {
              throw Exception('File is empty (0 bytes)');
            }
          } else {
            throw Exception('Failed to create temp file');
          }
        } catch (e) {
          print('❌ Error copying file to temp: $e');
          throw Exception('Failed to process file: $e');
        }
      } else {
        print('No file selected or file list is empty');
      }
    } catch (e) {
      print('❌ Error picking file: $e');
      if (mounted) {
        String errorMsg = e.toString();

        // Make error messages user-friendly
        if (errorMsg.contains('file type') && errorMsg.contains('null')) {
          errorMsg =
              'File picker error. Please try selecting from your Downloads or Music folder.';
        } else if (errorMsg.contains('Invalid file type')) {
          errorMsg = errorMsg.split(':').last.trim();
        } else if (errorMsg.contains('namespace')) {
          errorMsg =
              'File access error. Try selecting from Downloads or Music folder.';
        } else if (errorMsg.contains('permission')) {
          errorMsg =
              'Storage permission denied. Grant permission in Settings and retry.';
        } else if (errorMsg.contains('empty')) {
          errorMsg =
              'Selected file is empty (0 bytes). Choose a valid audio file.';
        } else if (errorMsg.contains('instance') ||
            errorMsg.contains('not been loaded')) {
          errorMsg =
              'File loading error. Try selecting a different file or restart the app.';
        } else if (errorMsg.contains('not accessible')) {
          errorMsg =
              'Cannot access file. Try copying it to Downloads folder first.';
        } else {
          // Extract the actual error message
          final parts = errorMsg.split(':');
          errorMsg =
              'Could not load file: ${parts.length > 1 ? parts.last.trim() : errorMsg}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _pickAudioFile(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _analyzeAudio() async {
    print('\n🔬 ========== ANALYZE AUDIO CALLED ==========');
    print('🤰 Gestation period: $_gestationPeriod');
    print('🎵 Audio file path: $_audioFilePath');
    print('📊 Is analyzing: $_isAnalyzing');

    // Validate inputs
    if (_gestationPeriod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please enter gestation period first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_audioFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please record or upload audio first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    try {
      print('🔍 Step 1: Checking server health...');

      // Check if server is running with multiple attempts
      bool isServerRunning = false;
      int maxAttempts = 3;

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        print('   Attempt $attempt/$maxAttempts...');
        isServerRunning = await BackendServerManager.isServerHealthy();

        if (isServerRunning) {
          print('   Server health: ✅ Healthy');
          break;
        } else {
          print('   Server health: ❌ Not responding');
          if (attempt < maxAttempts) {
            print('   Waiting 2 seconds before retry...');
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }

      // If server not running after all attempts
      if (!isServerRunning) {
        print('❌ Server not accessible after $maxAttempts attempts');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⚠️ Backend server not responding. Please check your internet connection.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  _analyzeAudio();
                },
              ),
            ),
          );
        }

        setState(() {
          _isAnalyzing = false;
        });
        return;
      }

      print('✅ Server is ready, proceeding with analysis...');
      print('🔬 Step 2: Sending audio for analysis...');

      // Analyze audio
      final result = await PredictionService.analyzeAudio(
        audioFilePath: _audioFilePath!,
        gestationPeriod: _gestationPeriod,
        audioBytes: _audioFileBytes,
      );

      print('✅ Analysis complete!');
      print('   Prediction: ${result.predictedLabel}');
      print('   Confidence: ${(result.confidence * 100).toStringAsFixed(2)}%');
      print('=============================================\n');

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });

      // Show result dialog
      if (mounted) {
        _showAnalysisResultDialog(result);
      }

    } catch (e) {
      print('❌ Analysis error: $e');
      print('=============================================\n');

      setState(() {
        _isAnalyzing = false;
      });

      if (mounted) {
        String errorMessage = e.toString();

        // Make error messages user-friendly
        if (errorMessage.contains('timeout') ||
            errorMessage.contains('TimeoutException')) {
          errorMessage = '⏱️ Request Timeout\n\n'
              'The server took too long to respond.\n\n'
              'Please check:\n'
              '• Server is running\n'
              '• Network connection is stable\n'
              '• Audio file is not too large';
        } else if (errorMessage.contains('Connection refused') ||
                   errorMessage.contains('Failed host lookup') ||
                   errorMessage.contains('SocketException')) {

          // Check if on physical device
          bool isPhysicalDevice = false;
          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
            isPhysicalDevice = true;
          }

          if (isPhysicalDevice) {
            errorMessage = '🔌 Cannot Connect to Server\n\n'
                'Server URL: ${BackendServerManager.getServerUrl()}\n\n'
                '📱 Running on Physical Device?\n\n'
                'Setup Required:\n\n'
                '1. Start server on your COMPUTER:\n'
                '   • Open Terminal\n'
                '   • cd lib/backend\n'
                '   • python api_server.py\n\n'
                '2. Configure server URL:\n'
                '   • Open Menu (☰)\n'
                '   • Tap "Server Configuration"\n'
                '   • Enter your computer\'s IP\n'
                '   • Example: http://192.168.1.100:8000\n\n'
                '3. Both devices must be on SAME Wi-Fi!\n\n'
                'Need help? See PHYSICAL_DEVICE_SETUP.md';
          } else {
            errorMessage = '🔌 Connection Failed\n\n'
                'Could not connect to server.\n\n'
                'Please ensure:\n'
                '• Server is running at ${BackendServerManager.getServerUrl()}\n'
                '• No firewall is blocking the connection\n'
                '• You are on the same network (for mobile)';
          }
        } else if (errorMessage.contains('SocketException')) {
          errorMessage = '🌐 Network Error\n\n'
              'Please check your network connection and try again.';
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Analysis Error'),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                errorMessage.replaceAll('Exception: ', ''),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _analyzeAudio(); // Retry
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showAnalysisResultDialog(AnalysisResult result) {
    final bool isNormal = result.status == 'healthy';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isNormal ? Icons.check_circle : Icons.warning,
              color: isNormal ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isNormal ? 'Normal Result' : 'Abnormality Detected',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Prediction
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isNormal
                    ? const Color(0xFFD1FAE5)
                    : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isNormal
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prediction: ${result.predictedLabel}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isNormal
                          ? const Color(0xFF065F46)
                          : const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        color: isNormal
                          ? const Color(0xFF047857)
                          : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Heart Rate Analysis Section
              if (result.fhrAnalysis != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2C6E91),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Color(0xFF2C6E91),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<String>(
                            future: _translate('Heart Rate Analysis'),
                            initialData: 'Heart Rate Analysis',
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? 'Heart Rate Analysis',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Average FHR
                      _buildHeartRateInfoRow(
                        'Average Heart Rate:',
                        '${result.fhrAnalysis!.measuredFhr.toStringAsFixed(1)} bpm',
                        Icons.monitor_heart_outlined,
                      ),
                      const SizedBox(height: 8),

                      // Normal Range
                      _buildHeartRateInfoRow(
                        'Normal Range:',
                        '${result.fhrAnalysis!.normalRangeMin}-${result.fhrAnalysis!.normalRangeMax} bpm',
                        Icons.equalizer,
                      ),
                      const SizedBox(height: 12),


                      // Medical Concern
                      if (result.fhrAnalysis!.medicalConcern.toLowerCase() == 'yes')
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.medical_services,
                                color: Color(0xFFEF4444),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Medical attention may be required',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Message
              Text(
                result.message,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Recommendation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF2C6E91),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF2C6E91),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.recommendation,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Probabilities
              const Text(
                'Detailed Probabilities:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...result.probabilities.entries.map((entry) {
                final percentage = (entry.value * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: LinearProgressIndicator(
                          value: entry.value,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            entry.key == 'Normal'
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '$percentage%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 16),

              // Gestation period
              Text(
                'Gestation Period: ${result.gestationPeriod}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper widget for heart rate info rows
  Widget _buildHeartRateInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2C6E91)),
        const SizedBox(width: 6),
        Expanded(
          child: FutureBuilder<String>(
            future: _translate(label),
            initialData: label,
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              );
            },
          ),
        ),
        Flexible(
          child: FutureBuilder<String>(
            future: _translate(value),
            initialData: value,
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.right,
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper widget for probability bars
  Widget _buildProbabilityBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FutureBuilder<String>(
              future: _translate(label),
              initialData: label,
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                );
              },
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // Helper method to get risk color
  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return const Color(0xFF10B981);
      case 'medium':
      case 'moderate':
        return const Color(0xFFF59E0B);
      case 'high':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  // Helper method to get risk icon
  IconData _getRiskIcon(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Icons.check_circle_outline;
      case 'medium':
      case 'moderate':
        return Icons.warning_amber_outlined;
      case 'high':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  // Translation methods
  Future<String> _translate(String text) async {
    if (_selectedLanguageCode == 'en' || text.isEmpty) {
      return text;
    }

    final cacheKey = '$text|$_selectedLanguageCode';

    // Return cached translation if available
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    // Return existing future if translation is in progress
    if (_translationFutures.containsKey(cacheKey)) {
      return _translationFutures[cacheKey]!;
    }

    // Create new translation future
    final future = _performTranslation(text, cacheKey);
    _translationFutures[cacheKey] = future;

    return future;
  }

  Future<String> _performTranslation(String text, String cacheKey) async {
    try {
      final translation = await _translator.translate(
        text,
        from: 'en',
        to: _selectedLanguageCode,
      );
      _translationCache[cacheKey] = translation.text;
      _translationFutures.remove(cacheKey); // Remove future once complete
      return translation.text;
    } catch (e) {
      print('Translation error: $e');
      _translationFutures.remove(cacheKey); // Remove future on error
      return text;
    }
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C6E91),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.translate, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Language',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _getLanguageList().map((lang) {
                      return ListTile(
                        leading: Icon(
                          Icons.language,
                          color: _selectedLanguageCode == lang['code']
                              ? const Color(0xFF2C6E91)
                              : Colors.grey,
                        ),
                        title: Text(
                          lang['name']!,
                          style: TextStyle(
                            fontWeight: _selectedLanguageCode == lang['code']
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedLanguageCode == lang['code']
                                ? const Color(0xFF2C6E91)
                                : Colors.black87,
                          ),
                        ),
                        trailing: _selectedLanguageCode == lang['code']
                            ? const Icon(Icons.check, color: Color(0xFF2C6E91))
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedLanguageCode = lang['code']!;
                            _selectedLanguageName = lang['name']!;
                            _translationCache.clear();
                            _translationFutures.clear();
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Language changed to ${lang['name']}'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: const Color(0xFF2C6E91),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, String>> _getLanguageList() {
    return [
      {'code': 'en', 'name': 'English'},
      {'code': 'hi', 'name': 'Hindi (हिंदी)'},
      {'code': 'bn', 'name': 'Bengali (বাংলা)'},
      {'code': 'te', 'name': 'Telugu (తెలుగు)'},
      {'code': 'mr', 'name': 'Marathi (मराठी)'},
      {'code': 'ta', 'name': 'Tamil (தமிழ்)'},
      {'code': 'gu', 'name': 'Gujarati (ગુજરાતી)'},
      {'code': 'kn', 'name': 'Kannada (ಕನ್ನಡ)'},
      {'code': 'ml', 'name': 'Malayalam (മലയാളം)'},
      {'code': 'pa', 'name': 'Punjabi (ਪੰਜਾਬੀ)'},
      {'code': 'or', 'name': 'Odia (ଓଡ଼ିଆ)'},
      {'code': 'ur', 'name': 'Urdu (اردو)'},
      {'code': 'es', 'name': 'Spanish (Español)'},
      {'code': 'fr', 'name': 'French (Français)'},
      {'code': 'de', 'name': 'German (Deutsch)'},
      {'code': 'zh-CN', 'name': 'Chinese Simplified (简体中文)'},
      {'code': 'zh-TW', 'name': 'Chinese Traditional (繁體中文)'},
      {'code': 'ja', 'name': 'Japanese (日本語)'},
      {'code': 'ko', 'name': 'Korean (한국어)'},
      {'code': 'ar', 'name': 'Arabic (العربية)'},
      {'code': 'ru', 'name': 'Russian (Русский)'},
      {'code': 'pt', 'name': 'Portuguese (Português)'},
      {'code': 'it', 'name': 'Italian (Italiano)'},
      {'code': 'nl', 'name': 'Dutch (Nederlands)'},
      {'code': 'tr', 'name': 'Turkish (Türkçe)'},
      {'code': 'vi', 'name': 'Vietnamese (Tiếng Việt)'},
      {'code': 'th', 'name': 'Thai (ไทย)'},
      {'code': 'id', 'name': 'Indonesian (Bahasa Indonesia)'},
      {'code': 'ms', 'name': 'Malay (Bahasa Melayu)'},
      {'code': 'pl', 'name': 'Polish (Polski)'},
      {'code': 'uk', 'name': 'Ukrainian (Українська)'},
      {'code': 'ro', 'name': 'Romanian (Română)'},
      {'code': 'cs', 'name': 'Czech (Čeština)'},
      {'code': 'el', 'name': 'Greek (Ελληνικά)'},
      {'code': 'sv', 'name': 'Swedish (Svenska)'},
      {'code': 'da', 'name': 'Danish (Dansk)'},
      {'code': 'fi', 'name': 'Finnish (Suomi)'},
      {'code': 'no', 'name': 'Norwegian (Norsk)'},
      {'code': 'hu', 'name': 'Hungarian (Magyar)'},
      {'code': 'he', 'name': 'Hebrew (עברית)'},
      {'code': 'fa', 'name': 'Persian (فارسی)'},
      {'code': 'af', 'name': 'Afrikaans'},
      {'code': 'sq', 'name': 'Albanian (Shqip)'},
      {'code': 'sw', 'name': 'Swahili (Kiswahili)'},
      {'code': 'ne', 'name': 'Nepali (नेपाली)'},
    ];
  }

  // Widget for translated text
  Widget _buildTranslatedText(
    String text, {
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return FutureBuilder<String>(
      future: _translate(text),
      initialData: text,
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isLoading
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF2C6E91),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_hospital,
                      color: Color(0xFF2C6E91),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTranslatedText(
                          "GarbhSuraksha",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _buildTranslatedText(
                          "Maternal Health Monitoring",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              elevation: 2,
              actions: [
                IconButton(
                  icon: const Icon(Icons.translate, color: Colors.white),
                  tooltip: 'Change Language',
                  onPressed: _showLanguageSelector,
                ),
                const SizedBox(width: 8),
              ],
            ),
      drawer: _isLoading
          ? null
          : Drawer(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 20,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2C6E91), Color(0xFF4A90B5)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.local_hospital_outlined,
                            size: 50,
                            color: Color(0xFF2C6E91),
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildTranslatedText(
                          "GarbhSuraksha",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _buildTranslatedText(
                          "Fetal Monitoring System",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(
                      Icons.dashboard_outlined,
                      color: Color(0xFF2C6E91),
                    ),
                    title: _buildTranslatedText(
                      "Dashboard",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.calendar_today_outlined,
                      color: Color(0xFF2C6E91),
                    ),
                    title: _buildTranslatedText(
                      "Appointments",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.medical_services_outlined,
                      color: Color(0xFF2C6E91),
                    ),
                    title: _buildTranslatedText(
                      "Medical Records",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF2C6E91),
                    ),
                    title: _buildTranslatedText(
                      "Reminders",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF2C6E91),
                    ),
                    title: _buildTranslatedText(
                      "Settings",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.help_outline,
                      color: Color(0xFF2C6E91),
                    ),
                    title: _buildTranslatedText(
                      "Help & Support",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _buildTranslatedText(
                      "Version 1.0.0",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
      body: Stack(
        children: [
          // Main Content (Form Screen)
          if (!_isLoading)
            Container(
              decoration: const BoxDecoration(color: Color(0xFFF5F8FA)),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Professional Medical Icon
                      Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C6E91),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.monitor_heart,
                          size: 55,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 25),
                      // Clinical Title
                      _buildTranslatedText(
                        "Smart Fetal Heart Rate Monitor",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTranslatedText(
                        "Enter current gestational week for fetal heart rate monitoring",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 35),
                      // Input Card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTranslatedText(
                              "Gestational Week",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _gestationController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1F2937),
                              ),
                              decoration: InputDecoration(
                                hintText: "Enter weeks (5-42)",
                                hintStyle: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: const Icon(
                                  Icons.event_note,
                                  color: Color(0xFF2C6E91),
                                  size: 24,
                                ),
                                suffixText: "weeks",
                                suffixStyle: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D5DB),
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D5DB),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2C6E91),
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    int? weeks = int.tryParse(
                                      _gestationController.text,
                                    );
                                    if (weeks == null) {
                                      _errorMessage =
                                          "Please enter a valid number";
                                      _gestationPeriod = "";
                                    } else if (weeks > 42) {
                                      _errorMessage =
                                          "Gestational age cannot exceed 42 weeks";
                                      _gestationPeriod = "";
                                    } else if (weeks < 5) {
                                      _errorMessage =
                                          "Fetal heart requires minimum 6 weeks to develop";
                                      _gestationPeriod = "";
                                    } else {
                                      _gestationPeriod =
                                          _gestationController.text;
                                      _errorMessage = "";

                                      // Reset audio-related states when continuing assessment
                                      _audioFilePath = null;
                                      _audioFileName = null;
                                      _audioFileBytes = null;
                                      _isRecording = false;
                                      _recordingDuration = 0;
                                      _recordingTimer?.cancel();
                                    }
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2C6E91),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FutureBuilder<String>(
                                      future: _translate("Continue Assessment"),
                                      initialData: "Continue Assessment",
                                      builder: (context, snapshot) {
                                        return Text(
                                          snapshot.data ?? "Continue Assessment",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Display Error Message
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFEF4444),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFDC2626),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTranslatedText(
                                      "Validation Error",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF991B1B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FutureBuilder<String>(
                                      future: _translate(_errorMessage),
                                      initialData: _errorMessage,
                                      builder: (context, snapshot) {
                                        return Text(
                                          snapshot.data ?? _errorMessage,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF991B1B),
                                            height: 1.4,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Display Result
                      if (_gestationPeriod.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildTranslatedText(
                                    "Assessment Confirmed",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF10B981),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildTranslatedText(
                                      "Current Gestation:",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FutureBuilder<String>(
                                      future: _translate("$_gestationPeriod Weeks"),
                                      initialData: "$_gestationPeriod Weeks",
                                      builder: (context, snapshot) {
                                        return Text(
                                          snapshot.data ?? "$_gestationPeriod Weeks",
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF065F46),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_gestationPeriod.isNotEmpty)
                        const SizedBox(height: 28),
                      if (_gestationPeriod.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                spreadRadius: 0,
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2C6E91,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.graphic_eq,
                                      color: Color(0xFF2C6E91),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildTranslatedText(
                                          "Fetal Heart Sound Recording",
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A1A),
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        _buildTranslatedText(
                                          "Record or upload fetal heartbeat audio",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF6B7280),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),


                              if (_isRecording)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Recording Status
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // Animated pulsing dot
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0.4, end: 1.0),
                                            duration: const Duration(
                                              milliseconds: 600,
                                            ),
                                            builder: (context, value, child) {
                                              return Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFDC2626,
                                                  ).withValues(alpha: value),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color:
                                                          const Color(
                                                            0xFFDC2626,
                                                          ).withValues(
                                                            alpha: value * 0.4,
                                                          ),
                                                      spreadRadius: 2,
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            onEnd: () {
                                              if (_isRecording) {
                                                setState(() {});
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            "Recording in Progress",
                                            style: TextStyle(
                                              color: Color(0xFF991B1B),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          "${_recordingDuration}s / 30s",
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF991B1B),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: _recordingDuration / 30,
                                          backgroundColor: const Color(
                                            0xFFE5E7EB,
                                          ),
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                Color
                                              >(Color(0xFFDC2626)),
                                          minHeight: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),



                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isRecording
                                          ? _stopRecording
                                          : _startRecording,
                                      icon: Icon(
                                        _isRecording
                                            ? Icons.stop_circle_outlined
                                            : Icons.mic_none,
                                        size: 22,
                                      ),
                                      label: FutureBuilder<String>(
                                        future: _translate(
                                          _isRecording ? "Stop" : "Record Audio",
                                        ),
                                        initialData: _isRecording ? "Stop" : "Record Audio",
                                        builder: (context, snapshot) {
                                          return Text(
                                            snapshot.data ?? (_isRecording ? "Stop" : "Record Audio"),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        },
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isRecording
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF2C6E91),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Upload Button
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _isRecording
                                          ? null
                                          : _pickAudioFile,
                                      icon: const Icon(
                                        Icons.upload_file,
                                        size: 22,
                                      ),
                                      label: FutureBuilder<String>(
                                        future: _translate("Upload File"),
                                        initialData: "Upload File",
                                        builder: (context, snapshot) {
                                          return Text(
                                            snapshot.data ?? "Upload File",
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        },
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF2C6E91,
                                        ),
                                        disabledForegroundColor: const Color(
                                          0xFF9CA3AF,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        side: BorderSide(
                                          color: _isRecording
                                              ? const Color(0xFFE5E7EB)
                                              : const Color(0xFF2C6E91),
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),


                              if (_audioFileName != null) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF10B981),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.library_music,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  "Audio File Ready",
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF065F46),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _audioFileName!,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF065F46),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: _downloadAudioFile,
                                              icon: const Icon(
                                                Icons.download_outlined,
                                                size: 18,
                                              ),
                                              label: FutureBuilder<String>(
                                                future: _translate("Download"),
                                                initialData: "Download",
                                                builder: (context, snapshot) {
                                                  return Text(
                                                    snapshot.data ?? "Download",
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  );
                                                },
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF059669,
                                                ),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                elevation: 0,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: (_audioFilePath != null &&
                                                      _gestationPeriod
                                                          .isNotEmpty &&
                                                      !_isAnalyzing)
                                                  ? () {
                                                      print('ANALYZE BUTTON PRESSED');
                                                      print('Audio path: $_audioFilePath');
                                                      print('Gestation: $_gestationPeriod');
                                                      _analyzeAudio();
                                                    }
                                                  : null,
                                              icon: _isAnalyzing
                                                  ? SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<Color>(Colors.white),
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.analytics_outlined,
                                                      size: 18,
                                                    ),
                                              label: FutureBuilder<String>(
                                                future: _translate(
                                                  _isAnalyzing
                                                      ? "Processing..."
                                                      : "AI Overview",
                                                ),
                                                initialData: _isAnalyzing
                                                    ? "Processing..."
                                                    : "AI Overview",
                                                builder: (context, snapshot) {
                                                  return Text(
                                                    snapshot.data ??
                                                        (_isAnalyzing
                                                            ? "Processing..."
                                                            : "AI Overview"),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  );
                                                },
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF2C6E91,
                                                ),
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor:
                                                    const Color(0xFF9CA3AF),
                                                disabledForegroundColor:
                                                    Colors.white70,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                elevation: 0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () {
                                                setState(() {
                                                  _audioFilePath = null;
                                                  _audioFileName = null;
                                                  _audioFileBytes = null;
                                                });
                                                _startRecording();
                                              },
                                              icon: const Icon(
                                                Icons.mic_none,
                                                size: 18,
                                              ),
                                              label: FutureBuilder<String>(
                                                future: _translate("New Recording"),
                                                initialData: "New Recording",
                                                builder: (context, snapshot) {
                                                  return Text(
                                                    snapshot.data ?? "New Recording",
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  );
                                                },
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(
                                                  0xFF2C6E91,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                side: const BorderSide(
                                                  color: Color(0xFF2C6E91),
                                                  width: 1.5,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: FutureBuilder<String>(
                                                      future: _translate('Cancel Recording'),
                                                      initialData: 'Cancel Recording',
                                                      builder: (context, snapshot) {
                                                        return Text(
                                                          snapshot.data ?? 'Cancel Recording',
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    content: FutureBuilder<String>(
                                                      future: _translate(
                                                        'Are you sure you want to cancel this recording? This action cannot be undone.',
                                                      ),
                                                      initialData:
                                                        'Are you sure you want to cancel this recording? This action cannot be undone.',
                                                      builder: (context, snapshot) {
                                                        return Text(
                                                          snapshot.data ??
                                                            'Are you sure you want to cancel this recording? This action cannot be undone.',
                                                        );
                                                      },
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                            ),
                                                        child: FutureBuilder<String>(
                                                          future: _translate('Keep Recording'),
                                                          initialData: 'Keep Recording',
                                                          builder: (context, snapshot) {
                                                            return Text(
                                                              snapshot.data ?? 'Keep Recording',
                                                              style: const TextStyle(
                                                                color: Color(
                                                                  0xFF6B7280,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          setState(() {
                                                            _audioFilePath =
                                                                null;
                                                            _audioFileName =
                                                                null;
                                                            _audioFileBytes =
                                                                null;
                                                          });
                                                          _translate('Recording cancelled').then((translated) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  translated,
                                                                ),
                                                                backgroundColor:
                                                                    const Color(
                                                                      0xFF6B7280,
                                                                    ),
                                                                duration:
                                                                    const Duration(
                                                                      seconds: 2,
                                                                    ),
                                                              ),
                                                            );
                                                          });
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                                0xFFDC2626,
                                                              ),
                                                          foregroundColor:
                                                              Colors.white,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                        ),
                                                        child: FutureBuilder<String>(
                                                          future: _translate('Cancel Recording'),
                                                          initialData: 'Cancel Recording',
                                                          builder: (context, snapshot) {
                                                            return Text(
                                                              snapshot.data ?? 'Cancel Recording',
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.close,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                "Cancel",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(
                                                  0xFFDC2626,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                side: const BorderSide(
                                                  color: Color(0xFFDC2626),
                                                  width: 1.5,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          // Loading Screen Overlay
          if (_isLoading)
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFFF5F8FA)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    Center(
                      child: Container(
                        height: 180,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              spreadRadius: 0,
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF6366F1).withValues(alpha: 0.1),
                                const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.pregnant_woman,
                              size: 100,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            spreadRadius: 0,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Column(
                        children: [
                          Text(
                            "GarbhSuraksha",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C6E91),
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Maternal Health Monitoring System",
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Color(0xFF2C6E91),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Initializing...",
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Connecting to backend server",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
