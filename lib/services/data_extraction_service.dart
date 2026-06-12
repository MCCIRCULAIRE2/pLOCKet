class ExtractedData {
  final List<String> dates;
  final List<String> amounts;
  final List<String> contractNumbers;
  final List<String> registrations;
  final List<String> ibans;
  final List<String> emails;
  final List<String> phones;
  final List<String> addresses;
  final List<String> deadlines;
  final List<String> socialSecurityNumbers;

  ExtractedData({
    this.dates = const [],
    this.amounts = const [],
    this.contractNumbers = const [],
    this.registrations = const [],
    this.ibans = const [],
    this.emails = const [],
    this.phones = const [],
    this.addresses = const [],
    this.deadlines = const [],
    this.socialSecurityNumbers = const [],
  });
}

class DataExtractionService {
  static final RegExp _datePattern =
      RegExp(r'\b(\d{2}/\d{2}/\d{4}|\d{4}-\d{2}-\d{2}|\d{2}\.\d{2}\.\d{4})\b');
  static final RegExp _amountPattern =
      RegExp(r'\b(\d[\d\s]*[.,]\d{2}\s?(?:€|EUR|euros?)|(?:€|EUR)\s?\d[\d\s]*[.,]\d{2})\b');
  static final RegExp _contractPattern =
      RegExp(r'\b(?:contrat|n°|no|numéro)[\s:]*([A-Z0-9]{4,20})\b', caseSensitive: false);
  static final RegExp _registrationPattern =
      RegExp(r'\b[A-Z]{2}[- ]?\d{3}[- ]?[A-Z]{2}\b');
  static final RegExp _ibanPattern =
      RegExp(r'\b[A-Z]{2}\d{2}[ ]?\d{4}[ ]?\d{4}[ ]?\d{4}[ ]?\d{4}[ ]?\d{0,4}\b');
  static final RegExp _emailPattern =
      RegExp(r'\b[\w.%+-]+@[\w.-]+\.[A-Za-z]{2,}\b');
  static final RegExp _phonePattern =
      RegExp(r'\b(?:0|\+33)[1-9](?:[\s.-]?\d{2}){4}\b');
  static final RegExp _addressPattern =
      RegExp(r'\b\d{1,4}\s+(?:rue|avenue|boulevard|place|chemin|impasse|allée)\s+.+?(?=\d{5})',
          caseSensitive: false);
  static final RegExp _deadlinePattern =
      RegExp(r'\b(?:échéance|echeance|échu|echu|expire|expiration)[\s:]*(\d{2}/\d{2}/\d{4}|\d{4}-\d{2}-\d{2})',
          caseSensitive: false);

  static final RegExp _ssnPattern = RegExp(
      r'(?:num[eé]ro\s+de\s+s[eé]curit[eé]\s+sociale|n[°o]\s*s[eé]cu|s[eé]curit[eé]\s+sociale)\s*(?:est\s+le\s+)?[:\s]*((?:\d[\s-]?){13,15}\d)',
      caseSensitive: false);

  ExtractedData extractAll(String text) {
    return ExtractedData(
      dates: _extractAll(_datePattern, text),
      amounts: _extractAll(_amountPattern, text),
      contractNumbers: _extractAll(_contractPattern, text),
      registrations: _extractAll(_registrationPattern, text),
      ibans: _extractAll(_ibanPattern, text),
      emails: _extractAll(_emailPattern, text),
      phones: _extractAll(_phonePattern, text),
      addresses: _extractAll(_addressPattern, text),
      deadlines: _extractAll(_deadlinePattern, text),
      socialSecurityNumbers: _extractAll(_ssnPattern, text),
    );
  }

  List<String> _extractAll(RegExp pattern, String text) {
    final matches = pattern.allMatches(text);
    final results = <String>{};
    for (final m in matches) {
      if (m.groupCount >= 1 && m.group(1) != null) {
        results.add(m.group(1)!);
      } else {
        results.add(m.group(0)!);
      }
    }
    return results.toList();
  }
}
