import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../ai/ai_service.dart';
import '../providers/card_provider.dart';
import '../widgets/response_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'card_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  AnswerResult? _answer;
  bool _isLoading = true;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _hasMicPermission = false;
  final TextEditingController _followUpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _ask();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize();
    if (!mounted) return;
    setState(() => _hasMicPermission = available);
  }

  Future<void> _startListening() async {
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
          _followUpController.text = result.recognizedWords;
        });
        
        // Si la reconnaissance est terminée et qu'il y a du texte, lancer la recherche
        if (!result.finalResult) return;
        
        final query = result.recognizedWords.trim();
        if (query.isNotEmpty) {
          _submitFollowUpSearch(query);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune question détectée. Réessayez.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  void _submitFollowUpSearch(String query) {
    setState(() => _isLoading = true);
    context.read<CardProvider>().ask(query.trim()).then((answer) {
      if (mounted) {
        setState(() {
          _answer = answer;
          _isLoading = false;
          _followUpController.clear();
          _isListening = false;
        });
      }
    });
  }

  Future<void> _ask() async {
    setState(() => _isLoading = true);
    final answer = await context.read<CardProvider>().ask(widget.query);
    if (mounted) {
      setState(() {
        _answer = answer;
        _isLoading = false;
      });
    }
  }

  void _openSourceCard(String cardId) {
    context.read<CardProvider>().selectCard(cardId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardDetailScreen(cardId: cardId),
      ),
    );
  }

  @override
  void dispose() {
    _followUpController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.lg, right: AppSpacing.lg),
            child: Row(
              children: [
                Icon(Icons.search, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.query,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _answer != null
              ? ListView(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  children: [
                    ResponseCard(
                      result: _answer!,
                      onOpenSource: _answer!.sourceCardId != null
                          ? () => _openSourceCard(_answer!.sourceCardId!)
                          : null,
                      onOpenSourceById: _openSourceCard,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: TextField(
                        controller: _followUpController,
                        decoration: InputDecoration(
                          hintText: _isListening ? 'J\'écoute...' : 'Poser une autre question...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_followUpController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _followUpController.clear();
                                    setState(() {});
                                  },
                                ),
                              IconButton(
                                icon: Icon(
                                  _isListening ? Icons.mic : Icons.mic_none,
                                  size: 20,
                                  color: _isListening ? AppColors.accentRed : null,
                                ),
                                onPressed: _isListening ? _stopListening : _startListening,
                              ),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (query) {
                          if (query.trim().isNotEmpty) {
                            _submitFollowUpSearch(query);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        context.watch<CardProvider>().error ?? 'Aucun résultat',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
    );
  }
}
