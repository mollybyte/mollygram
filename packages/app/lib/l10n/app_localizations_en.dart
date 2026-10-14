// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mollygram';

  @override
  String get back => 'Back';

  @override
  String get qrTitle => 'Log in to Mollygram by QR code';

  @override
  String get qrStep1 => 'Open Telegram on your phone';

  @override
  String get qrStep2 => 'Go to Settings > Devices > Link Desktop Device';

  @override
  String get qrStep3 => 'Point your phone at this screen to confirm login';

  @override
  String get qrLoading => 'Loading the code…';

  @override
  String get logInByPhone => 'Log in by phone number';

  @override
  String get logInByQr => 'Log in by QR code';

  @override
  String get phoneTitle => 'Your phone number';

  @override
  String get phoneHint =>
      'Please confirm your country code and enter your phone number.';

  @override
  String get phoneNumberHint => 'Phone number';

  @override
  String get country => 'Country';

  @override
  String get next => 'Next';

  @override
  String get codeHint => 'Code';

  @override
  String get codeSentApp =>
      'We have sent the code to the Telegram app on your other device.';

  @override
  String get codeSentSms => 'We have sent you a code via SMS.';

  @override
  String get codeSentCall => 'We are calling you to dictate the code.';

  @override
  String get codeSentOther => 'Enter the code you received.';

  @override
  String get passwordTitle => 'Two-step verification';

  @override
  String get passwordHint =>
      'Your account is protected with an additional password.';

  @override
  String passwordHintWithHint(String hint) {
    return 'Your account is protected with an additional password. Hint: $hint';
  }

  @override
  String get passwordFieldHint => 'Password';

  @override
  String get starting => 'Starting Telegram…';

  @override
  String get unsupportedTitle => 'Finish signing up in the official app';

  @override
  String get unsupportedStep =>
      'This sign-in step is not supported yet. Finish signing up in the official Telegram app, then try again.';

  @override
  String get errorInvalidPhone => 'Invalid phone number';

  @override
  String get errorInvalidCode => 'Invalid code';

  @override
  String get errorCodeExpired => 'The code has expired, request a new one';

  @override
  String get errorInvalidPassword => 'Wrong password';

  @override
  String get errorTooManyAttempts => 'Too many attempts, try again later';

  @override
  String errorGeneric(String message) {
    return 'Something went wrong: $message';
  }

  @override
  String get missingKeysTitle => 'Telegram API keys are missing';

  @override
  String get missingKeysHint =>
      'Build the app with --dart-define-from-file=config/telegram.json. The template is config/telegram.example.json.';

  @override
  String get startFailedTitle => 'Telegram could not start';

  @override
  String get searchHint => 'Search';

  @override
  String get folderAll => 'All';

  @override
  String get noChats => 'No chats yet';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get selectChat => 'Select a chat to start messaging';

  @override
  String get messageHint => 'Message';

  @override
  String get attach => 'Attach';

  @override
  String get emoji => 'Emoji and stickers';

  @override
  String get record => 'Record a voice or video message';

  @override
  String get send => 'Send';

  @override
  String previewYou(String text) {
    return 'You: $text';
  }

  @override
  String get previewPhoto => 'Photo';

  @override
  String get previewVideo => 'Video';

  @override
  String get previewVideoNote => 'Video message';

  @override
  String get previewVoiceNote => 'Voice message';

  @override
  String get previewAudio => 'Audio';

  @override
  String get previewDocument => 'File';

  @override
  String get previewSticker => 'Sticker';

  @override
  String get previewAnimation => 'GIF';

  @override
  String get previewOther => 'Message';

  @override
  String get noTextMessages => 'No text messages here yet';

  @override
  String get sendFailed => 'The message wasn\'t sent. Try again';
}
