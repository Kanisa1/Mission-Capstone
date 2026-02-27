class PredictionResult {
  final String predictedMineral;
  final double confidence;
  final Map<String, double> probabilities;
  final Map<String, double>? chemicalUsed;
  final String? scanId;
  final DateTime timestamp;
  final String? fingerprintId;
  final String? location;

  PredictionResult({
    required this.predictedMineral,
    required this.confidence,
    required this.probabilities,
    this.chemicalUsed,
    this.scanId,
    required this.timestamp,
    this.fingerprintId,
    this.location,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    Map<String, double> probs = {};
    if (json['probabilities'] != null) {
      (json['probabilities'] as Map<String, dynamic>).forEach((key, value) {
        probs[key] = (value as num).toDouble();
      });
    }

    return PredictionResult(
      predictedMineral: json['predicted_mineral'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      probabilities: probs,
      chemicalUsed: json['chemical_used'] != null
          ? (json['chemical_used'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()))
          : null,
      scanId: json['scan_id'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      fingerprintId: json['fingerprint_id'],
      location: json['location'] ?? json['site_id'] ?? json['site_name'],
    );
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}
