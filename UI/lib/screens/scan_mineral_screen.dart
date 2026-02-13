import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/verification_record.dart';
import '../widgets/api_form_widget.dart';
import 'verification_result_screen.dart';

class ScanMineralScreen extends StatefulWidget {
  const ScanMineralScreen({super.key});

  @override
  State<ScanMineralScreen> createState() => _ScanMineralScreenState();
}

class _ScanMineralScreenState extends State<ScanMineralScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  
  MineralType _selectedMineral = MineralType.gold;
  bool _imageAttached = false;
  bool _audioRecorded = false;

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleCaptureImage() {
    // Mock image capture - no camera integration yet
    setState(() {
      _imageAttached = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image captured (mock)'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleRecordAudio() {
    // Mock audio recording - no audio integration yet
    setState(() {
      _audioRecorded = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Acoustic signal recorded (mock)'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      if (!_imageAttached) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please capture an image first'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (!_audioRecorded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please record acoustic signal first'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Create mock verification record
      final record = VerificationRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        userId: '1',
        userName: 'Current User',
        mineralType: _selectedMineral,
        location: _locationController.text,
        miningSite: 'Site A',
        status: VerificationStatus.verified, // Mock result
        confidenceScore: 0.92, // Mock score
        notes: _notesController.text,
      );

      // Navigate to result screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VerificationResultScreen(record: record),
        ),
      );

      // Reset form
      setState(() {
        _imageAttached = false;
        _audioRecorded = false;
        _locationController.clear();
        _notesController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Scan Mineral Sample',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Capture image and acoustic signature for verification',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),

                // Mineral type selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mineral Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<MineralType>(
                          value: _selectedMineral,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: MineralType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(_getMineralName(type)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedMineral = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Image capture
                Card(
                  child: InkWell(
                    onTap: _handleCaptureImage,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            _imageAttached
                                ? Icons.check_circle
                                : Icons.camera_alt_outlined,
                            size: 48,
                            color: _imageAttached
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _imageAttached
                                ? 'Image Captured ✓'
                                : 'Capture Image',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _imageAttached
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap to capture mineral sample image',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Audio recording
                Card(
                  child: InkWell(
                    onTap: _handleRecordAudio,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            _audioRecorded
                                ? Icons.check_circle
                                : Icons.mic_outlined,
                            size: 48,
                            color: _audioRecorded
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _audioRecorded
                                ? 'Acoustic Signal Recorded ✓'
                                : 'Record Acoustic Signal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _audioRecorded
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap to record geoacoustic fingerprint',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Location metadata
                const Text(
                  'Location & Metadata',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g., Central Equatoria',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Additional observations',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),

                // Submit button
                ElevatedButton.icon(
                  onPressed: _handleSubmit,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text(
                    'Submit for Verification',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 32),
                const Text(
                  'Swagger-style API upload',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const ApiFormWidget(embedded: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMineralName(MineralType type) {
    switch (type) {
      case MineralType.chalcopyrite:
        return 'Chalcopyrite';
      case MineralType.gold:
        return 'Gold';
      case MineralType.hematite:
        return 'Hematite';
    }
  }
}
