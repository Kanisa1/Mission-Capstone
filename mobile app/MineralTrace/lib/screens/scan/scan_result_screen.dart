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
    final isMineral = result.isMineral;
    final mineralColor = Color(
      isMineral
          ? (AppConstants.mineralColors[result.predictedMineral.toLowerCase()] ?? 0xFFCCCCCC)
          : AppTheme.errorColor.value,
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
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.04),
                      blurRadius: 44,
                      offset: const Offset(0, 20),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: (isMineral ? AppTheme.successColor : AppTheme.errorColor).withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isMineral ? AppTheme.successColor : AppTheme.errorColor).withOpacity(0.25),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isMineral ? Icons.check_circle : Icons.warning_amber_rounded,
                        size: 80,
                        color: isMineral ? AppTheme.successColor : AppTheme.errorColor,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      isMineral ? 'Identification Complete' : 'Non-Mineral Detected',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Mineral Name
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            mineralColor.withOpacity(0.12),
                            mineralColor.withOpacity(0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: mineralColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isMineral
                            ? result.predictedMineral.toUpperCase()
                            : 'NOT A MINERAL SAMPLE',
                        style: TextStyle(
                          fontSize: isMineral ? 28 : 18,
                          fontWeight: FontWeight.w800,
                          color: mineralColor,
                          letterSpacing: -0.3,
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
                          isMineral
                              ? 'Confidence: ${result.confidencePercent}'
                              : 'Gate confidence: ${result.gateConfidencePercent}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (!isMineral && (result.rejectionReason ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        result.rejectionReason!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              
              if (result.probabilities.isNotEmpty) ...[
                const SizedBox(height: 24),
              
                // Probabilities
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.03),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMineral ? 'Mineral Probabilities' : 'Mineral Likelihoods',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      
                      ...result.probabilities.entries.map((entry) {
                        final percentage = (entry.value * 100);
                        final color = Color(
                          AppConstants.mineralColors[entry.key.toLowerCase()] ?? 0xFFCCCCCC,
                        );
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
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
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: entry.value,
                                  backgroundColor: AppTheme.backgroundColor,
                                  color: color,
                                  minHeight: 10,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Details
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.03),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                      spreadRadius: 0,
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
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    
                    _buildDetailRow('Scan ID', result.scanId ?? 'N/A'),
                    _buildDetailRow(
                      'Timestamp',
                      DateFormat('MMM dd, yyyy • HH:mm:ss').format(result.timestamp),
                    ),
                    _buildDetailRow('Mineral Gate', result.isMineral ? 'Passed' : 'Rejected'),
                    if ((result.oodStatus ?? '').isNotEmpty)
                      _buildDetailRow('OOD Status', result.oodStatus!),
                    if (result.similarityScore != null)
                      _buildDetailRow('Similarity Score', result.similarityPercent),
                    if (result.isMineral)
                      _buildDetailRow('Same Physical Sample', result.isSameSample ? 'Yes' : 'No'),
                    if ((result.reidStatus ?? '').isNotEmpty)
                      _buildDetailRow('Re-ID Status', result.reidStatus!),
                    if ((result.matchedSampleId ?? '').isNotEmpty)
                      _buildDetailRow('Matched Sample', result.matchedSampleId!),
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
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.03),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                        spreadRadius: 0,
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
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                      onPressed: !result.isMineral ? null : () async {
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
                          final done = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (context) => VerificationResultScreen(
                                verification: verification,
                                prediction: result,
                              ),
                            ),
                          );

                          if (done == true && context.mounted) {
                            Navigator.of(context).pop(true);
                          }
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
