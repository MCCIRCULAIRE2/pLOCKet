class UserProfile {
  final String userId;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final DateTime? birthDate;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Anciennes colonnes conservées pour migration applicative
  // Seront supprimées après migration 012
  final String? email;
  final String? adressePostale;
  final String? numeroSecuriteSociale;
  final String? iban;
  final String? informationsLibres;

  UserProfile({
    required this.userId,
    this.firstName,
    this.lastName,
    this.phone,
    this.birthDate,
    this.onboardingCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.email,
    this.adressePostale,
    this.numeroSecuriteSociale,
    this.iban,
    this.informationsLibres,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'birth_date': birthDate?.toIso8601String(),
        'onboarding_completed': onboardingCompleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        // Anciennes colonnes pour migration
        'email': email,
        'adresse_postale': adressePostale,
        'numero_securite_sociale': numeroSecuriteSociale,
        'iban': iban,
        'informations_libres': informationsLibres,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        userId: map['user_id'] as String,
        firstName: map['first_name'] as String?,
        lastName: map['last_name'] as String?,
        phone: map['phone'] as String?,
        birthDate: map['birth_date'] != null
            ? DateTime.parse(map['birth_date'] as String)
            : null,
        onboardingCompleted: map['onboarding_completed'] as bool? ?? false,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
        // Anciennes colonnes
        email: map['email'] as String?,
        adressePostale: map['adresse_postale'] as String?,
        numeroSecuriteSociale: map['numero_securite_sociale'] as String?,
        iban: map['iban'] as String?,
        informationsLibres: map['informations_libres'] as String?,
      );

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? birthDate,
    bool? onboardingCompleted,
  }) =>
      UserProfile(
        userId: userId,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        birthDate: birthDate ?? this.birthDate,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        // Conserver les anciennes colonnes
        email: email,
        adressePostale: adressePostale,
        numeroSecuriteSociale: numeroSecuriteSociale,
        iban: iban,
        informationsLibres: informationsLibres,
      );

  bool get isEmpty =>
      firstName == null &&
      lastName == null &&
      phone == null &&
      birthDate == null;

  bool get isNotEmpty => !isEmpty;

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return '';
  }
  
  // Compatibilité avec l'ancien nom
  String get nomComplet => fullName;
}
