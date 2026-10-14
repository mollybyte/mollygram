import 'package:mollygram_core/mollygram_core.dart';
import 'package:test/test.dart';

void main() {
  const countries = [
    PhoneCountry(code: 'US', name: 'United States', callingCodes: ['1']),
    PhoneCountry(code: 'CA', name: 'Canada', callingCodes: ['1']),
    PhoneCountry(code: 'RU', name: 'Russia', callingCodes: ['7']),
    PhoneCountry(code: 'AG', name: 'Antigua', callingCodes: ['1268']),
  ];

  test('picks the longest matching calling code', () {
    expect(countryForDigits(countries, '12685551234')?.code, 'AG');
    expect(countryForDigits(countries, '79001234567')?.code, 'RU');
    expect(countryForDigits(countries, '44'), isNull);
  });

  test('breaks a shared code in favor of the preferred country', () {
    expect(countryForDigits(countries, '1', preferred: 'CA')?.code, 'CA');
  });
}
