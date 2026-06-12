class UserProfile {
  final String? nom;
  final String? prenom;
  final DateTime? dateNaissance;
  final String? email;
  final String? telephone;
  final String? adressePostale;
  final String? numeroSecuriteSociale;
  final String? iban;
  final String? informationsLibres;

  UserProfile({
    this.nom,
    this.prenom,
    this.dateNaissance,
    this.email,
    this.telephone,
    this.adressePostale,
    this.numeroSecuriteSociale,
    this.iban,
    this.informationsLibres,
  });

  UserProfile copyWith({
    String? nom,
    String? prenom,
    DateTime? dateNaissance,
    String? email,
    String? telephone,
    String? adressePostale,
    String? numeroSecuriteSociale,
    String? iban,
    String? informationsLibres,
  }) {
    return UserProfile(
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      adressePostale: adressePostale ?? this.adressePostale,
      numeroSecuriteSociale: numeroSecuriteSociale ?? this.numeroSecuriteSociale,
      iban: iban ?? this.iban,
      informationsLibres: informationsLibres ?? this.informationsLibres,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'prenom': prenom,
      'dateNaissance': dateNaissance?.toIso8601String(),
      'email': email,
      'telephone': telephone,
      'adressePostale': adressePostale,
      'numeroSecuriteSociale': numeroSecuriteSociale,
      'iban': iban,
      'informationsLibres': informationsLibres,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      nom: map['nom'] as String?,
      prenom: map['prenom'] as String?,
      dateNaissance: map['dateNaissance'] != null
          ? DateTime.parse(map['dateNaissance'] as String)
          : null,
      email: map['email'] as String?,
      telephone: map['telephone'] as String?,
      adressePostale: map['adressePostale'] as String?,
      numeroSecuriteSociale: map['numeroSecuriteSociale'] as String?,
      iban: map['iban'] as String?,
      informationsLibres: map['informationsLibres'] as String?,
    );
  }

  bool get isEmpty =>
      nom == null &&
      prenom == null &&
      dateNaissance == null &&
      email == null &&
      telephone == null &&
      adressePostale == null &&
      numeroSecuriteSociale == null &&
      iban == null &&
      informationsLibres == null;

  bool get isNotEmpty => !isEmpty;

  String get nomComplet {
    if (prenom != null && nom != null) {
      return '$prenom $nom';
    } else if (prenom != null) {
      return prenom!;
    } else if (nom != null) {
      return nom!;
    }
    return '';
  }
}
