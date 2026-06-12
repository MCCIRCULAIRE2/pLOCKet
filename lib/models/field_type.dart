import 'package:flutter/material.dart';

enum FieldType {
  text,
  date,
  currency,
  number,
  percentage,
  distance,
  identifier,
  vehicleRegistration,
  socialSecurityNumber,
  email,
  phone;

  String get displayName {
    switch (this) {
      case FieldType.text: return 'Texte';
      case FieldType.date: return 'Date';
      case FieldType.currency: return 'Monnaie';
      case FieldType.number: return 'Nombre';
      case FieldType.percentage: return 'Pourcentage';
      case FieldType.distance: return 'Distance';
      case FieldType.identifier: return 'Identifiant';
      case FieldType.vehicleRegistration: return 'Plaque';
      case FieldType.socialSecurityNumber: return 'N° Sécu';
      case FieldType.email: return 'Email';
      case FieldType.phone: return 'Téléphone';
    }
  }

  String get shortName {
    switch (this) {
      case FieldType.text: return 'txt';
      case FieldType.date: return 'date';
      case FieldType.currency: return '€';
      case FieldType.number: return '#';
      case FieldType.percentage: return '%';
      case FieldType.distance: return 'km';
      case FieldType.identifier: return 'ID';
      case FieldType.vehicleRegistration: return 'plaque';
      case FieldType.socialSecurityNumber: return 'ss';
      case FieldType.email: return '@';
      case FieldType.phone: return 'tel';
    }
  }

  IconData get icon {
    switch (this) {
      case FieldType.text: return Icons.text_fields;
      case FieldType.date: return Icons.calendar_today;
      case FieldType.currency: return Icons.euro;
      case FieldType.number: return Icons.tag;
      case FieldType.percentage: return Icons.percent;
      case FieldType.distance: return Icons.straighten;
      case FieldType.identifier: return Icons.badge;
      case FieldType.vehicleRegistration: return Icons.directions_car;
      case FieldType.socialSecurityNumber: return Icons.health_and_safety;
      case FieldType.email: return Icons.email_outlined;
      case FieldType.phone: return Icons.phone;
    }
  }

  Color get color {
    switch (this) {
      case FieldType.text: return Colors.blueGrey;
      case FieldType.date: return Colors.teal;
      case FieldType.currency: return Colors.green;
      case FieldType.number: return Colors.indigo;
      case FieldType.percentage: return Colors.orange;
      case FieldType.distance: return Colors.cyan;
      case FieldType.identifier: return Colors.purple;
      case FieldType.vehicleRegistration: return Colors.amber;
      case FieldType.socialSecurityNumber: return Colors.pink;
      case FieldType.email: return Colors.blue;
      case FieldType.phone: return Colors.deepOrange;
    }
  }

  static FieldType detect(String rawValue) {
    final v = rawValue.trim();

    if (v.isEmpty) return FieldType.text;

    if (v.contains('@') && v.contains('.') && !v.contains(' ')) {
      return FieldType.email;
    }

    if (RegExp(r'^0[1-9](\s?\d{2}){4}$').hasMatch(v) ||
        RegExp(r'^\+33\s?\d(\s?\d{2}){4}$').hasMatch(v) ||
        RegExp(r'^\+\d{1,3}\s?\d{6,12}$').hasMatch(v)) {
      return FieldType.phone;
    }

    if (RegExp(r'^[1-9]\d{12}\d{0,2}$').hasMatch(v) && v.length >= 13) {
      return FieldType.socialSecurityNumber;
    }

    if (RegExp(r'^[A-Z]{2}-\d{3}-[A-Z]{2}$').hasMatch(v.toUpperCase()) ||
        RegExp(r'^\d{3,4}\s?[A-Z]{2}\s?\d{2,3}$').hasMatch(v.toUpperCase())) {
      return FieldType.vehicleRegistration;
    }

    if (RegExp(r'^\d{0,3}\s?\d{0,3}\s?\d{0,4}\s?\d{0,4}$').hasMatch(v) &&
        v.replaceAll(' ', '').length >= 6 &&
        v.replaceAll(' ', '').length <= 20) {
      // Could be an identifier, but we're conservative
    }

    if (v.endsWith('%') || v.endsWith(' %') || v.endsWith('pourcent')) {
      return FieldType.percentage;
    }

    if (RegExp(r'\d+\s*km$', caseSensitive: false).hasMatch(v) ||
        RegExp(r'\d+\s*kilomètres$', caseSensitive: false).hasMatch(v)) {
      return FieldType.distance;
    }

    if (v.contains('€') || v.contains('EUR') || v.contains('\$') || v.contains('£')) {
      return FieldType.currency;
    }

    final hasCurrencyPrefix = RegExp(r'^[€$£]\s*\d').hasMatch(v);
    if (hasCurrencyPrefix) return FieldType.currency;

    // Check for pure numbers with currency formatting
    final cleaned = v
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    if (RegExp(r'^\d+[.,]?\d*$').hasMatch(cleaned)) {
      return FieldType.number;
    }

    // Cleaned with currency suffix (e.g. "6085" with no symbol but field name suggests money)
    // We can't detect this without field name context, so leave as text for now

    if (RegExp(r'^\d{2}[/-]\d{2}[/-]\d{4}$').hasMatch(v) ||
        RegExp(r'^\d{4}[/-]\d{2}[/-]\d{2}$').hasMatch(v)) {
      return FieldType.date;
    }

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
      return FieldType.date;
    }

    return FieldType.text;
  }

  static FieldType detectFromName(String name, String rawValue) {
    final key = name.toLowerCase().trim();

    if (key.contains('date') || key.contains('échéance') || key.contains('echeance')) {
      return FieldType.date;
    }
    if (key.contains('montant') || key.contains('total') || key.contains('prix') ||
        key.contains('acompte') || key.contains('tva') || key.contains('paie') ||
        key.contains('salaire') || key.contains('cout') || key.contains('coût') ||
        key.contains('remise') || key.contains('solde')) {
      return FieldType.currency;
    }
    if (key.contains('email') || key.contains('courriel') || key.contains('mail')) {
      return FieldType.email;
    }
    if (key.contains('téléphone') || key.contains('telephone') || key.contains('tel') ||
        key.contains('mobile') || key.contains('fixe') || key.contains('portable')) {
      return FieldType.phone;
    }
    if (key.contains('sécurité sociale') || key.contains('securite sociale') ||
        key.contains('n° sécu') || key.contains('numéro sécu') ||
        key.contains('ssn') || key.contains('numero_securite')) {
      return FieldType.socialSecurityNumber;
    }
    if (key.contains('plaque') || key.contains('immatriculation') ||
        key.contains('véhicule') || key.contains('vehicule') ||
        key.contains('carte grise') || key.contains('carte_grise')) {
      return FieldType.vehicleRegistration;
    }
    if (key.contains('km') || key.contains('kilomètre') || key.contains('kilometre') ||
        key.contains('distance')) {
      return FieldType.distance;
    }
    if (key.contains('pourcent') || key.contains('taux') || key.contains('remise')) {
      return FieldType.percentage;
    }
    if (key.contains('numéro') || key.contains('numero') || key.contains('n°') ||
        key.contains('ref') || key.contains('réf') || key.contains('réference') ||
        key.contains('reference') || key.contains('id') || key.contains('identifiant') ||
        key.contains('code') || key.contains('facture')) {
      return FieldType.identifier;
    }

    return detect(rawValue);
  }

  bool validate(String rawValue) {
    final v = rawValue.trim();
    if (v.isEmpty) return true;

    switch (this) {
      case FieldType.date:
        return RegExp(r'^\d{2}[/-]\d{2}[/-]\d{4}$').hasMatch(v) ||
            RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v);

      case FieldType.currency:
        final cleaned = v
            .replaceAll('€', '').replaceAll('EUR', '').replaceAll('\$', '').replaceAll('£', '')
            .replaceAll(' ', '').replaceAll(',', '.');
        return RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned);

      case FieldType.number:
        final cleaned = v.replaceAll(' ', '').replaceAll(',', '.');
        if (v.contains('km') || v.contains('€') || v.contains('%')) return false;
        return RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned);

      case FieldType.percentage:
        return RegExp(r'^\d+([.,]\d+)?\s*%$').hasMatch(v) ||
            RegExp(r'^\d+([.,]\d+)?$').hasMatch(v);

      case FieldType.distance:
        return RegExp(r'^\d+([.,]\d+)?\s*km$', caseSensitive: false).hasMatch(v);

      case FieldType.vehicleRegistration:
        return RegExp(r'^[A-Z]{2}-\d{3}-[A-Z]{2}$').hasMatch(v.toUpperCase()) ||
            RegExp(r'^\d{3,4}\s?[A-Z]{2}\s?\d{2,3}$').hasMatch(v.toUpperCase());

      case FieldType.socialSecurityNumber:
        final digits = v.replaceAll(RegExp(r'[\s-]'), '');
        return digits.length == 13 || digits.length == 15;

      case FieldType.email:
        return v.contains('@') && v.contains('.');

      case FieldType.phone:
        return RegExp(r'^0[1-9](\s?\d{2}){4}$').hasMatch(v) ||
            RegExp(r'^\+33\s?\d(\s?\d{2}){4}$').hasMatch(v);

      case FieldType.identifier:
        return v.length >= 2;

      case FieldType.text:
        return true;
    }
  }

  String normalize(String rawValue) {
    switch (this) {
      case FieldType.date:
        final parts = rawValue.split(RegExp(r'[/-]'));
        if (parts.length == 3) {
          // DD/MM/YYYY or YYYY-MM-DD
          if (parts[0].length == 4) {
            return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
          }
          return '${parts[0].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[2]}';
        }
        return rawValue;

      case FieldType.currency:
        return rawValue
            .replaceAll('€', '').replaceAll('EUR', '').replaceAll('\$', '').replaceAll('£', '')
            .replaceAll(' ', '')
            .replaceAll(',', '.')
            .trim();

      case FieldType.number:
        return rawValue.replaceAll(' ', '').replaceAll(',', '.').trim();

      case FieldType.percentage:
        return rawValue.replaceAll('%', '').replaceAll(' ', '').replaceAll(',', '.').trim();

      case FieldType.distance:
        return rawValue
            .replaceAll(RegExp(r'km$', caseSensitive: false), '')
            .replaceAll(RegExp(r'kilomètres?$', caseSensitive: false), '')
            .replaceAll(' ', '')
            .replaceAll(',', '.')
            .trim();

      case FieldType.phone:
        return rawValue.replaceAll(' ', '').trim();

      case FieldType.socialSecurityNumber:
        return rawValue.replaceAll(RegExp(r'[\s-]'), '');

      default:
        return rawValue.trim();
    }
  }
}
