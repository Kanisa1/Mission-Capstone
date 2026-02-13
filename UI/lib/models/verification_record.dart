enum VerificationStatus {
  verified,
  notVerified,
  pending,
}

enum MineralType {
  chalcopyrite,
  gold,
  hematite,
}

class VerificationRecord {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String userName;
  final MineralType mineralType;
  final String location;
  final String miningSite;
  final VerificationStatus status;
  final double confidenceScore;
  final String? imagePath;
  final String? notes;

  VerificationRecord({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userName,
    required this.mineralType,
    required this.location,
    required this.miningSite,
    required this.status,
    required this.confidenceScore,
    this.imagePath,
    this.notes,
  });

  String get mineralName {
    switch (mineralType) {
      case MineralType.chalcopyrite:
        return 'Chalcopyrite';
      case MineralType.gold:
        return 'Gold';
      case MineralType.hematite:
        return 'Hematite';
    }
  }

  String get statusText {
    switch (status) {
      case VerificationStatus.verified:
        return 'Verified';
      case VerificationStatus.notVerified:
        return 'Not Verified';
      case VerificationStatus.pending:
        return 'Pending';
    }
  }
}

class MiningSite {
  final String id;
  final String name;
  final String location;
  final List<MineralType> minerals;

  MiningSite({
    required this.id,
    required this.name,
    required this.location,
    required this.minerals,
  });
}

class AuditLog {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String userName;
  final String action;
  final String result;

  AuditLog({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userName,
    required this.action,
    required this.result,
  });
}
