import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ocr_service.dart';
import '../services/document_scanner_service.dart';
import '../services/ocr_quality_scorer.dart';
import '../providers/card_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';

class OcrDebugScreen extends StatefulWidget {
  final Uint8List originalBytes;
  final String fileName;

  const OcrDebugScreen({
    super.key,
    required this.originalBytes,
    required this.fileName,
  });

  @override
  State<OcrDebugScreen> createState() => _OcrDebugScreenState();
}

class _OcrDebugScreenState extends State<OcrDebugScreen> {
  Uint8List? _preprocessedBytes;
  String _ocrRawText = '';
  OcrQualityResult? _qualityResult;
  Map<String, dynamic>? _extractedFields;
  bool _isProcessing = false;
  String _statusText = '';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _runPipeline());
  }

  void _log(String msg) {
    setState(() => _logs.add('${DateTime.now().toIso8601String().substring(11, 23)} $msg'));
  }

  Future<void> _runPipeline() async {
    setState(() {
      _isProcessing = true;
      _statusText = 'Étape 1/4 : Prétraitement...';
    });

    _log('Début pipeline debug');
    _log('Image originale: ${widget.originalBytes.length} octets');

    final scanner = DocumentScannerService();
    final sw = Stopwatch()..start();
    _preprocessedBytes = await scanner.preprocessImage(widget.originalBytes);
    _log('Prétraitement terminé en ${sw.elapsedMilliseconds}ms');
    _log('Image prétraitée: ${_preprocessedBytes!.length} octets');

    setState(() => _statusText = 'Étape 2/4 : OCR...');

    final ocr = OcrService();
    sw.reset();
    if (kIsWeb) {
      _ocrRawText = await ocr.extractTextFromImageBytes(_preprocessedBytes!);
    } else {
      _ocrRawText = await ocr.extractTextFromImageBytesNative(_preprocessedBytes!);
    }
    _log('OCR terminé en ${sw.elapsedMilliseconds}ms');
    _log('Texte OCR: ${_ocrRawText.length} caractères');

    setState(() => _statusText = 'Étape 3/4 : Contrôle qualité...');

    _qualityResult = OcrQualityScorer.analyze(_ocrRawText);
    _log('Qualité OCR: ${_qualityResult!.score}/100 (${_qualityResult!.level})');
    for (final w in _qualityResult!.warnings) {
      _log('  ⚠ $w');
    }

    setState(() => _statusText = 'Étape 4/4 : Extraction des champs...');

    final cardProvider = context.read<CardProvider>();
    final draft = await cardProvider.analyzeDocument(
      title: 'Debug - ${widget.fileName}',
      ocrText: _ocrRawText,
      filePath: null,
      mimeType: 'image/jpeg',
      sourceFileName: widget.fileName,
      sourceFileExtension: 'jpg',
      sourceBytes: widget.originalBytes,
    );

    if (draft != null) {
      _extractedFields = {};
      for (final entry in draft.fields.entries) {
        _extractedFields![entry.key] = entry.value.rawValue;
        _log('  ${entry.key} = ${entry.value.rawValue}');
      }
      _log('Extraction: ${draft.fields.length} champ(s)');
    } else {
      _log('Extraction: ÉCHEC');
    }

    setState(() {
      _isProcessing = false;
      _statusText = 'Terminé';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Debug OCR Pipeline')),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(_statusText, style: theme.textTheme.bodyMedium),
                ],
              ),
            )
          : ListView(
              padding: AppSpacing.screenPadding,
              children: [
                GlassSectionHeader(title: '1. Image originale'),
                const SizedBox(height: AppSpacing.sm),
                GlassCard(
                  child: Column(
                    children: [
                      Image.memory(
                        widget.originalBytes,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${widget.originalBytes.length} octets',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                GlassSectionHeader(title: '2. Image prétraitée'),
                const SizedBox(height: AppSpacing.sm),
                GlassCard(
                  child: Column(
                    children: [
                      if (_preprocessedBytes != null)
                        Image.memory(
                          _preprocessedBytes!,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${_preprocessedBytes?.length ?? 0} octets',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                GlassSectionHeader(title: '3. Texte OCR brut'),
                const SizedBox(height: AppSpacing.sm),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Moteur: ${kIsWeb ? "Tesseract.js v5 (fra)" : "Google ML Kit (Latin)"}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textTertiary)),
                          const Spacer(),
                          Text('${_ocrRawText.length} car.',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textTertiary)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: SelectableText(
                          _ocrRawText.isEmpty
                              ? '(aucun texte extrait)'
                              : _ocrRawText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: _ocrRawText.isEmpty
                                ? AppColors.accentRed
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                GlassSectionHeader(title: '4. Contrôle qualité'),
                const SizedBox(height: AppSpacing.sm),
                if (_qualityResult != null)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _qualityResult!.score >= 60
                                  ? Icons.check_circle
                                  : _qualityResult!.score >= 40
                                      ? Icons.warning
                                      : Icons.error,
                              color: _qualityResult!.score >= 60
                                  ? AppColors.accentGreen
                                  : _qualityResult!.score >= 40
                                      ? AppColors.accentOrange
                                      : AppColors.accentRed,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Score: ${_qualityResult!.score.toInt()}/100 (${_qualityResult!.level})',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: _qualityResult!.score >= 60
                                    ? AppColors.accentGreen
                                    : _qualityResult!.score >= 40
                                        ? AppColors.accentOrange
                                        : AppColors.accentRed,
                              ),
                            ),
                          ],
                        ),
                        if (_qualityResult!.warnings.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          ..._qualityResult!.warnings.map((w) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '⚠ $w',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.accentOrange),
                                ),
                              )),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.md,
                          children: _qualityResult!.metrics.entries.map((e) {
                            return Text(
                              '${e.key}: ${e.value}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 10),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xxl),

                GlassSectionHeader(title: '5. Champs extraits'),
                const SizedBox(height: AppSpacing.sm),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_extractedFields == null ||
                          _extractedFields!.isEmpty)
                        Text('Aucun champ extrait',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.accentRed))
                      else
                        ..._extractedFields!.entries.map((e) {
                          final value = e.value?.toString() ?? '';
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: Text(
                                    e.key,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    value.isEmpty ? '(vide)' : value,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: value.isEmpty
                                          ? AppColors.textTertiary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                GlassSectionHeader(title: 'Logs pipeline'),
                const SizedBox(height: AppSpacing.sm),
                GlassCard(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: SelectableText(
                      _logs.join('\n'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
