class VerificationResult {
  final bool isAuthentic;
  final double matchScore;
  final String? matchedFingerprintId;
  final String? message;
  final Map<String, dynamic>? details;

  VerificationResult({
    required this.isAuthentic,
    required this.matchScore,
    this.matchedFingerprintId,
    this.message,
    this.details,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      isAuthentic: json['is_authentic'] ?? false,
      matchScore: (json['match_score'] ?? 0.0).toDouble(),
      matchedFingerprintId: json['matched_fingerprint_id'],
      message: json['message'],
      details: json['details'],
    );
  }

  String get matchScorePercent => '${(matchScore * 100).toStringAsFixed(1)}%';
}
