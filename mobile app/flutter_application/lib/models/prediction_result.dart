class PredictionResult {
  final String predictedMineral;
  final double confidence;
  final Map<String, double> probabilities;
  final String? scanId;
  final DateTime timestamp;
  final String? fingerprintId;

  PredictionResult({
    required this.predictedMineral,
    required this.confidence,
    required this.probabilities,
    this.scanId,
    required this.timestamp,
    this.fingerprintId,
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
      scanId: json['scan_id'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      fingerprintId: json['fingerprint_id'],
    );
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}
