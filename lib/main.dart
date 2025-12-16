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

    // Start backend server automatically (only on desktop, not mobile/web)
    if (!kIsWeb) {
      if (Platform.isAndroid || Platform.isIOS) {
        print('📱 Mobile platform detected');
        print('⚠️  Server must be running on external machine');
        print('   Expected server at: ${BackendServerManager.getServerUrl()}');

        // Check if server is accessible
        print('🔍 Checking for remote server...');
        final serverAvailable = await BackendServerManager.isServerHealthy();

        if (serverAvailable) {
          print('✅ Remote server is accessible!');
        } else {
          print('❌ No server found. User will need to start it manually.');
          print('   Instructions will be shown when analysis is attempted.');
        }
      } else {
        print('💻 Desktop platform - attempting to start local server...');
        print('   A new window will open with the backend server');

        if (mounted) {
        }

        final serverStarted = await BackendServerManager.startServer();

        if (serverStarted) {
          print('✅ Backend server started successfully!');
          print('   Keep the server window open while using the app');
        } else {
          print('⚠️  Backend server could not be started automatically');
          print('   You can start it manually using START_SERVER.bat');
        }
      }
    } else {
      print('🌐 Web platform - server must be started manually');
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
      final fileName = _audioFileName ?? 'recording.wav';

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

      if (Platform.isAndroid) {
        PermissionStatus permissionStatus;

        if (await Permission.manageExternalStorage.isPermanentlyDenied ||
            await Permission.storage.isPermanentlyDenied) {
          // Show dialog to user
          if (mounted) {
            final shouldOpenSettings = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Permission Required'),
                content: const Text(
                  'Storage permission is required to download files. '
                  'Please enable it in app settings.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );

            if (shouldOpenSettings == true) {
              await openAppSettings();
            }
          }
          return;
        }

        permissionStatus = await Permission.manageExternalStorage.request();

        if (!permissionStatus.isGranted) {
          permissionStatus = await Permission.storage.request();
        }

        if (!permissionStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Storage permission is required to download files',
                ),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download cancelled - No folder selected'),
              backgroundColor: Colors.grey,
            ),
          );
        }
        return;
      }

      // Copy file to selected directory
      final newPath = '$selectedDirectory${Platform.pathSeparator}$fileName';

      print('Copying from: $_audioFilePath');
      print('Copying to: $newPath');

      await sourceFile.copy(newPath);

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
        String errorMessage = 'Failed to save file';

        if (e.toString().contains('not found')) {
          errorMessage = 'Audio file not found. Please record again.';
        } else if (e.toString().contains('Permission denied')) {
          errorMessage = 'Permission denied. Please grant storage permission.';
        } else if (e.toString().contains('No such file')) {
          errorMessage = 'Source file missing. Please record again.';
        } else {
          errorMessage = 'Failed to save file: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _downloadAudioFile(),
            ),
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

      // Check if server is running
      bool isServerRunning = await BackendServerManager.isServerHealthy();
      print('   Server health: ${isServerRunning ? "✅ Healthy" : "❌ Not responding"}');

      // If server not running, try to start it (desktop only)
      if (!isServerRunning && !kIsWeb) {
        if (Platform.isAndroid || Platform.isIOS) {
          // Mobile platform - can't start server locally
          print('📱 Mobile platform - server must be on external machine');

          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Server Not Running',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'The Python backend server must be running on your COMPUTER to analyze audio files.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[300]!, width: 2),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.play_circle_filled, color: Colors.blue, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Quick Start',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'On your COMPUTER:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text('1️⃣ Open Terminal/Command Prompt', style: TextStyle(fontSize: 13)),
                            SizedBox(height: 4),
                            Text('2️⃣ Run these commands:', style: TextStyle(fontSize: 13)),
                            SizedBox(height: 8),
                            Text(
                              '   cd lib/backend\n'
                              '   pip install -r requirements.txt\n'
                              '   python api_server.py',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text('3️⃣ Wait for:', style: TextStyle(fontSize: 13)),
                            SizedBox(height: 4),
                            Text(
                              '   "Uvicorn running on http://0.0.0.0:8000"',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text('4️⃣ Keep terminal OPEN and click Retry!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber[300]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Or double-click START_SERVER.bat in project folder',
                                style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Read: START_HERE_FIRST.txt for detailed help',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _analyzeAudio();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }

          setState(() {
            _isAnalyzing = false;
          });
          return;

        } else {
          // Desktop platform - try to start server
          print('💻 Desktop - attempting to start server...');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text('Starting backend server, please wait...'),
                  ],
                ),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 45),
              ),
            );
          }

          final serverStarted = await BackendServerManager.startServer();

          if (serverStarted) {
            isServerRunning = true;
            print('✅ Server started successfully!');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Server started successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }

            // Give server a moment to fully initialize
            await Future.delayed(const Duration(seconds: 2));

          } else {
            print('❌ Could not start server automatically');
            throw Exception(
              'Could not start backend server automatically.\n\n'
              'Please start it manually:\n'
              'Then try analyzing again.'
            );
          }
        }
      }

      // Verify server is accessible one more time
      if (!isServerRunning) {
        print('❌ Server still not accessible, throwing error');
        throw Exception(
          'Backend server is not accessible.\n\n'
          'Server URL: ${BackendServerManager.getServerUrl()}'
        );
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "GarbhSuraksha",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "Maternal Health Monitoring",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              elevation: 2,
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
                        const Text(
                          "GarbhSuraksha",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          "Fetal Monitoring System",
                          style: TextStyle(
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
                    title: const Text(
                      "Dashboard",
                      style: TextStyle(fontWeight: FontWeight.w500),
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
                    title: const Text(
                      "Appointments",
                      style: TextStyle(fontWeight: FontWeight.w500),
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
                    title: const Text(
                      "Medical Records",
                      style: TextStyle(fontWeight: FontWeight.w500),
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
                    title: const Text(
                      "Reminders",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.dns_outlined,
                      color: Color(0xFF2C6E91),
                    ),
                    title: const Text(
                      "Server Configuration",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      BackendServerManager.customServerUrl ?? "Auto",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showServerConfigDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF2C6E91),
                    ),
                    title: const Text(
                      "Settings",
                      style: TextStyle(fontWeight: FontWeight.w500),
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
                    title: const Text(
                      "Help & Support",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "Version 1.0.0",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
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
                      const Text(
                        "Smart Fetal Heart Rate Monitor",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Enter current gestational week for fetal heart rate monitoring",
                        style: TextStyle(
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
                            const Text(
                              "Gestational Week",
                              style: TextStyle(
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
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Continue Assessment",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward, size: 18),
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
                                    const Text(
                                      "Validation Error",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF991B1B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _errorMessage,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF991B1B),
                                        height: 1.4,
                                      ),
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
                                  const Text(
                                    "Assessment Confirmed",
                                    style: TextStyle(
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
                                    const Text(
                                      "Current Gestation:",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "$_gestationPeriod Weeks",
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF065F46),
                                      ),
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
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Fetal Heart Sound Recording",
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A1A),
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          "Record or upload fetal heartbeat audio",
                                          style: TextStyle(
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
                                      label: Text(
                                        _isRecording ? "Stop" : "Record Audio",
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                                      label: const Text(
                                        "Upload File",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                                              label: const Text(
                                                "Download",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
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
                                              label: Text(
                                                _isAnalyzing
                                                    ? "Processing..."
                                                    : "AI Overview",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
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
                                              label: const Text(
                                                "New Recording",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
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
                                                    title: const Text(
                                                      'Cancel Recording',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    content: const Text(
                                                      'Are you sure you want to cancel this recording? This action cannot be undone.',
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
                                                        child: const Text(
                                                          'Keep Recording',
                                                          style: TextStyle(
                                                            color: Color(
                                                              0xFF6B7280,
                                                            ),
                                                          ),
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
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                'Recording cancelled',
                                                              ),
                                                              backgroundColor:
                                                                  Color(
                                                                    0xFF6B7280,
                                                                  ),
                                                              duration:
                                                                  Duration(
                                                                    seconds: 2,
                                                                  ),
                                                            ),
                                                          );
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
                                                        child: const Text(
                                                          'Cancel Recording',
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            'https://static.vecteezy.com/system/resources/thumbnails/000/585/705/small/5-08.jpg',
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: const Color(0xFF6366F1),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
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
                              );
                            },
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
                    if (!kIsWeb)
                      const SizedBox(height: 4),
                    if (!kIsWeb)
                      const Text(
                        "Starting backend server",
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

  /// Show server configuration dialog for physical devices
  void _showServerConfigDialog() {
    final TextEditingController serverUrlController = TextEditingController(
      text: BackendServerManager.customServerUrl ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.dns_outlined, color: Color(0xFF2C6E91)),
              SizedBox(width: 12),
              Text(
                'Server Configuration',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFFF59E0B), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          Platform.isAndroid || Platform.isIOS
                              ? 'For physical devices only'
                              : 'Optional: Override auto-detected URL',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Current Configuration:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    BackendServerManager.getServerUrl(),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Custom Server URL:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: serverUrlController,
                  decoration: InputDecoration(
                    hintText: 'http://192.168.1.100:8000',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF2C6E91), width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear, size: 20),
                      onPressed: () {
                        serverUrlController.clear();
                      },
                    ),
                  ),
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF2C6E91).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Color(0xFF2C6E91), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Setup Instructions:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      _buildInstructionStep('1', 'Find your computer\'s IP address:\n   Windows: cmd → ipconfig → IPv4 Address\n   Example: 192.168.1.100'),
                      SizedBox(height: 6),
                      _buildInstructionStep('2', 'Ensure phone and computer are on the same Wi-Fi network'),
                      SizedBox(height: 6),
                      _buildInstructionStep('3', 'Make sure backend server is running on your computer'),
                      SizedBox(height: 6),
                      _buildInstructionStep('4', 'Enter URL as: http://YOUR_IP:8000'),
                      SizedBox(height: 6),
                      _buildInstructionStep('5', 'Test in phone browser: http://YOUR_IP:8000/health'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                BackendServerManager.customServerUrl = null;
                setState(() {});
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reset to auto-detect: ${BackendServerManager.getServerUrl()}'),
                    backgroundColor: Color(0xFF2C6E91),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text(
                'Reset',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                String url = serverUrlController.text.trim();
                if (url.isEmpty) {
                  BackendServerManager.customServerUrl = null;
                  setState(() {});
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Using auto-detect: ${BackendServerManager.getServerUrl()}'),
                      backgroundColor: Color(0xFF2C6E91),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                // Validate URL format
                if (!url.startsWith('http://') && !url.startsWith('https://')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('URL must start with http:// or https://'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                // Remove trailing slash
                if (url.endsWith('/')) {
                  url = url.substring(0, url.length - 1);
                }

                // Set the custom URL
                BackendServerManager.customServerUrl = url;

                // Test connection
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Testing connection to $url...'),
                      ],
                    ),
                    backgroundColor: Color(0xFF2C6E91),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 5),
                  ),
                );

                final isHealthy = await BackendServerManager.isServerHealthy();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                if (isHealthy) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('✓ Connected successfully!\nServer: $url')),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '✗ Cannot connect to server\n\nMake sure:\n• Server is running on your computer\n• Both devices are on same Wi-Fi\n• Firewall allows port 8000\n• URL is correct',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 6),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2C6E91),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Save & Test',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Color(0xFF2C6E91),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF1E3A8A),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
