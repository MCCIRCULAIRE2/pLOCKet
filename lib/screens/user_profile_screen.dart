import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _emailController;
  late TextEditingController _telephoneController;
  late TextEditingController _adresseController;
  late TextEditingController _numeroSSController;
  late TextEditingController _ibanController;
  late TextEditingController _informationsController;
  
  DateTime? _dateNaissance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController();
    _prenomController = TextEditingController();
    _emailController = TextEditingController();
    _telephoneController = TextEditingController();
    _adresseController = TextEditingController();
    _numeroSSController = TextEditingController();
    _ibanController = TextEditingController();
    _informationsController = TextEditingController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  void _loadProfile() {
    final provider = context.read<UserProfileProvider>();
    final profile = provider.profile;
    
    if (profile != null) {
      setState(() {
        _nomController.text = profile.nom ?? '';
        _prenomController.text = profile.prenom ?? '';
        _emailController.text = profile.email ?? '';
        _telephoneController.text = profile.telephone ?? '';
        _adresseController.text = profile.adressePostale ?? '';
        _numeroSSController.text = profile.numeroSecuriteSociale ?? '';
        _ibanController.text = profile.iban ?? '';
        _informationsController.text = profile.informationsLibres ?? '';
        _dateNaissance = profile.dateNaissance;
      });
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    _numeroSSController.dispose();
    _ibanController.dispose();
    _informationsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final profile = UserProfile(
      nom: _nomController.text.trim().isEmpty ? null : _nomController.text.trim(),
      prenom: _prenomController.text.trim().isEmpty ? null : _prenomController.text.trim(),
      dateNaissance: _dateNaissance,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      telephone: _telephoneController.text.trim().isEmpty ? null : _telephoneController.text.trim(),
      adressePostale: _adresseController.text.trim().isEmpty ? null : _adresseController.text.trim(),
      numeroSecuriteSociale: _numeroSSController.text.trim().isEmpty ? null : _numeroSSController.text.trim(),
      iban: _ibanController.text.trim().isEmpty ? null : _ibanController.text.trim(),
      informationsLibres: _informationsController.text.trim().isEmpty ? null : _informationsController.text.trim(),
    );

    final provider = context.read<UserProfileProvider>();
    await provider.saveProfile(profile);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (provider.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil sauvegardé avec succès')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() => _dateNaissance = picked);
    }
  }

  Future<void> _deleteProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le profil ?'),
        content: const Text('Toutes vos informations personnelles seront supprimées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = context.read<UserProfileProvider>();
      await provider.deleteProfile();
      
      if (mounted) {
        setState(() {
          _nomController.clear();
          _prenomController.clear();
          _emailController.clear();
          _telephoneController.clear();
          _adresseController.clear();
          _numeroSSController.clear();
          _ibanController.clear();
          _informationsController.clear();
          _dateNaissance = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil supprimé')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<UserProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes informations'),
        actions: [
          if (provider.profile != null && provider.profile!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteProfile,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informations personnelles',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Ces informations sont utilisées pour améliorer l\'indexation et les recherches.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  _buildTextField(
                    controller: _prenomController,
                    label: 'Prénom',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  _buildTextField(
                    controller: _nomController,
                    label: 'Nom',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  _buildDateField(theme),
                  const SizedBox(height: AppSpacing.md),
                  
                  _buildTextField(
                    controller: _emailController,
                    label: 'Adresse email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty && !value.contains('@')) {
                        return 'Adresse email invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  _buildTextField(
                    controller: _telephoneController,
                    label: 'Téléphone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  _buildTextField(
                    controller: _adresseController,
                    label: 'Adresse postale',
                    icon: Icons.home_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  _buildTextField(
                    controller: _numeroSSController,
                    label: 'Numéro de sécurité sociale',
                    icon: Icons.credit_card_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  _buildTextField(
                    controller: _ibanController,
                    label: 'IBAN',
                    icon: Icons.account_balance_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  _buildTextField(
                    controller: _informationsController,
                    label: 'Informations libres',
                    icon: Icons.notes_outlined,
                    maxLines: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildDateField(ThemeData theme) {
    return InkWell(
      onTap: _selectDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date de naissance',
          prefixIcon: Icon(Icons.cake_outlined, size: 20),
          border: OutlineInputBorder(),
        ),
        child: Text(
          _dateNaissance != null
              ? DateFormat('dd/MM/yyyy').format(_dateNaissance!)
              : 'Sélectionner une date',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
