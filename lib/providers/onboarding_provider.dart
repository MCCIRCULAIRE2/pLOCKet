import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../providers/user_profile_provider.dart';

class OnboardingProvider extends ChangeNotifier {
  UserProfile? _profile;

  int _currentStep = 0;
  int get currentStep => _currentStep;

  static const int totalSteps = 3;

  bool get isOnboardingCompleted =>
      _profile?.onboardingCompleted ?? false;

  bool get isLastStep => _currentStep >= totalSteps - 1;

  void updateProfile(UserProfile? profile) {
    _profile = profile;
    notifyListeners();
  }

  void goToStep(int step) {
    if (step >= 0 && step < totalSteps) {
      _currentStep = step;
      notifyListeners();
    }
  }

  void nextStep() {
    if (_currentStep < totalSteps - 1) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding(
      UserProfileProvider userProfileProvider) async {
    final currentProfile = _profile ??
        UserProfile(
          userId: userProfileProvider.profile?.userId ?? '',
          onboardingCompleted: true,
        );

    final updatedProfile = currentProfile.copyWith(
      onboardingCompleted: true,
    );

    await userProfileProvider.saveProfile(updatedProfile);
    _profile = updatedProfile;
    notifyListeners();
  }

  void reset() {
    _currentStep = 0;
    notifyListeners();
  }
}
