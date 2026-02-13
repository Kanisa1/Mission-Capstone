import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../models/verification_record.dart';

class MiningSitesMineralsPage extends StatefulWidget {
  const MiningSitesMineralsPage({super.key});

  @override
  State<MiningSitesMineralsPage> createState() => _MiningSitesMineralsPageState();
}

class _MiningSitesMineralsPageState extends State<MiningSitesMineralsPage> {
  List<MiningSite> _getMiningSites() {
    return [
      MiningSite(
        id: 'A',
        name: 'Site A',
        location: 'Central Equatoria',
        minerals: [MineralType.gold, MineralType.hematite],
      ),
      MiningSite(
        id: 'B',
        name: 'Site B',
        location: 'Kapoeta East',
        minerals: [MineralType.chalcopyrite],
      ),
      MiningSite(
        id: 'C',
        name: 'Site C',
        location: 'Yei River',
        minerals: [MineralType.gold, MineralType.chalcopyrite, MineralType.hematite],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sites = _getMiningSites();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.business, size: 48, color: AppColors.primary),
                        const SizedBox(height: 12),
                        Text(
                          '${sites.length}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const Text('Registered Sites'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.diamond, size: 48, color: AppColors.accent),
                        const SizedBox(height: 12),
                        Text(
                          '${MineralType.values.length}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                        const Text('Mineral Types'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mining Sites',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _showAddSiteDialog(context);
                },
                icon: const Icon(Icons.add),
                label: const Text('Register Site'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sites.map((site) => _buildSiteCard(site)),
        ],
      ),
    );
  }

  Widget _buildSiteCard(MiningSite site) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            site.location,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Minerals:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: site.minerals.map((mineral) {
                return Chip(
                  label: Text(_getMineralName(mineral)),
                  backgroundColor: AppColors.accent.withOpacity(0.1),
                  labelStyle: const TextStyle(color: AppColors.textPrimary),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSiteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register Mining Site'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Site Name'),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(labelText: 'Location'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Site registered (mock)')),
              );
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  String _getMineralName(MineralType type) {
    switch (type) {
      case MineralType.chalcopyrite:
        return 'Chalcopyrite';
      case MineralType.gold:
        return 'Gold';
      case MineralType.hematite:
        return 'Hematite';
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
