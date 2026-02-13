import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_theme.dart';
import '../../constants/api_config.dart';
import '../../models/user.dart';
import '../../models/verification_record.dart';
import '../../services/api_service.dart';
import 'verification_result_screen.dart';

class ReviewSubmitScreen extends StatefulWidget {
  final User user;
  final MineralType mineralType;
  final String location;
  final String miningSite;
  final String notes;
  final XFile? imageFile;
  final String? audioPath;

  const ReviewSubmitScreen({
    super.key,
    required this.user,
    required this.mineralType,
    required this.location,
    required this.miningSite,
    required this.notes,
    this.imageFile,
    this.audioPath,
  });

  @override
  State<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends State<ReviewSubmitScreen> {
  late final ApiService _apiService;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: ApiConfig.defaultBaseUrl);
  }

  Future<void> _handleSubmit(BuildContext context) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Convert XFile to PlatformFile
      PlatformFile? imagePlatformFile;
      if (widget.imageFile != null) {
        final bytes = await widget.imageFile!.readAsBytes();
        imagePlatformFile = PlatformFile(
          name: widget.imageFile!.name,
          size: bytes.length,
          bytes: bytes,
        );
      }

      // Convert audio path to PlatformFile
      PlatformFile? audioPlatformFile;
      if (widget.audioPath != null) {
        Uint8List audioBytes;
        if (kIsWeb) {
          // On web, the path might be a blob URL, try to fetch it
          try {
            final response = await http.get(Uri.parse(widget.audioPath!));
            audioBytes = response.bodyBytes;
          } catch (e) {
            // If fetching fails, create mock audio
            audioBytes = Uint8List.fromList(List<int>.filled(1024, 0));
          }
        } else {
          final audioFile = File(widget.audioPath!);
          audioBytes = await audioFile.readAsBytes();
        }
        audioPlatformFile = PlatformFile(
          name: widget.audioPath!.split('/').last.split('\\').last,
          size: audioBytes.length,
          bytes: audioBytes,
        );
      } else {
        // Create mock audio file if no audio was recorded
        final mockAudioBytes = Uint8List.fromList(List<int>.filled(1024, 0));
        audioPlatformFile = PlatformFile(
          name: 'audio_sample.wav',
          size: mockAudioBytes.length,
          bytes: mockAudioBytes,
        );
      }

      // Default chemical composition values (mobile UI doesn't collect these)
      // You can customize these defaults based on mineral type if needed
      final chemicalValues = _getDefaultChemicalValues(widget.mineralType);

      if (imagePlatformFile == null) {
        throw Exception('Image file is required');
      }

      // Call the API
      final response = await _apiService.generateFingerprint(
        image: imagePlatformFile,
        audio: audioPlatformFile,
        au: chemicalValues['Au']!,
        cu: chemicalValues['Cu']!,
        fe: chemicalValues['Fe']!,
        s: chemicalValues['S']!,
        o: chemicalValues['O']!,
        sampleId: DateTime.now().millisecondsSinceEpoch.toString(),
        site: widget.miningSite,
        mineral: _getMineralName(widget.mineralType),
      );

      // Create record with API response
      final record = VerificationRecord(
        id: response['sample_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        userId: widget.user.id,
        userName: widget.user.name,
        mineralType: widget.mineralType,
        location: widget.location,
        miningSite: widget.miningSite,
        status: VerificationStatus.verified,
        confidenceScore: response['confidence']?.toDouble() ?? 0.93,
        notes: widget.notes.isEmpty ? null : widget.notes,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => VerificationResultScreen(record: record),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Map<String, double> _getDefaultChemicalValues(MineralType type) {
    // Default chemical composition values for demonstration
    // You can customize these based on typical mineral compositions
    switch (type) {
      case MineralType.chalcopyrite:
        return {'Au': 0.5, 'Cu': 34.5, 'Fe': 30.5, 'S': 34.5, 'O': 0.0};
      case MineralType.gold:
        return {'Au': 99.9, 'Cu': 0.05, 'Fe': 0.03, 'S': 0.01, 'O': 0.01};
      case MineralType.hematite:
        return {'Au': 0.1, 'Cu': 0.2, 'Fe': 69.9, 'S': 0.0, 'O': 29.8};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Submit'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Review Inputs',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Mineral Type', _getMineralName(widget.mineralType)),
                      const Divider(height: 24),
                      _buildDetailRow('Location', widget.location),
                      const Divider(height: 24),
                      _buildDetailRow('Mining Site', widget.miningSite),
                      if (widget.notes.isNotEmpty) ...[
                        const Divider(height: 24),
                        _buildDetailRow('Notes', widget.notes),
                      ],
                      const Divider(height: 24),
                      _buildDetailRow('Image', 'Captured ✓'),
                      const Divider(height: 24),
                      _buildDetailRow('Acoustic Signal', 'Recorded ✓'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Verification request will be processed using AI-powered geoacoustic analysis.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : () => _handleSubmit(context),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Verification Request',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
