class PredictionResult {
  final String predictedMineral;
  final double confidence;
  final Map<String, double> probabilities;
  final Map<String, double>? chemicalUsed;
  final String? scanId;
  final DateTime timestamp;
  final String? fingerprintId;
  final String? location;
  final bool isMineral;
  final double? gateConfidence;
  final String? rejectionReason;
  final String? oodStatus;
  final double? similarityScore;
  final bool isSameSample;
  final String? matchedSampleId;
  final String? reidStatus;

  PredictionResult({
    required this.predictedMineral,
    required this.confidence,
    required this.probabilities,
    this.chemicalUsed,
    this.scanId,
    required this.timestamp,
    this.fingerprintId,
    this.location,
    this.isMineral = true,
    this.gateConfidence,
    this.rejectionReason,
    this.oodStatus,
    this.similarityScore,
    this.isSameSample = false,
    this.matchedSampleId,
    this.reidStatus,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    double? toNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    Map<String, double> probs = {};
    if (json['probabilities'] != null) {
      (json['probabilities'] as Map<String, dynamic>).forEach((key, value) {
        final parsed = toNullableDouble(value);
        if (parsed != null) {
          probs[key] = parsed;
        }
      });
    }

    Map<String, double>? chemical;
    if (json['chemical_used'] != null) {
      final rawChemical = json['chemical_used'] as Map<String, dynamic>;
      final parsedChemical = <String, double>{};
      rawChemical.forEach((k, v) {
        final parsed = toNullableDouble(v);
        if (parsed != null) {
          parsedChemical[k] = parsed;
        }
      });
      if (parsedChemical.isNotEmpty) {
        chemical = parsedChemical;
      }
    }

    return PredictionResult(
      predictedMineral: json['predicted_mineral'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      probabilities: probs,
      chemicalUsed: chemical,
      scanId: json['scan_id'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      fingerprintId: json['fingerprint_id'],
      location: json['location'] ?? json['site_id'] ?? json['site_name'],
      isMineral: json['is_mineral'] ?? true,
      gateConfidence: toNullableDouble(json['gate_confidence']),
      rejectionReason: json['rejection_reason'],
      oodStatus: json['ood_status'],
      similarityScore: toNullableDouble(json['similarity_score']),
      isSameSample: json['is_same_sample'] ?? false,
      matchedSampleId: json['matched_sample_id'],
      reidStatus: json['reid_status'],
    );
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
  String get gateConfidencePercent => '${((gateConfidence ?? 0.0) * 100).toStringAsFixed(1)}%';
  String get similarityPercent => '${((similarityScore ?? 0.0) * 100).toStringAsFixed(1)}%';
}
