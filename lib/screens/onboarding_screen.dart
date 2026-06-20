import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/entity_provider.dart';
import '../providers/entity_type_provider.dart';
import '../providers/relation_provider.dart';
import '../providers/relation_type_provider.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  // Step 1 — Identity form
  final _identityFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _birthDate;

  // Step 2 — Entities
  int _step2CreatedCount = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    context.read<OnboardingProvider>().goToStep(step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _skipToEnd() async {
    await context.read<OnboardingProvider>().completeOnboarding(
      context.read<UserProfileProvider>(),
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _onContinueStep1() async {
    if (!_identityFormKey.currentState!.validate()) return;

    final profile = UserProfile(
      userId: context.read<AuthProvider>().userId ?? '',
      firstName: _firstNameController.text.trim().isEmpty
          ? null
          : _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim().isEmpty
          ? null
          : _lastNameController.text.trim(),
      birthDate: _birthDate,
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
    );

    await context.read<UserProfileProvider>().saveProfile(profile);
    context.read<OnboardingProvider>().updateProfile(profile);
    if (!mounted) return;
    _goToStep(1);
  }

  void _onContinueStep2() {
    _goToStep(2);
  }

  Future<void> _addQuickEntity({
    required String label,
    required String entityTypeCode,
    required String relationTypeCode,
  }) async {
    final entityProvider = context.read<EntityProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();
    final entityTypeProvider = context.read<EntityTypeProvider>();
    final relationProvider = context.read<RelationProvider>();
    final relationTypeProvider = context.read<RelationTypeProvider>();

    final me = await entityProvider.getMeEntity(
      userProfileProvider: userProfileProvider,
      entityTypeProvider: entityTypeProvider,
    );
    if (me == null) return;

    final typeId = entityTypeProvider.getTypeByCode(entityTypeCode)?.id;
    final relTypeId = relationTypeProvider.getTypeByCode(relationTypeCode)?.id;
    if (typeId == null || relTypeId == null) return;

    final entity = await entityProvider.createEntity(
      entityTypeId: typeId,
      label: label,
    );

    await relationProvider.createRelation(
      sourceEntityId: me.id,
      targetEntityId: entity.id,
      relationTypeId: relTypeId,
    );

    if (!mounted) return;
    setState(() => _step2CreatedCount++);
  }

  void _showQuickEntityDialog({
    required String title,
    required String entityTypeCode,
    required String relationTypeCode,
    String? defaultLabel,
  }) {
    final labelController =
        TextEditingController(text: defaultLabel ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text(title),
        content: TextField(
          controller: labelController,
          decoration: InputDecoration(
            labelText: defaultLabel == null ? 'Nom' : 'Libellé',
            hintText: defaultLabel ?? 'Ex: Emma',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final label = labelController.text.trim();
              if (label.isNotEmpty) {
                Navigator.pop(ctx);
                _addQuickEntity(
                  label: label,
                  entityTypeCode: entityTypeCode,
                  relationTypeCode: relationTypeCode,
                );
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<OnboardingProvider>(
      builder: (context, onboarding, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: _buildStepIndicator(onboarding),
            actions: [
              TextButton(
                onPressed: _skipToEnd,
                child: const Text('Passer'),
              ),
            ],
          ),
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (page) {
              onboarding.goToStep(page);
            },
            children: [
              _buildStep1(theme),
              _buildStep2(theme),
              _buildStep3(theme, onboarding),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(onboarding),
        );
      },
    );
  }

  Widget _buildStepIndicator(OnboardingProvider onboarding) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < OnboardingProvider.totalSteps; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == onboarding.currentStep
                    ? AppColors.primaryBlue
                    : AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStep1(ThemeData theme) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _identityFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Qui êtes-vous ?',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Ces informations permettent à pLOCKet de personnaliser '
                'vos recherches et de vous répondre quand vous demandez '
                '« Quel est mon numéro de téléphone ? » ou '
                '« Montre-moi mon profil ».',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Prénom',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Requis'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Requis'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date de naissance',
                    prefixIcon: Icon(Icons.cake_outlined, size: 20),
                  ),
                  child: Text(
                    _birthDate != null
                        ? DateFormat('dd/MM/yyyy').format(_birthDate!)
                        : 'Sélectionner une date',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _birthDate != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Widget _buildStep2(ThemeData theme) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Qu\'est-ce qui compte pour vous ?',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Ajoutez des personnes, des biens ou des contrats pour '
              'pouvoir poser des questions comme :',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _QuickSuggestionCard(
              icon: Icons.favorite_outline,
              color: AppColors.accentRed,
              title: 'Mon/Ma conjoint(e)',
              subtitle: 'Téléphone, email, date de naissance',
              example: '« Quel est le numéro de mon conjoint ? »',
              onAdd: () => _showQuickEntityDialog(
                title: 'Ajouter un(e) conjoint(e)',
                entityTypeCode: 'personne',
                relationTypeCode: 'conjoint',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _QuickSuggestionCard(
              icon: Icons.child_care_outlined,
              color: AppColors.accentTeal,
              title: 'Mon enfant',
              subtitle: 'Date de naissance, école, numéro',
              example: '« Quelle est la date de naissance de mon enfant ? »',
              onAdd: () => _showQuickEntityDialog(
                title: 'Ajouter un enfant',
                entityTypeCode: 'personne',
                relationTypeCode: 'enfant',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _QuickSuggestionCard(
              icon: Icons.home_outlined,
              color: AppColors.primaryBlue,
              title: 'Ma résidence',
              subtitle: 'Adresse, surface, charges',
              example: '« Quelle est mon adresse ? »',
              onAdd: () => _showQuickEntityDialog(
                title: 'Ajouter une résidence',
                entityTypeCode: 'maison',
                relationTypeCode: 'occupant',
                defaultLabel: 'Résidence principale',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _QuickSuggestionCard(
              icon: Icons.directions_car_outlined,
              color: AppColors.accentOrange,
              title: 'Mon véhicule',
              subtitle: 'Immatriculation, marque, modèle',
              example: '« Quelle est mon immatriculation ? »',
              onAdd: () => _showQuickEntityDialog(
                title: 'Ajouter un véhicule',
                entityTypeCode: 'voiture',
                relationTypeCode: 'conducteur_principal',
                defaultLabel: 'Ma voiture',
              ),
            ),
            if (_step2CreatedCount > 0) ...[
              const SizedBox(height: AppSpacing.lg),
              GlassCard(
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.accentGreen, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$_step2CreatedCount élément(s) ajouté(s)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.accentGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Center(
              child: Text(
                'Vous pourrez ajouter ou modifier vos informations à tout moment\n'
                'depuis Paramètres > Mes données personnelles.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3(ThemeData theme, OnboardingProvider onboarding) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.huge),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGreen.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 40,
                color: AppColors.accentGreen,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'C\'est parti !',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _step2CreatedCount > 0
                  ? '$_step2CreatedCount élément(s) ont été ajoutés à '
                      'vos données personnelles. Vous pouvez maintenant '
                      'interroger pLOCKet par la recherche ou la voix.'
                  : 'Vos informations de base sont enregistrées. Vous pourrez '
                      'enrichir vos données à tout moment depuis '
                      'Paramètres > Mes données personnelles.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Essayez de demander :',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ExampleRow(
                    icon: Icons.search,
                    text: '« Quel est mon numéro de téléphone ? »',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ExampleRow(
                    icon: Icons.search,
                    text: '« Quelle est mon adresse ? »',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ExampleRow(
                    icon: Icons.mic_outlined,
                    text: '« Qui est mon conjoint ? »',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ExampleRow(
                    icon: Icons.search,
                    text: '« Montre-moi mes informations »',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(OnboardingProvider onboarding) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Row(
          children: [
            if (onboarding.currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goToStep(onboarding.currentStep - 1),
                  child: const Text('Précédent'),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  switch (onboarding.currentStep) {
                    case 0:
                      _onContinueStep1();
                    case 1:
                      _onContinueStep2();
                    case 2:
                      _skipToEnd();
                  }
                },
                child: Text(
                  onboarding.isLastStep ? 'Commencer' : 'Continuer',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSuggestionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String example;
  final VoidCallback onAdd;

  const _QuickSuggestionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.example,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    example,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ExampleRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}


