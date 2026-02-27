import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../models/prediction_result.dart';
import '../../services/storage_service.dart';
import 'scan_result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _apiService = ApiService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();

  static const List<_KnownPlace> _knownPlaces = [
    _KnownPlace(
      name: 'African Leadership University',
      latitude: -1.9439,
      longitude: 30.0928,
      radiusMeters: 3000,
    ),
    _KnownPlace(
      name: 'Kagarama',
      latitude: -1.9958,
      longitude: 30.1174,
      radiusMeters: 2500,
    ),
  ];
  
  File? _imageFile;
  File? _audioFile;
  String? _detectedLocation;
  Position? _currentPosition;
  bool _isScanning = false;
  bool _isLoadingLocation = false;

  String? _resolveKnownPlaceByCoordinates(Position position) {
    for (final place in _knownPlaces) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        place.latitude,
        place.longitude,
      );

      if (distance <= place.radiusMeters) {
        return place.name;
      }
    }
    return null;
  }

  String? _resolveKnownPlaceByText(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.contains('african leadership university') ||
        normalized.contains('kigali innovation city')) {
      return 'African Leadership University';
    }

    if (normalized.contains('kagarama')) {
      return 'Kagarama';
    }

    return null;
  }

  String _friendlyLocationFromPlacemark(Placemark place) {
    final knownFromText = _resolveKnownPlaceByText(
      [
        place.name,
        place.street,
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
      ].where((v) => (v ?? '').trim().isNotEmpty).join(', '),
    );

    if (knownFromText != null) {
      return knownFromText;
    }

    if ((place.subLocality ?? '').trim().isNotEmpty) {
      return place.subLocality!.trim();
    }

    if ((place.locality ?? '').trim().isNotEmpty) {
      return place.locality!.trim();
    }

    if ((place.subAdministrativeArea ?? '').trim().isNotEmpty) {
      return place.subAdministrativeArea!.trim();
    }

    if ((place.administrativeArea ?? '').trim().isNotEmpty) {
      return place.administrativeArea!.trim();
    }

    return 'Unknown Location';
  }

  String _friendlyLocationFromApiText(String value) {
    final knownFromText = _resolveKnownPlaceByText(value);
    if (knownFromText != null) {
      return knownFromText;
    }

    final chunks = value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (chunks.isEmpty) {
      return 'Unknown Location';
    }

    return chunks.first;
  }

  String _formatCoordinates(Position position) {
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }

  Future<String?> _resolveLocationNameFromMapApi(Position position) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2'
        '&lat=${position.latitude}'
        '&lon=${position.longitude}'
        '&zoom=14',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'MineralTrace/1.0 (admin@mineraltrace.local)'
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = (data['address'] as Map<String, dynamic>?) ?? {};

      final locality =
          (address['city'] ?? address['town'] ?? address['village'] ?? address['suburb'] ?? address['county'])?.toString();
      final region = (address['state'] ?? address['region'])?.toString();
      final country = address['country']?.toString();

      final parts = <String>[
        if ((locality ?? '').trim().isNotEmpty) locality!.trim(),
        if ((region ?? '').trim().isNotEmpty) region!.trim(),
        if ((country ?? '').trim().isNotEmpty) country!.trim(),
      ];

      if (parts.isNotEmpty) {
        return parts.join(', ');
      }

      final displayName = data['display_name']?.toString();
      if ((displayName ?? '').trim().isNotEmpty) {
        return displayName!.trim();
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String> _resolveLocationName(Position position) async {
    final knownByCoordinates = _resolveKnownPlaceByCoordinates(position);
    if (knownByCoordinates != null) {
      return knownByCoordinates;
    }

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        final fromApi = await _resolveLocationNameFromMapApi(position);
        if (fromApi != null && fromApi.trim().isNotEmpty) {
          return _friendlyLocationFromApiText(fromApi);
        }
        return _formatCoordinates(position);
      }

      final place = placemarks.first;
      final friendly = _friendlyLocationFromPlacemark(place);
      if (friendly != 'Unknown Location') {
        return friendly;
      }

      final fromApi = await _resolveLocationNameFromMapApi(position);
      if (fromApi != null) {
        return _friendlyLocationFromApiText(fromApi);
      }

      return _formatCoordinates(position);
    } catch (_) {
      final fromApi = await _resolveLocationNameFromMapApi(position);
      if (fromApi != null) {
        return _friendlyLocationFromApiText(fromApi);
      }

      return _formatCoordinates(position);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled. Please enable them.');
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions are permanently denied');
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final locationName = await _resolveLocationName(position);

      setState(() {
        _currentPosition = position;
        _detectedLocation = locationName;
        _isLoadingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location detected successfully'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      _showError('Failed to get location: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        
        // Automatically detect location after image capture
        await _getCurrentLocation();
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _performScan() async {
    if (_imageFile == null && _audioFile == null) {
      _showError('Please provide at least one input (image or audio)');
      return;
    }

    setState(() => _isScanning = true);

    try {
      final userId = _storageService.getUserId();
      final userName = _storageService.getUserName() ?? 'Unknown';

      // Step 1: Predict mineral type
      final result = await _apiService.predict(
        imageFile: _imageFile,
        audioFile: _audioFile,
        chemicalData: null,
        siteId: _detectedLocation,
        userId: userId,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );

      // Generate scan ID if not already present
      String scanId = result.scanId ?? 'scan_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(900000)}';

      // Step 2: Extract and store fingerprint with predicted mineral
      try {
        final fingerprintResponse = await _apiService.extractFingerprint(
          sampleId: scanId,
          site: _detectedLocation ?? 'Unknown',
          mineral: result.predictedMineral,
          userId: userId ?? '',
          userName: userName,
          imageFile: _imageFile,
          audioFile: _audioFile,
          chemicalUsed: result.chemicalUsed,
          latitude: _currentPosition?.latitude,
          longitude: _currentPosition?.longitude,
        );

        // Use the returned sample_id as fingerprint ID
        final fingerprintId = fingerprintResponse['sample_id'] ?? scanId;
        final resultWithFingerprint = PredictionResult(
          predictedMineral: result.predictedMineral,
          confidence: result.confidence,
          probabilities: result.probabilities,
          chemicalUsed: result.chemicalUsed,
          scanId: scanId,
          timestamp: result.timestamp,
          fingerprintId: fingerprintId,
          location: _detectedLocation,
        );

        // Persist scan ID locally
        try {
          await _storageService.addScanId(scanId);
        } catch (_) {}

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ScanResultScreen(result: resultWithFingerprint),
            ),
          );
        }
      } catch (fpError) {
        // If fingerprint storage fails, still show results but warn user
        _showError('Warning: Fingerprint storage failed. Verification may not work.');
        
        final resultWithId = PredictionResult(
          predictedMineral: result.predictedMineral,
          confidence: result.confidence,
          probabilities: result.probabilities,
          chemicalUsed: result.chemicalUsed,
          scanId: scanId,
          timestamp: result.timestamp,
          fingerprintId: null,
          location: _detectedLocation,
        );

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ScanResultScreen(result: resultWithId),
            ),
          );
        }
      }
    } catch (e) {
      _showError('Scan failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Scan Mineral'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mineral Image',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_imageFile != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _imageFile!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                              onPressed: () {
                                setState(() => _imageFile = null);
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Camera'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryColor,
                                side: const BorderSide(color: AppTheme.primaryColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Audio Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Audio Sample (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement audio recording
                        _showError('Audio recording coming soon');
                      },
                      icon: Icon(_audioFile != null ? Icons.check_circle : Icons.mic_outlined),
                      label: Text(_audioFile != null ? 'Audio Recorded' : 'Record Audio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _audioFile != null ? AppTheme.successColor : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Location Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GPS Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Location is automatically detected after capturing image',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_detectedLocation != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.successColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: AppTheme.successColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _detectedLocation!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              color: AppTheme.successColor,
                              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                        icon: _isLoadingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(_isLoadingLocation ? 'Detecting...' : 'Detect Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info card about automatic chemical analysis
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Automatic Chemical Analysis',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'The system will automatically analyze chemical composition from XRF data',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Scan Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _performScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: _isScanning
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'SCANNING...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'SCAN MINERAL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnownPlace {
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const _KnownPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
}
