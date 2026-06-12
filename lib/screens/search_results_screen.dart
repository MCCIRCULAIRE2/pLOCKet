import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _ask();
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
                        decoration: InputDecoration(
                          hintText: 'Poser une autre question...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (query) {
                          if (query.trim().isNotEmpty) {
                            setState(() => _isLoading = true);
                            context.read<CardProvider>().ask(query.trim()).then((answer) {
                              if (mounted) {
                                setState(() {
                                  _answer = answer;
                                  _isLoading = false;
                                });
                              }
                            });
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
