import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';

class DebugStorageScreen extends StatefulWidget {
  const DebugStorageScreen({super.key});

  @override
  State<DebugStorageScreen> createState() => _DebugStorageScreenState();
}

class _DebugStorageScreenState extends State<DebugStorageScreen> {
  String _storageKey = 'plocket_db';
  String _rawData = '';
  int _dataSize = 0;
  Map<String, dynamic>? _parsedData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      
      setState(() {
        _rawData = data ?? '';
        _dataSize = _rawData.length;
        
        if (_rawData.isNotEmpty) {
          try {
            _parsedData = jsonDecode(_rawData);
          } catch (e) {
            _parsedData = null;
          }
        } else {
          _parsedData = null;
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await _loadStorageData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Storage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStorageData,
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Effacer le stockage ?'),
                  content: const Text('Cette action supprimera toutes les données stockées dans localStorage.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Effacer'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                await _clearStorage();
              }
            },
            tooltip: 'Effacer le stockage',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informations générales
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Informations', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.md),
                        _buildInfoRow('Clé de stockage', _storageKey),
                        _buildInfoRow('Taille des données', '${_dataSize} octets'),
                        _buildInfoRow('Données présentes', _rawData.isNotEmpty ? 'Oui' : 'Non'),
                        _buildInfoRow('Données valides', _parsedData != null ? 'Oui' : 'Non'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Statistiques par table
                  if (_parsedData != null) ...[
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Statistiques par table', style: theme.textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.md),
                          ...(_parsedData!.entries.map((entry) {
                            final tableName = entry.key;
                            final rows = entry.value as List;
                            return _buildInfoRow(tableName, '${rows.length} ligne(s)');
                          })),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  
                  // Données brutes
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Données brutes', style: theme.textTheme.titleMedium),
                            const Spacer(),
                            if (_rawData.isNotEmpty)
                              TextButton.icon(
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copier'),
                                onPressed: () {
                                  // Copier dans le presse-papier
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            _rawData.isEmpty ? '(vide)' : _rawData,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Instructions de test
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Instructions de test', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.md),
                        const Text('1. Créez une fiche'),
                        const Text('2. Rafraîchissez cette page (F5)'),
                        const Text('3. Vérifiez que les données sont toujours présentes'),
                        const Text('4. Fermez complètement le navigateur'),
                        const Text('5. Réouvrez l\'application'),
                        const Text('6. Vérifiez que les données sont toujours présentes'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
