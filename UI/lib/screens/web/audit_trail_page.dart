import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';

class AuditTrailPage extends StatelessWidget {
  const AuditTrailPage({super.key});

  List<AuditLog> _getMockAuditLogs() {
    return [
      AuditLog(
        id: '1',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        userId: '1',
        userName: 'John Inspector',
        action: 'Submitted verification request',
        result: 'Verified - Gold sample from Site A',
      ),
      AuditLog(
        id: '2',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        userId: '2',
        userName: 'Sarah Officer',
        action: 'Submitted verification request',
        result: 'Verified - Chalcopyrite sample from Site B',
      ),
      AuditLog(
        id: '3',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        userId: 'admin',
        userName: 'Admin User',
        action: 'Registered new mining site',
        result: 'Site D created successfully',
      ),
      AuditLog(
        id: '4',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        userId: '3',
        userName: 'Mike Verifier',
        action: 'Submitted verification request',
        result: 'Not Verified - Hematite sample from Site C',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final logs = _getMockAuditLogs();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      'Audit trail is an immutable log of all system activities. Records cannot be modified or deleted.',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: logs.map((log) {
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          log.userName[0],
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        log.action,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(log.result),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                log.userName,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM dd, yyyy - HH:mm').format(log.timestamp),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Chip(
                        label: Text('ID: ${log.id}'),
                        backgroundColor: Colors.grey.shade100,
                      ),
                    ),
                    if (log != logs.last) const Divider(),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
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
