import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/card_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'verification_screen.dart';

class DictationScreen extends StatefulWidget {
  const DictationScreen({super.key});

  @override
  State<DictationScreen> createState() => _DictationScreenState();
}

class _DictationScreenState extends State<DictationScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();
  bool _isListening = false;
  bool _isProcessing = false;
  bool _hasMicPermission = false;
  double _confidence = 0;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize();
    if (!mounted) return;
    setState(() => _hasMicPermission = available);
    
    if (available) {
      _listen();
    }
  }

  Future<void> _listen() async {
    if (!_hasMicPermission) {
      final available = await _speech.initialize();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission microphone refusée')),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() => _hasMicPermission = true);
    }

    if (!mounted) return;
    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _textController.text = result.recognizedWords;
          _confidence = result.confidence;
        });
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  Future<void> _processDictation() async {
    if (_isListening) {
      await _stopListening();
    }
    
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (!mounted) return;
    setState(() => _isProcessing = true);

    final draft = await context.read<CardProvider>().analyzeText(text);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (mounted) {
      if (draft != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationScreen(draft: draft),
          ),
        );
      } else {
        final err = context.read<CardProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Erreur lors de l\'analyse')),
        );
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _speech.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dicter'),
      ),
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening
                            ? AppColors.accentRed.withValues(alpha: 0.15)
                            : AppColors.primaryBlue.withValues(alpha: 0.1),
                        border: Border.all(
                          color: _isListening ? AppColors.accentRed : AppColors.primaryBlue,
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          size: 48,
                          color: _isListening ? AppColors.accentRed : AppColors.primaryBlue,
                        ),
                        onPressed: _isListening ? _stopListening : _listen,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _isListening
                          ? 'Écoute en cours... Parlez maintenant'
                          : _textController.text.isEmpty
                              ? 'Appuyez sur le micro pour reprendre'
                              : 'Dictée en pause — Modifiez ou enregistrez',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_isListening)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          'Confiance : ${(_confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    TextField(
                      controller: _textController,
                      maxLines: 12,
                      decoration: InputDecoration(
                        hintText: 'Le texte dicté apparaîtra ici...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(AppSpacing.lg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.lg),
                child: CircularProgressIndicator(),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _textController.text.trim().isEmpty
                      ? null
                      : _processDictation,
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text('Analyser et enregistrer'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              if (!_hasMicPermission)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Permission micro requise pour dicter',
                    style: TextStyle(fontSize: 12, color: AppColors.accentRed),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
