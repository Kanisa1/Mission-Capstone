class Scan {
  final String scanId;
  final String mineral;
  final double confidence;
  final String location;
  final DateTime timestamp;
  final String userId;
  final bool verified;
  final Map<String, dynamic>? fingerprint;
  final String? imageUrl;
  final String? audioUrl;

  Scan({
    required this.scanId,
    required this.mineral,
    required this.confidence,
    required this.location,
    required this.timestamp,
    required this.userId,
    this.verified = false,
    this.fingerprint,
    this.imageUrl,
    this.audioUrl,
  });

  factory Scan.fromJson(Map<String, dynamic> json) {
    return Scan(
      scanId: json['scan_id'] ?? '',
      mineral: json['mineral'] ?? json['predicted_mineral'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      location: json['location'] ?? json['site_id'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      userId: json['user_id'] ?? '',
      verified: json['verified'] ?? false,
      fingerprint: json['fingerprint'],
      imageUrl: json['image_url'],
      audioUrl: json['audio_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scan_id': scanId,
      'mineral': mineral,
      'confidence': confidence,
      'location': location,
      'timestamp': timestamp.toIso8601String(),
      'user_id': userId,
      'verified': verified,
      'fingerprint': fingerprint,
      'image_url': imageUrl,
      'audio_url': audioUrl,
    };
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}
