import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  test('maps a phone-number authorization request to the phone stage', () {
    final stage = AuthorizationStage.from(
      const td.AuthorizationStateWaitPhoneNumber(),
    );

    expect(stage.kind, AuthorizationStageKind.phoneNumber);
  });

  test('keeps the TDLib QR confirmation link', () {
    const link = 'tg://login?token=abc';

    final stage = AuthorizationStage.from(
      const td.AuthorizationStateWaitOtherDeviceConfirmation(link: link),
    );

    expect(stage.kind, AuthorizationStageKind.qrCode);
    expect(stage.qrLink, link);
  });

  test('maps code, password, and ready states', () {
    final code = AuthorizationStage.from(
      td.AuthorizationStateWaitCode(
        codeInfo: const td.AuthenticationCodeInfo(
          phoneNumber: '+15550000000',
          type: td.AuthenticationCodeTypeTelegramMessage(length: 5),
          nextType: null,
          timeout: 0,
        ),
      ),
    );
    expect(code.kind, AuthorizationStageKind.code);
    expect(code.phoneNumber, '+15550000000');
    expect(code.codeDelivery, CodeDelivery.app);

    final password = AuthorizationStage.from(
      const td.AuthorizationStateWaitPassword(
        passwordHint: 'cat',
        hasRecoveryEmailAddress: false,
        hasPassportData: false,
        recoveryEmailAddressPattern: '',
      ),
    );
    expect(password.kind, AuthorizationStageKind.password);
    expect(password.passwordHint, 'cat');

    final ready = AuthorizationStage.from(const td.AuthorizationStateReady());
    expect(ready.kind, AuthorizationStageKind.ready);
  });
}
