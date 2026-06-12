import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/card_provider.dart';
import '../providers/search_provider.dart';
import '../providers/analytical_field_provider.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/recent_card_card.dart';
import '../widgets/update_notification.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'scanner_screen.dart';
import 'import_screen.dart';
import 'dictation_screen.dart';
import 'manual_entry_screen.dart';
import 'search_results_screen.dart';
import 'card_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _hasMicPermission = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CardProvider>().loadCards();
      context.read<AnalyticalFieldProvider>().loadAll();
    });
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
          _searchController.text = result.recognizedWords;
        });
        
        // Si la reconnaissance est terminée et qu'il y a du texte, lancer la recherche
        if (!result.finalResult) return;
        
        final query = result.recognizedWords.trim();
        if (query.isNotEmpty) {
          _submitSearch(query);
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _speech.stop();
    super.dispose();
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    context.read<SearchProvider>().search(trimmed);
    _searchController.clear();
    _searchFocus.unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(query: trimmed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('pLOCKet'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(context, theme),
                const SizedBox(height: AppSpacing.xl),
                _buildQuickActions(context, theme),
                const SizedBox(height: AppSpacing.xxxl),
                _buildRecentCardsSection(context, theme),
                const SizedBox(height: AppSpacing.xxxl),
                _buildRecentQuestionsSection(context, theme),
                const SizedBox(height: AppSpacing.huge),
              ],
            ),
          ),
        ),
        const UpdateNotification(),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Que cherchez-vous ?',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: _isListening ? 'J\'écoute...' : 'Posez une question...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
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
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: _submitSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg, bottom: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text('ACTIONS RAPIDES', style: theme.textTheme.titleSmall),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              QuickActionButton(
                icon: Icons.camera_alt_outlined,
                label: 'Scanner',
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ScannerScreen()),
                ),
              ),
              QuickActionButton(
                icon: Icons.upload_file_outlined,
                label: 'Importer',
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ImportScreen()),
                ),
              ),
              QuickActionButton(
                icon: Icons.mic_outlined,
                label: 'Dicter',
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const DictationScreen()),
                ),
              ),
              QuickActionButton(
                icon: Icons.edit_note_outlined,
                label: 'Saisir',
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentCardsSection(BuildContext context, ThemeData theme) {
    return Consumer<CardProvider>(
      builder: (context, provider, _) {
        final recent = provider.cards.take(10).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, bottom: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 3, height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('FICHES RÉCENTES', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  if (recent.length >= 10)
                    TextButton(
                      onPressed: () {},
                      child: Text('Tout voir', style: TextStyle(fontSize: 13, color: AppColors.primaryBlue)),
                    ),
                ],
              ),
            ),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucune fiche pour le moment', style: theme.textTheme.bodySmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Importez ou scannez un document', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: recent
                    .map((card) => RecentCardCard(
                          card: card,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CardDetailScreen(cardId: card.id),
                              ),
                            );
                          },
                        ))
                    .toList(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRecentQuestionsSection(BuildContext context, ThemeData theme) {
    return Consumer<SearchProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, bottom: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 3, height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('QUESTIONS RÉCENTES', style: theme.textTheme.titleSmall),
                ],
              ),
            ),
            if (provider.recentQueries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Center(
                  child: Text('Aucune question pour le moment', style: theme.textTheme.bodySmall),
                ),
              )
            else
              ...provider.recentQueries.map((q) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 2),
                    child: Material(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        onTap: () {
                          _searchController.clear();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SearchResultsScreen(query: q),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(color: AppColors.borderLight, width: 0.5),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.history, size: 20, color: AppColors.textTertiary),
                            title: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium),
                            trailing: Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                          ),
                        ),
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}
