/// A country for the phone number form, as TDLib lists it.
final class PhoneCountry {
  const PhoneCountry({
    required this.code,
    required this.name,
    required this.callingCodes,
  });

  /// ISO 3166-1 alpha-2 code, such as `RU`.
  final String code;

  /// The name in the language TDLib was started with.
  final String name;

  /// Calling codes without the plus sign, such as `7`.
  final List<String> callingCodes;
}

/// Finds the country whose calling code is the longest prefix of [digits].
///
/// Several countries can share a code (`1` covers the US and Canada); the
/// [preferred] country wins such a tie.
PhoneCountry? countryForDigits(
  List<PhoneCountry> countries,
  String digits, {
  String? preferred,
}) {
  PhoneCountry? best;
  var bestLength = 0;
  for (final country in countries) {
    for (final code in country.callingCodes) {
      if (code.isEmpty || !digits.startsWith(code)) continue;
      final better =
          code.length > bestLength ||
          (code.length == bestLength && country.code == preferred);
      if (better) {
        best = country;
        bestLength = code.length;
      }
    }
  }
  return best;
}
