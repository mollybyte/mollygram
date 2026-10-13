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
  String get signInTitle => 'Sign in to Telegram';

  @override
  String get signInQrSteps =>
      'Open Telegram on your phone, go to Settings > Devices > Link Desktop Device and scan this code.';

  @override
  String get signInQrLoading => 'Loading the code…';

  @override
  String get signInWithPhone => 'Sign in with phone number';

  @override
  String get signInWithQr => 'Sign in with QR code';

  @override
  String get phoneTitle => 'Your phone number';

  @override
  String get phoneHint =>
      'Enter your number in international format, starting with +.';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get continueAction => 'Continue';

  @override
  String get codeTitle => 'Enter the code';

  @override
  String get codeHint =>
      'Telegram sent a code to the app on your other device or by SMS.';

  @override
  String get codeLabel => 'Code';

  @override
  String get wrongNumber => 'Wrong number?';

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
  String get passwordLabel => 'Password';

  @override
  String get starting => 'Starting Telegram…';

  @override
  String get unsupportedStep =>
      'This sign-in step is not supported yet. Finish signing up in the official app, then try again.';

  @override
  String get errorInvalidPhone => 'This phone number is not valid.';

  @override
  String get errorInvalidCode => 'This code is not valid.';

  @override
  String get errorCodeExpired => 'The code has expired. Request a new one.';

  @override
  String get errorInvalidPassword => 'Wrong password.';

  @override
  String get errorTooManyAttempts => 'Too many attempts. Try again later.';

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
  String get selectChat => 'Select a chat to start messaging';

  @override
  String get messageHint => 'Message';

  @override
  String get send => 'Send';

  @override
  String get newMessage => 'New message';

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
}
