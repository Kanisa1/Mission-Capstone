import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/prediction_result.dart';
import '../../services/api_service.dart';
import 'verification_result_screen.dart';

class ScanResultScreen extends StatelessWidget {
  final PredictionResult result;

  const ScanResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final mineralColor = Color(
      AppConstants.mineralColors[result.predictedMineral.toLowerCase()] ?? 0xFFCCCCCC,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Scan Result'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // TODO: Implement share
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Animation Container
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 80,
                        color: AppTheme.successColor,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Identification Complete',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Mineral Name
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: mineralColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: mineralColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        result.predictedMineral.toUpperCase(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: mineralColor,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Confidence
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.analytics_outlined,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Confidence: ${result.confidencePercent}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Probabilities
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
                      'Mineral Probabilities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ...result.probabilities.entries.map((entry) {
                      final percentage = (entry.value * 100);
                      final color = Color(
                        AppConstants.mineralColors[entry.key.toLowerCase()] ?? 0xFFCCCCCC,
                      );
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: entry.value,
                                backgroundColor: AppTheme.backgroundColor,
                                color: color,
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Details
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
                      'Scan Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDetailRow('Scan ID', result.scanId ?? 'N/A'),
                    _buildDetailRow(
                      'Timestamp',
                      DateFormat('MMM dd, yyyy • HH:mm:ss').format(result.timestamp),
                    ),
                    if (result.location != null && result.location!.trim().isNotEmpty)
                      _buildDetailRow('Location', result.location!),
                    if (result.fingerprintId != null)
                      _buildDetailRow('Fingerprint ID', result.fingerprintId!),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Chemical composition used
              if (result.chemicalUsed != null)
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
                        'Chemical Composition Used',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...['Au', 'Cu', 'Fe', 'S', 'O'].map((el) {
                        final val = result.chemicalUsed![el];
                        return _buildDetailRow(el, val != null ? val.toString() : 'N/A');
                      }).toList(),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('New Scan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Show progress dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const AlertDialog(
                            content: SizedBox(
                              height: 60,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),
                        );

                        try {
                          final api = ApiService();

                          // Prepare chemical data in expected order [Au, Cu, Fe, S, O]
                          List<double>? chemicalList;
                          if (result.chemicalUsed != null) {
                            chemicalList = [
                              result.chemicalUsed!['Au'] ?? 0.0,
                              result.chemicalUsed!['Cu'] ?? 0.0,
                              result.chemicalUsed!['Fe'] ?? 0.0,
                              result.chemicalUsed!['S'] ?? 0.0,
                              result.chemicalUsed!['O'] ?? 0.0,
                            ];
                          }

                          if ((result.fingerprintId == null || result.fingerprintId!.isEmpty) && chemicalList == null) {
                            Navigator.of(context).pop();
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Verification'),
                                content: const Text('No verification data available'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                                ],
                              ),
                            );
                            return;
                          }

                          final verification = await api.verify(
                            fingerprintId: result.fingerprintId,
                            chemicalData: chemicalList,
                          );

                          Navigator.of(context).pop(); // remove progress

                          // Navigate to dedicated verification result screen
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => VerificationResultScreen(
                                verification: verification,
                                prediction: result,
                              ),
                            ),
                          );
                        } catch (e) {
                          Navigator.of(context).pop();
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Verification Error'),
                              content: Text(e.toString()),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                              ],
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Verify'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
