import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';

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

    Future.delayed(const Duration(seconds: 1), () {
      _animationController.forward().then((_) {
        setState(() {
          _isLoading = false;
        });
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _gestationController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
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

      if (mounted) {
        setState(() {
          _isRecording = false;
          _audioFilePath = path;
          _audioFileName =
              path?.split('/').last.split('\\').last ?? 'recording.wav';
          _recordingDuration = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording stopped successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
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
    if (_audioFilePath == null) return;

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
              content: Text('Download cancelled'),
              backgroundColor: Colors.grey,
            ),
          );
        }
        return;
      }

      // Copy file to selected directory
      final sourceFile = File(_audioFilePath!);
      if (!await sourceFile.exists()) {
        throw Exception('Source file not found');
      }

      final newPath = '$selectedDirectory${Platform.pathSeparator}$fileName';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Row(
                                                      children: [
                                                        Icon(
                                                          Icons.check_circle,
                                                          color: Color(
                                                            0xFF10B981,
                                                          ),
                                                          size: 28,
                                                        ),
                                                        SizedBox(width: 12),
                                                        Text(
                                                          'Audio Ready',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    content: Text(
                                                      'Audio file prepared successfully!\n\n'
                                                      'Gestation Period: $_gestationPeriod\n'
                                                      'File: ${_audioFileName ?? "recording"}',
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
                                                        child: const Text('OK'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.analytics_outlined,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                "Analyze",
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
                            "https://media.istockphoto.com/id/1410084181/vector/pregnant-woman-silhouette-continuous-line.jpg?s=612x612&w=0&k=20&c=v_tPP5Av4wm6oz84LRRdK0C9lM6WGKox3_3AlTfTkhQ=",
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
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
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
