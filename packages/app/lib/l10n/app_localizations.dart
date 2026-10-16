import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Mollygram'**
  String get appTitle;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @qrTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to Mollygram by QR code'**
  String get qrTitle;

  /// No description provided for @qrStep1.
  ///
  /// In en, this message translates to:
  /// **'Open Telegram on your phone'**
  String get qrStep1;

  /// No description provided for @qrStep2.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings > Devices > Link Desktop Device'**
  String get qrStep2;

  /// No description provided for @qrStep3.
  ///
  /// In en, this message translates to:
  /// **'Point your phone at this screen to confirm login'**
  String get qrStep3;

  /// No description provided for @qrLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the code…'**
  String get qrLoading;

  /// No description provided for @logInByPhone.
  ///
  /// In en, this message translates to:
  /// **'Log in by phone number'**
  String get logInByPhone;

  /// No description provided for @logInByQr.
  ///
  /// In en, this message translates to:
  /// **'Log in by QR code'**
  String get logInByQr;

  /// No description provided for @phoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone number'**
  String get phoneTitle;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your country code and enter your phone number.'**
  String get phoneHint;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumberHint;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @codeHint.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get codeHint;

  /// No description provided for @codeSentApp.
  ///
  /// In en, this message translates to:
  /// **'We have sent the code to the Telegram app on your other device.'**
  String get codeSentApp;

  /// No description provided for @codeSentSms.
  ///
  /// In en, this message translates to:
  /// **'We have sent you a code via SMS.'**
  String get codeSentSms;

  /// No description provided for @codeSentCall.
  ///
  /// In en, this message translates to:
  /// **'We are calling you to dictate the code.'**
  String get codeSentCall;

  /// No description provided for @codeSentOther.
  ///
  /// In en, this message translates to:
  /// **'Enter the code you received.'**
  String get codeSentOther;

  /// No description provided for @passwordTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification'**
  String get passwordTitle;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Your account is protected with an additional password.'**
  String get passwordHint;

  /// No description provided for @passwordHintWithHint.
  ///
  /// In en, this message translates to:
  /// **'Your account is protected with an additional password. Hint: {hint}'**
  String passwordHintWithHint(String hint);

  /// No description provided for @passwordFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordFieldHint;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting Telegram…'**
  String get starting;

  /// No description provided for @unsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish signing up in the official app'**
  String get unsupportedTitle;

  /// No description provided for @unsupportedStep.
  ///
  /// In en, this message translates to:
  /// **'This sign-in step is not supported yet. Finish signing up in the official Telegram app, then try again.'**
  String get unsupportedStep;

  /// No description provided for @errorInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number'**
  String get errorInvalidPhone;

  /// No description provided for @errorInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code'**
  String get errorInvalidCode;

  /// No description provided for @errorCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'The code has expired, request a new one'**
  String get errorCodeExpired;

  /// No description provided for @errorInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get errorInvalidPassword;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts, try again later'**
  String get errorTooManyAttempts;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {message}'**
  String errorGeneric(String message);

  /// No description provided for @missingKeysTitle.
  ///
  /// In en, this message translates to:
  /// **'Telegram API keys are missing'**
  String get missingKeysTitle;

  /// No description provided for @missingKeysHint.
  ///
  /// In en, this message translates to:
  /// **'Build the app with --dart-define-from-file=config/telegram.json. The template is config/telegram.example.json.'**
  String get missingKeysHint;

  /// No description provided for @startFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Telegram could not start'**
  String get startFailedTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @sidebarSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search or {shortcut}'**
  String sidebarSearchHint(String shortcut);

  /// No description provided for @folderAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get folderAll;

  /// No description provided for @noChats.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChats;

  /// No description provided for @connectionWaitingForNetwork.
  ///
  /// In en, this message translates to:
  /// **'Waiting for network…'**
  String get connectionWaitingForNetwork;

  /// No description provided for @connectionConnectingToProxy.
  ///
  /// In en, this message translates to:
  /// **'Connecting to proxy…'**
  String get connectionConnectingToProxy;

  /// No description provided for @connectionConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectionConnecting;

  /// No description provided for @connectionUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get connectionUpdating;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @draftLabel.
  ///
  /// In en, this message translates to:
  /// **'Draft:'**
  String get draftLabel;

  /// No description provided for @newMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newMessage;

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @peopleSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Name or username'**
  String get peopleSearchHint;

  /// No description provided for @recentChats.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentChats;

  /// No description provided for @globalSearch.
  ///
  /// In en, this message translates to:
  /// **'Global search'**
  String get globalSearch;

  /// No description provided for @noContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get noContacts;

  /// No description provided for @presenceOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get presenceOnline;

  /// No description provided for @presenceJustNow.
  ///
  /// In en, this message translates to:
  /// **'last seen just now'**
  String get presenceJustNow;

  /// No description provided for @presenceMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{last seen {count} minute ago} other{last seen {count} minutes ago}}'**
  String presenceMinutes(num count);

  /// No description provided for @presenceToday.
  ///
  /// In en, this message translates to:
  /// **'last seen today at {time}'**
  String presenceToday(Object time);

  /// No description provided for @presenceYesterday.
  ///
  /// In en, this message translates to:
  /// **'last seen yesterday at {time}'**
  String presenceYesterday(Object time);

  /// No description provided for @presenceDate.
  ///
  /// In en, this message translates to:
  /// **'last seen {date}'**
  String presenceDate(Object date);

  /// No description provided for @presenceRecently.
  ///
  /// In en, this message translates to:
  /// **'last seen recently'**
  String get presenceRecently;

  /// No description provided for @presenceLastWeek.
  ///
  /// In en, this message translates to:
  /// **'last seen within a week'**
  String get presenceLastWeek;

  /// No description provided for @presenceLastMonth.
  ///
  /// In en, this message translates to:
  /// **'last seen within a month'**
  String get presenceLastMonth;

  /// No description provided for @presenceLongAgo.
  ///
  /// In en, this message translates to:
  /// **'last seen a long time ago'**
  String get presenceLongAgo;

  /// No description provided for @presenceBot.
  ///
  /// In en, this message translates to:
  /// **'bot'**
  String get presenceBot;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// No description provided for @contactFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get contactFirstName;

  /// No description provided for @contactLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name (optional)'**
  String get contactLastName;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get contactPhone;

  /// No description provided for @contactAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get contactAdd;

  /// No description provided for @contactFirstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a first name'**
  String get contactFirstNameRequired;

  /// No description provided for @contactPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number'**
  String get contactPhoneRequired;

  /// No description provided for @contactNotOnTelegram.
  ///
  /// In en, this message translates to:
  /// **'This number is not on Telegram'**
  String get contactNotOnTelegram;

  /// No description provided for @contactAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the contact. Check the connection and try again.'**
  String get contactAddFailed;

  /// No description provided for @deleteContact.
  ///
  /// In en, this message translates to:
  /// **'Delete contact'**
  String get deleteContact;

  /// No description provided for @deleteContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} from contacts?'**
  String deleteContactTitle(Object name);

  /// No description provided for @deleteContactFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the contact'**
  String get deleteContactFailed;

  /// No description provided for @selectChat.
  ///
  /// In en, this message translates to:
  /// **'Select a chat to start messaging'**
  String get selectChat;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attach;

  /// No description provided for @emoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji and stickers'**
  String get emoji;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record a voice or video message'**
  String get record;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @voiceHoldToRecord.
  ///
  /// In en, this message translates to:
  /// **'Hold to record a voice message'**
  String get voiceHoldToRecord;

  /// No description provided for @voiceReleaseToCancel.
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get voiceReleaseToCancel;

  /// No description provided for @voiceDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete recording'**
  String get voiceDelete;

  /// No description provided for @voiceMicrophoneDenied.
  ///
  /// In en, this message translates to:
  /// **'Mollygram has no access to the microphone.'**
  String get voiceMicrophoneDenied;

  /// No description provided for @voiceOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings'**
  String get voiceOpenSettings;

  /// No description provided for @voiceRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start recording'**
  String get voiceRecordFailed;

  /// No description provided for @voiceSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the voice message'**
  String get voiceSendFailed;

  /// No description provided for @videoHoldToRecord.
  ///
  /// In en, this message translates to:
  /// **'Hold to record a video message'**
  String get videoHoldToRecord;

  /// No description provided for @videoCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Mollygram has no access to the camera.'**
  String get videoCameraDenied;

  /// No description provided for @videoSwitchCamera.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get videoSwitchCamera;

  /// No description provided for @senderYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get senderYou;

  /// No description provided for @previewYou.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String previewYou(String text);

  /// No description provided for @previewPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get previewPhoto;

  /// No description provided for @previewVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get previewVideo;

  /// No description provided for @previewVideoNote.
  ///
  /// In en, this message translates to:
  /// **'Video message'**
  String get previewVideoNote;

  /// No description provided for @previewVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get previewVoiceNote;

  /// No description provided for @transcribe.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get transcribe;

  /// No description provided for @hideTranscript.
  ///
  /// In en, this message translates to:
  /// **'Hide transcript'**
  String get hideTranscript;

  /// No description provided for @transcribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing…'**
  String get transcribing;

  /// No description provided for @transcriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t transcribe this message'**
  String get transcriptionFailed;

  /// No description provided for @previewAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get previewAudio;

  /// No description provided for @previewDocument.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get previewDocument;

  /// No description provided for @previewSticker.
  ///
  /// In en, this message translates to:
  /// **'Sticker'**
  String get previewSticker;

  /// No description provided for @previewAnimation.
  ///
  /// In en, this message translates to:
  /// **'GIF'**
  String get previewAnimation;

  /// No description provided for @previewOther.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get previewOther;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsSectionAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get notificationsSectionAlerts;

  /// No description provided for @notificationsSectionBadge.
  ///
  /// In en, this message translates to:
  /// **'Dock icon'**
  String get notificationsSectionBadge;

  /// No description provided for @notificationsShow.
  ///
  /// In en, this message translates to:
  /// **'Show notifications'**
  String get notificationsShow;

  /// No description provided for @notificationsShowHint.
  ///
  /// In en, this message translates to:
  /// **'Banners appear while Mollygram is in the background. Muted chats stay silent.'**
  String get notificationsShowHint;

  /// No description provided for @notificationsPreview.
  ///
  /// In en, this message translates to:
  /// **'Show message text'**
  String get notificationsPreview;

  /// No description provided for @notificationsPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'When off, a notification only says who wrote.'**
  String get notificationsPreviewHint;

  /// No description provided for @notificationsSound.
  ///
  /// In en, this message translates to:
  /// **'Play sound'**
  String get notificationsSound;

  /// No description provided for @notificationsBadge.
  ///
  /// In en, this message translates to:
  /// **'Show unread count'**
  String get notificationsBadge;

  /// No description provided for @notificationsBadgeMuted.
  ///
  /// In en, this message translates to:
  /// **'Include muted chats'**
  String get notificationsBadgeMuted;

  /// No description provided for @notificationsBadgeMessages.
  ///
  /// In en, this message translates to:
  /// **'Count messages instead of chats'**
  String get notificationsBadgeMessages;

  /// No description provided for @notificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications for Mollygram are turned off in System Settings.'**
  String get notificationsDenied;

  /// No description provided for @notificationsOpenSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings'**
  String get notificationsOpenSystemSettings;

  /// No description provided for @notificationHiddenText.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get notificationHiddenText;

  /// No description provided for @notificationReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get notificationReply;

  /// No description provided for @notificationSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get notificationSend;

  /// No description provided for @notificationReplyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get notificationReplyPlaceholder;

  /// No description provided for @notificationMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get notificationMarkRead;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'The message wasn\'t sent. Try again'**
  String get sendFailed;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages here yet'**
  String get noMessages;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get edited;

  /// No description provided for @forwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarded from {name}'**
  String forwardedFrom(String name);

  /// No description provided for @deletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Deleted message'**
  String get deletedMessage;

  /// No description provided for @deletedMark.
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get deletedMark;

  /// No description provided for @deletedAt.
  ///
  /// In en, this message translates to:
  /// **'Deleted {time}'**
  String deletedAt(String time);

  /// No description provided for @menuEditHistory.
  ///
  /// In en, this message translates to:
  /// **'Edit history'**
  String get menuEditHistory;

  /// No description provided for @editHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit history'**
  String get editHistoryTitle;

  /// No description provided for @editHistoryCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get editHistoryCurrent;

  /// No description provided for @editHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No earlier versions were kept'**
  String get editHistoryEmpty;

  /// No description provided for @loadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingMessage;

  /// No description provided for @unknownSender.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownSender;

  /// No description provided for @hiddenAccount.
  ///
  /// In en, this message translates to:
  /// **'Hidden account'**
  String get hiddenAccount;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @cancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get cancelDownload;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openFile;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @menuReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get menuReply;

  /// No description provided for @menuQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get menuQuote;

  /// No description provided for @menuReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get menuReport;

  /// No description provided for @moreReactions.
  ///
  /// In en, this message translates to:
  /// **'More reactions'**
  String get moreReactions;

  /// No description provided for @reportDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add details'**
  String get reportDetailsTitle;

  /// No description provided for @reportDetailsOptional.
  ///
  /// In en, this message translates to:
  /// **'You can add details, or send the report as it is.'**
  String get reportDetailsOptional;

  /// No description provided for @reportDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'What is wrong with this message?'**
  String get reportDetailsHint;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thank you, the report is on its way.'**
  String get reportSent;

  /// No description provided for @seenBy.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Seen by {count}} other{Seen by {count}}}'**
  String seenBy(int count);

  /// No description provided for @reactedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} reaction} other{{count} reactions}}'**
  String reactedCount(int count);

  /// No description provided for @readAt.
  ///
  /// In en, this message translates to:
  /// **'Read {time}'**
  String readAt(String time);

  /// No description provided for @notReadYet.
  ///
  /// In en, this message translates to:
  /// **'Not read yet'**
  String get notReadYet;

  /// No description provided for @editedAt.
  ///
  /// In en, this message translates to:
  /// **'Edited {time}'**
  String editedAt(String time);

  /// No description provided for @menuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// No description provided for @menuCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get menuCopyText;

  /// No description provided for @menuCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get menuCopyLink;

  /// No description provided for @menuForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get menuForward;

  /// No description provided for @menuChooseChat.
  ///
  /// In en, this message translates to:
  /// **'Choose chat…'**
  String get menuChooseChat;

  /// No description provided for @menuSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get menuSaveAs;

  /// No description provided for @menuSaveToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Save to Downloads'**
  String get menuSaveToDownloads;

  /// No description provided for @menuShowInFinder.
  ///
  /// In en, this message translates to:
  /// **'Show in Finder'**
  String get menuShowInFinder;

  /// No description provided for @menuShowInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get menuShowInFolder;

  /// No description provided for @menuQuickLook.
  ///
  /// In en, this message translates to:
  /// **'Quick Look'**
  String get menuQuickLook;

  /// No description provided for @sendWithoutSound.
  ///
  /// In en, this message translates to:
  /// **'Send without sound'**
  String get sendWithoutSound;

  /// No description provided for @scheduleMessage.
  ///
  /// In en, this message translates to:
  /// **'Schedule message…'**
  String get scheduleMessage;

  /// No description provided for @sendWhenOnline.
  ///
  /// In en, this message translates to:
  /// **'Send when online'**
  String get sendWhenOnline;

  /// No description provided for @scheduledWhenOnline.
  ///
  /// In en, this message translates to:
  /// **'Will be sent when they come online'**
  String get scheduledWhenOnline;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule message'**
  String get scheduleTitle;

  /// No description provided for @scheduleHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the day and the time it goes out.'**
  String get scheduleHint;

  /// No description provided for @scheduleTimeHint.
  ///
  /// In en, this message translates to:
  /// **'HH:MM'**
  String get scheduleTimeHint;

  /// No description provided for @scheduleAction.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleAction;

  /// No description provided for @scheduledList.
  ///
  /// In en, this message translates to:
  /// **'Scheduled messages'**
  String get scheduledList;

  /// No description provided for @scheduledCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} scheduled message} other{{count} scheduled messages}}'**
  String scheduledCount(int count);

  /// No description provided for @menuSendNow.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get menuSendNow;

  /// No description provided for @menuReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule…'**
  String get menuReschedule;

  /// No description provided for @scheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for {date}'**
  String scheduledFor(String date);

  /// No description provided for @menuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get menuDelete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @formatBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get formatBold;

  /// No description provided for @formatItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get formatItalic;

  /// No description provided for @formatUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get formatUnderline;

  /// No description provided for @formatStrikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get formatStrikethrough;

  /// No description provided for @formatMonospace.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get formatMonospace;

  /// No description provided for @formatSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Spoiler'**
  String get formatSpoiler;

  /// No description provided for @formatQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get formatQuote;

  /// No description provided for @formatLink.
  ///
  /// In en, this message translates to:
  /// **'Link…'**
  String get formatLink;

  /// No description provided for @formatPlain.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get formatPlain;

  /// No description provided for @linkTitle.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get linkTitle;

  /// No description provided for @linkHint.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get linkHint;

  /// No description provided for @linkApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get linkApply;

  /// No description provided for @deleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get deleteMessageTitle;

  /// No description provided for @deleteMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Delete {count} message?} other{Delete {count} messages?}}'**
  String deleteMessagesTitle(int count);

  /// No description provided for @deleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get deleteForEveryone;

  /// No description provided for @deleteAlsoFor.
  ///
  /// In en, this message translates to:
  /// **'Also delete for {name}'**
  String deleteAlsoFor(String name);

  /// No description provided for @editingMessage.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get editingMessage;

  /// No description provided for @linkPreviewAboveText.
  ///
  /// In en, this message translates to:
  /// **'Show the preview above the text'**
  String get linkPreviewAboveText;

  /// No description provided for @linkPreviewBelowText.
  ///
  /// In en, this message translates to:
  /// **'Show the preview below the text'**
  String get linkPreviewBelowText;

  /// No description provided for @removeLinkPreview.
  ///
  /// In en, this message translates to:
  /// **'Remove the link preview'**
  String get removeLinkPreview;

  /// No description provided for @forwardTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward to chat'**
  String get forwardTitle;

  /// No description provided for @forwardSearch.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get forwardSearch;

  /// No description provided for @forwardHideSender.
  ///
  /// In en, this message translates to:
  /// **'Hide sender names'**
  String get forwardHideSender;

  /// No description provided for @forwardHideCaptions.
  ///
  /// In en, this message translates to:
  /// **'Hide captions'**
  String get forwardHideCaptions;

  /// No description provided for @forwardComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get forwardComment;

  /// No description provided for @noChatsFound.
  ///
  /// In en, this message translates to:
  /// **'No chats found'**
  String get noChatsFound;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get statusOnline;

  /// No description provided for @statusJustNow.
  ///
  /// In en, this message translates to:
  /// **'last seen just now'**
  String get statusJustNow;

  /// No description provided for @statusMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{last seen {count} minute ago} other{last seen {count} minutes ago}}'**
  String statusMinutesAgo(int count);

  /// No description provided for @statusToday.
  ///
  /// In en, this message translates to:
  /// **'last seen today at {time}'**
  String statusToday(String time);

  /// No description provided for @statusYesterday.
  ///
  /// In en, this message translates to:
  /// **'last seen yesterday at {time}'**
  String statusYesterday(String time);

  /// No description provided for @statusOnDate.
  ///
  /// In en, this message translates to:
  /// **'last seen {date}'**
  String statusOnDate(String date);

  /// No description provided for @statusRecently.
  ///
  /// In en, this message translates to:
  /// **'last seen recently'**
  String get statusRecently;

  /// No description provided for @statusLastWeek.
  ///
  /// In en, this message translates to:
  /// **'last seen within a week'**
  String get statusLastWeek;

  /// No description provided for @statusLastMonth.
  ///
  /// In en, this message translates to:
  /// **'last seen within a month'**
  String get statusLastMonth;

  /// No description provided for @statusLongAgo.
  ///
  /// In en, this message translates to:
  /// **'last seen a long time ago'**
  String get statusLongAgo;

  /// No description provided for @statusBot.
  ///
  /// In en, this message translates to:
  /// **'bot'**
  String get statusBot;

  /// No description provided for @statusService.
  ///
  /// In en, this message translates to:
  /// **'service notifications'**
  String get statusService;

  /// No description provided for @statusGroup.
  ///
  /// In en, this message translates to:
  /// **'group'**
  String get statusGroup;

  /// No description provided for @statusChannel.
  ///
  /// In en, this message translates to:
  /// **'channel'**
  String get statusChannel;

  /// No description provided for @statusMembers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} member} other{{count} members}}'**
  String statusMembers(int count);

  /// No description provided for @statusMembersOnline.
  ///
  /// In en, this message translates to:
  /// **'{members}, {online} online'**
  String statusMembersOnline(String members, String online);

  /// No description provided for @statusSubscribers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} subscriber} other{{count} subscribers}}'**
  String statusSubscribers(int count);

  /// No description provided for @activityTyping.
  ///
  /// In en, this message translates to:
  /// **'typing'**
  String get activityTyping;

  /// No description provided for @activityRecordingVoice.
  ///
  /// In en, this message translates to:
  /// **'recording a voice message'**
  String get activityRecordingVoice;

  /// No description provided for @activityRecordingVideoNote.
  ///
  /// In en, this message translates to:
  /// **'recording a video message'**
  String get activityRecordingVideoNote;

  /// No description provided for @activityRecordingVideo.
  ///
  /// In en, this message translates to:
  /// **'recording a video'**
  String get activityRecordingVideo;

  /// No description provided for @activitySendingPhoto.
  ///
  /// In en, this message translates to:
  /// **'sending a photo'**
  String get activitySendingPhoto;

  /// No description provided for @activitySendingVideo.
  ///
  /// In en, this message translates to:
  /// **'sending a video'**
  String get activitySendingVideo;

  /// No description provided for @activitySendingVoice.
  ///
  /// In en, this message translates to:
  /// **'sending a voice message'**
  String get activitySendingVoice;

  /// No description provided for @activitySendingVideoNote.
  ///
  /// In en, this message translates to:
  /// **'sending a video message'**
  String get activitySendingVideoNote;

  /// No description provided for @activitySendingFile.
  ///
  /// In en, this message translates to:
  /// **'sending a file'**
  String get activitySendingFile;

  /// No description provided for @activityChoosingSticker.
  ///
  /// In en, this message translates to:
  /// **'choosing a sticker'**
  String get activityChoosingSticker;

  /// No description provided for @activityChoosingLocation.
  ///
  /// In en, this message translates to:
  /// **'choosing a location'**
  String get activityChoosingLocation;

  /// No description provided for @activityChoosingContact.
  ///
  /// In en, this message translates to:
  /// **'choosing a contact'**
  String get activityChoosingContact;

  /// No description provided for @activityPlayingGame.
  ///
  /// In en, this message translates to:
  /// **'playing a game'**
  String get activityPlayingGame;

  /// No description provided for @activityWatchingAnimations.
  ///
  /// In en, this message translates to:
  /// **'watching an animation'**
  String get activityWatchingAnimations;

  /// No description provided for @activityByOne.
  ///
  /// In en, this message translates to:
  /// **'{name} is {activity}'**
  String activityByOne(String name, String activity);

  /// No description provided for @activityByTwo.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second} are typing'**
  String activityByTwo(String first, String second);

  /// No description provided for @activityByMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{name} and {count} other are typing} other{{name} and {count} others are typing}}'**
  String activityByMany(String name, int count);

  /// No description provided for @archivedChats.
  ///
  /// In en, this message translates to:
  /// **'Archived chats'**
  String get archivedChats;

  /// No description provided for @noArchivedChats.
  ///
  /// In en, this message translates to:
  /// **'No archived chats'**
  String get noArchivedChats;

  /// No description provided for @menuPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get menuPin;

  /// No description provided for @menuUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get menuUnpin;

  /// No description provided for @menuMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get menuMute;

  /// No description provided for @menuUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get menuUnmute;

  /// No description provided for @muteFor1Hour.
  ///
  /// In en, this message translates to:
  /// **'For 1 hour'**
  String get muteFor1Hour;

  /// No description provided for @muteFor8Hours.
  ///
  /// In en, this message translates to:
  /// **'For 8 hours'**
  String get muteFor8Hours;

  /// No description provided for @muteFor3Days.
  ///
  /// In en, this message translates to:
  /// **'For 3 days'**
  String get muteFor3Days;

  /// No description provided for @muteForever.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get muteForever;

  /// No description provided for @menuArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get menuArchive;

  /// No description provided for @menuUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get menuUnarchive;

  /// No description provided for @menuMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get menuMarkRead;

  /// No description provided for @menuMarkUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark as unread'**
  String get menuMarkUnread;

  /// No description provided for @menuMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get menuMarkAllRead;

  /// No description provided for @menuHideArchive.
  ///
  /// In en, this message translates to:
  /// **'Hide archive'**
  String get menuHideArchive;

  /// No description provided for @menuShowArchive.
  ///
  /// In en, this message translates to:
  /// **'Show archive'**
  String get menuShowArchive;

  /// No description provided for @showArchiveRow.
  ///
  /// In en, this message translates to:
  /// **'Archive in the chat list'**
  String get showArchiveRow;

  /// No description provided for @showArchiveRowHint.
  ///
  /// In en, this message translates to:
  /// **'Archived chats stay in the rail and in search while the row is hidden.'**
  String get showArchiveRowHint;

  /// No description provided for @menuClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get menuClearHistory;

  /// No description provided for @menuDeleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get menuDeleteChat;

  /// No description provided for @menuDeleteAndLeave.
  ///
  /// In en, this message translates to:
  /// **'Delete and leave'**
  String get menuDeleteAndLeave;

  /// No description provided for @menuLeaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get menuLeaveGroup;

  /// No description provided for @menuLeaveChannel.
  ///
  /// In en, this message translates to:
  /// **'Leave channel'**
  String get menuLeaveChannel;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Messages in {name} will be deleted for you.'**
  String clearHistoryMessage(String name);

  /// No description provided for @clearAlsoFor.
  ///
  /// In en, this message translates to:
  /// **'Also clear for {name}'**
  String clearAlsoFor(String name);

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @deleteChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get deleteChatTitle;

  /// No description provided for @deleteChatMessage.
  ///
  /// In en, this message translates to:
  /// **'The chat with {name} will be deleted for you.'**
  String deleteChatMessage(String name);

  /// No description provided for @leaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}?'**
  String leaveTitle(String name);

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @deleteAndLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete and leave {name}?'**
  String deleteAndLeaveTitle(String name);

  /// No description provided for @chatActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t do that, try again'**
  String get chatActionFailed;

  /// No description provided for @editFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the changes'**
  String get editFailed;

  /// No description provided for @attachTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Send {count} file} other{Send {count} files}}'**
  String attachTitle(int count);

  /// No description provided for @attachPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Send {count} photo} other{Send {count} photos}}'**
  String attachPhotosTitle(int count);

  /// No description provided for @attachAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add more'**
  String get attachAddMore;

  /// No description provided for @groupAlbum.
  ///
  /// In en, this message translates to:
  /// **'Group as an album'**
  String get groupAlbum;

  /// No description provided for @removeFromSend.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeFromSend;

  /// No description provided for @sendAsFiles.
  ///
  /// In en, this message translates to:
  /// **'Send as files'**
  String get sendAsFiles;

  /// No description provided for @hideWithSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Hide with a spoiler'**
  String get hideWithSpoiler;

  /// No description provided for @viewOnce.
  ///
  /// In en, this message translates to:
  /// **'View once'**
  String get viewOnce;

  /// No description provided for @captionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a caption'**
  String get captionHint;

  /// No description provided for @dropFiles.
  ///
  /// In en, this message translates to:
  /// **'Drop files here to send them'**
  String get dropFiles;

  /// No description provided for @attachFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the files'**
  String get attachFailed;

  /// No description provided for @hiddenMedia.
  ///
  /// In en, this message translates to:
  /// **'Hidden media, tap to show'**
  String get hiddenMedia;

  /// No description provided for @spoilerMedia.
  ///
  /// In en, this message translates to:
  /// **'Spoiler'**
  String get spoilerMedia;

  /// No description provided for @secretMedia.
  ///
  /// In en, this message translates to:
  /// **'Tap to view'**
  String get secretMedia;

  /// No description provided for @sensitiveMedia.
  ///
  /// In en, this message translates to:
  /// **'18+'**
  String get sensitiveMedia;

  /// No description provided for @forwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t forward the message'**
  String get forwardFailed;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @peerInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get peerInfo;

  /// No description provided for @lastSeenJustNow.
  ///
  /// In en, this message translates to:
  /// **'last seen just now'**
  String get lastSeenJustNow;

  /// No description provided for @lastSeenMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{last seen 1 minute ago} other{last seen {count} minutes ago}}'**
  String lastSeenMinutesAgo(int count);

  /// No description provided for @lastSeenToday.
  ///
  /// In en, this message translates to:
  /// **'last seen today at {time}'**
  String lastSeenToday(String time);

  /// No description provided for @lastSeenYesterday.
  ///
  /// In en, this message translates to:
  /// **'last seen yesterday at {time}'**
  String lastSeenYesterday(String time);

  /// No description provided for @lastSeenDate.
  ///
  /// In en, this message translates to:
  /// **'last seen {date}'**
  String lastSeenDate(String date);

  /// No description provided for @lastSeenRecently.
  ///
  /// In en, this message translates to:
  /// **'last seen recently'**
  String get lastSeenRecently;

  /// No description provided for @lastSeenWeek.
  ///
  /// In en, this message translates to:
  /// **'last seen within a week'**
  String get lastSeenWeek;

  /// No description provided for @lastSeenMonth.
  ///
  /// In en, this message translates to:
  /// **'last seen within a month'**
  String get lastSeenMonth;

  /// No description provided for @lastSeenLongAgo.
  ///
  /// In en, this message translates to:
  /// **'last seen a long time ago'**
  String get lastSeenLongAgo;

  /// No description provided for @deletedAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleted account'**
  String get deletedAccount;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no members} =1{1 member} other{{count} members}}'**
  String membersCount(int count);

  /// No description provided for @subscribersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no subscribers} =1{1 subscriber} other{{count} subscribers}}'**
  String subscribersCount(int count);

  /// No description provided for @infoBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get infoBio;

  /// No description provided for @infoUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get infoUsername;

  /// No description provided for @infoPhone.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get infoPhone;

  /// No description provided for @infoBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get infoBirthday;

  /// No description provided for @infoDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get infoDescription;

  /// No description provided for @infoLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get infoLink;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @infoMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get infoMessage;

  /// No description provided for @infoMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get infoMute;

  /// No description provided for @infoUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get infoUnmute;

  /// No description provided for @muteForHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{For 1 hour} other{For {count} hours}}'**
  String muteForHours(int count);

  /// No description provided for @muteForDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{For 1 day} other{For {count} days}}'**
  String muteForDays(int count);

  /// No description provided for @muteUntilEnabled.
  ///
  /// In en, this message translates to:
  /// **'Until I turn it back on'**
  String get muteUntilEnabled;

  /// No description provided for @autoDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete messages'**
  String get autoDeleteTitle;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get blockUser;

  /// No description provided for @infoShareContact.
  ///
  /// In en, this message translates to:
  /// **'Share contact'**
  String get infoShareContact;

  /// No description provided for @unblockUser.
  ///
  /// In en, this message translates to:
  /// **'Unblock user'**
  String get unblockUser;

  /// No description provided for @blockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockConfirmTitle(String name);

  /// No description provided for @blockConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to send you messages or call you.'**
  String get blockConfirmMessage;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @memberOwner.
  ///
  /// In en, this message translates to:
  /// **'owner'**
  String get memberOwner;

  /// No description provided for @memberAdmin.
  ///
  /// In en, this message translates to:
  /// **'admin'**
  String get memberAdmin;

  /// No description provided for @infoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the info'**
  String get infoFailed;

  /// No description provided for @fileSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{size} B'**
  String fileSizeBytes(String size);

  /// No description provided for @fileSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String fileSizeKb(String size);

  /// No description provided for @fileSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String fileSizeMb(String size);

  /// No description provided for @fileSizeGb.
  ///
  /// In en, this message translates to:
  /// **'{size} GB'**
  String fileSizeGb(String size);

  /// No description provided for @fileProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String fileProgress(String done, String total);

  /// No description provided for @contentLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get contentLocation;

  /// No description provided for @contentLiveLocation.
  ///
  /// In en, this message translates to:
  /// **'Live location'**
  String get contentLiveLocation;

  /// No description provided for @liveLocationEnded.
  ///
  /// In en, this message translates to:
  /// **'Live location ended'**
  String get liveLocationEnded;

  /// No description provided for @liveMinutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min left'**
  String liveMinutesLeft(int minutes);

  /// No description provided for @liveHoursLeft.
  ///
  /// In en, this message translates to:
  /// **'{hours} h left'**
  String liveHoursLeft(int hours);

  /// No description provided for @contentContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contentContact;

  /// No description provided for @contentPoll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get contentPoll;

  /// No description provided for @contentQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get contentQuiz;

  /// No description provided for @pollVotes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No votes} =1{1 vote} other{{count} votes}}'**
  String pollVotes(int count);

  /// No description provided for @pollAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous poll'**
  String get pollAnonymous;

  /// No description provided for @pollAnonymousQuiz.
  ///
  /// In en, this message translates to:
  /// **'Anonymous quiz'**
  String get pollAnonymousQuiz;

  /// No description provided for @pollFinalResults.
  ///
  /// In en, this message translates to:
  /// **'Final results'**
  String get pollFinalResults;

  /// No description provided for @pollVote.
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get pollVote;

  /// No description provided for @pollRetractVote.
  ///
  /// In en, this message translates to:
  /// **'Retract vote'**
  String get pollRetractVote;

  /// No description provided for @quizAnswers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nobody answered yet} =1{1 answered} other{{count} answered}}'**
  String quizAnswers(int count);

  /// No description provided for @menuStopPoll.
  ///
  /// In en, this message translates to:
  /// **'Stop poll'**
  String get menuStopPoll;

  /// No description provided for @stopPollTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop this poll?'**
  String get stopPollTitle;

  /// No description provided for @stopPollMessage.
  ///
  /// In en, this message translates to:
  /// **'Nobody will be able to vote in it any more.'**
  String get stopPollMessage;

  /// No description provided for @botMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get botMenu;

  /// No description provided for @webAppUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the bot\'s app'**
  String get webAppUnavailable;

  /// No description provided for @sendAs.
  ///
  /// In en, this message translates to:
  /// **'Send as'**
  String get sendAs;

  /// No description provided for @sendAsPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal account'**
  String get sendAsPersonal;

  /// No description provided for @sendAsChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get sendAsChannel;

  /// No description provided for @sendAsPremium.
  ///
  /// In en, this message translates to:
  /// **'Telegram Premium'**
  String get sendAsPremium;

  /// No description provided for @botKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Bot keyboard'**
  String get botKeyboard;

  /// No description provided for @botNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'The bot did not answer'**
  String get botNoAnswer;

  /// No description provided for @sharePhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your phone number?'**
  String get sharePhoneTitle;

  /// No description provided for @sharePhoneMessage.
  ///
  /// In en, this message translates to:
  /// **'{bot} will receive the phone number of your account.'**
  String sharePhoneMessage(String bot);

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @attachFile.
  ///
  /// In en, this message translates to:
  /// **'File…'**
  String get attachFile;

  /// No description provided for @attachPoll.
  ///
  /// In en, this message translates to:
  /// **'Poll…'**
  String get attachPoll;

  /// No description provided for @attachContact.
  ///
  /// In en, this message translates to:
  /// **'Contact…'**
  String get attachContact;

  /// No description provided for @sendContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Send contact'**
  String get sendContactTitle;

  /// No description provided for @attachLocation.
  ///
  /// In en, this message translates to:
  /// **'Location…'**
  String get attachLocation;

  /// No description provided for @sendLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Send location'**
  String get sendLocationTitle;

  /// No description provided for @locationSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Place, address or coordinates'**
  String get locationSearchHint;

  /// No description provided for @locationStartHint.
  ///
  /// In en, this message translates to:
  /// **'Enter coordinates or paste a map link to pick a place, then search for venues around it'**
  String get locationStartHint;

  /// No description provided for @sendThisLocation.
  ///
  /// In en, this message translates to:
  /// **'Send this location'**
  String get sendThisLocation;

  /// No description provided for @mapZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get mapZoomIn;

  /// No description provided for @mapZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get mapZoomOut;

  /// No description provided for @newPollTitle.
  ///
  /// In en, this message translates to:
  /// **'New poll'**
  String get newPollTitle;

  /// No description provided for @newQuizTitle.
  ///
  /// In en, this message translates to:
  /// **'New quiz'**
  String get newQuizTitle;

  /// No description provided for @pollQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get pollQuestionHint;

  /// No description provided for @pollOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get pollOptionsTitle;

  /// No description provided for @pollOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add an option'**
  String get pollOptionHint;

  /// No description provided for @pollRemoveOption.
  ///
  /// In en, this message translates to:
  /// **'Remove option'**
  String get pollRemoveOption;

  /// No description provided for @pollCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get pollCorrectAnswer;

  /// No description provided for @pollAnonymousVoting.
  ///
  /// In en, this message translates to:
  /// **'Anonymous voting'**
  String get pollAnonymousVoting;

  /// No description provided for @pollMultipleAnswers.
  ///
  /// In en, this message translates to:
  /// **'Multiple answers'**
  String get pollMultipleAnswers;

  /// No description provided for @pollQuizMode.
  ///
  /// In en, this message translates to:
  /// **'Quiz mode'**
  String get pollQuizMode;

  /// No description provided for @pollExplanationHint.
  ///
  /// In en, this message translates to:
  /// **'Explanation (optional)'**
  String get pollExplanationHint;

  /// No description provided for @pollQuizHint.
  ///
  /// In en, this message translates to:
  /// **'Mark the correct answer; voters see the explanation after answering.'**
  String get pollQuizHint;

  /// No description provided for @pollCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get pollCreate;

  /// No description provided for @startBot.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startBot;

  /// No description provided for @contentGame.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get contentGame;

  /// No description provided for @contentInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get contentInvoice;

  /// No description provided for @contentStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get contentStory;

  /// No description provided for @contentChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get contentChecklist;

  /// No description provided for @checklistProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} completed'**
  String checklistProgress(int done, int total);

  /// No description provided for @contentGiveaway.
  ///
  /// In en, this message translates to:
  /// **'Giveaway'**
  String get contentGiveaway;

  /// No description provided for @contentPaidMedia.
  ///
  /// In en, this message translates to:
  /// **'Paid media'**
  String get contentPaidMedia;

  /// No description provided for @contentExpiredPhoto.
  ///
  /// In en, this message translates to:
  /// **'The photo has expired'**
  String get contentExpiredPhoto;

  /// No description provided for @contentExpiredVideo.
  ///
  /// In en, this message translates to:
  /// **'The video has expired'**
  String get contentExpiredVideo;

  /// No description provided for @contentExpiredVideoNote.
  ///
  /// In en, this message translates to:
  /// **'The video message has expired'**
  String get contentExpiredVideoNote;

  /// No description provided for @contentExpiredVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'The voice message has expired'**
  String get contentExpiredVoiceNote;

  /// No description provided for @contentUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This message isn\'t supported in Mollygram yet'**
  String get contentUnsupported;

  /// No description provided for @callOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing call'**
  String get callOutgoing;

  /// No description provided for @callIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get callIncoming;

  /// No description provided for @callVideoOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing video call'**
  String get callVideoOutgoing;

  /// No description provided for @callVideoIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get callVideoIncoming;

  /// No description provided for @callMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed call'**
  String get callMissed;

  /// No description provided for @callDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined call'**
  String get callDeclined;

  /// No description provided for @callCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled call'**
  String get callCancelled;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min} other{{count} min}}'**
  String durationMinutes(int count);

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count} s'**
  String durationSeconds(int count);

  /// No description provided for @serviceGroupCreated.
  ///
  /// In en, this message translates to:
  /// **'{name} created the group «{title}»'**
  String serviceGroupCreated(String name, String title);

  /// No description provided for @serviceChannelCreated.
  ///
  /// In en, this message translates to:
  /// **'Channel created'**
  String get serviceChannelCreated;

  /// No description provided for @serviceTitleChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} changed the group name to «{title}»'**
  String serviceTitleChanged(String name, String title);

  /// No description provided for @serviceChannelTitleChanged.
  ///
  /// In en, this message translates to:
  /// **'Channel name changed to «{title}»'**
  String serviceChannelTitleChanged(String title);

  /// No description provided for @servicePhotoChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} updated the group photo'**
  String servicePhotoChanged(String name);

  /// No description provided for @serviceChannelPhotoChanged.
  ///
  /// In en, this message translates to:
  /// **'Channel photo updated'**
  String get serviceChannelPhotoChanged;

  /// No description provided for @servicePhotoRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed the group photo'**
  String servicePhotoRemoved(String name);

  /// No description provided for @serviceChannelPhotoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Channel photo removed'**
  String get serviceChannelPhotoRemoved;

  /// No description provided for @serviceJoined.
  ///
  /// In en, this message translates to:
  /// **'{name} joined the group'**
  String serviceJoined(String name);

  /// No description provided for @serviceAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added {members}'**
  String serviceAdded(String name, String members);

  /// No description provided for @serviceJoinedByLink.
  ///
  /// In en, this message translates to:
  /// **'{name} joined the group via invite link'**
  String serviceJoinedByLink(String name);

  /// No description provided for @serviceJoinedByRequest.
  ///
  /// In en, this message translates to:
  /// **'{name} was accepted to the group'**
  String serviceJoinedByRequest(String name);

  /// No description provided for @serviceLeft.
  ///
  /// In en, this message translates to:
  /// **'{name} left the group'**
  String serviceLeft(String name);

  /// No description provided for @serviceRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed {member}'**
  String serviceRemoved(String name, String member);

  /// No description provided for @servicePinned.
  ///
  /// In en, this message translates to:
  /// **'{name} pinned «{text}»'**
  String servicePinned(String name, String text);

  /// No description provided for @servicePinnedMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} pinned a message'**
  String servicePinnedMessage(String name);

  /// No description provided for @serviceScreenshot.
  ///
  /// In en, this message translates to:
  /// **'{name} took a screenshot'**
  String serviceScreenshot(String name);

  /// No description provided for @serviceAutoDeleteOn.
  ///
  /// In en, this message translates to:
  /// **'{name} set messages to auto-delete after {time}'**
  String serviceAutoDeleteOn(String name, String time);

  /// No description provided for @serviceAutoDeleteOff.
  ///
  /// In en, this message translates to:
  /// **'{name} turned off auto-delete'**
  String serviceAutoDeleteOff(String name);

  /// No description provided for @serviceUpgraded.
  ///
  /// In en, this message translates to:
  /// **'The group was upgraded to a supergroup'**
  String get serviceUpgraded;

  /// No description provided for @serviceVideoChatStarted.
  ///
  /// In en, this message translates to:
  /// **'{name} started a video chat'**
  String serviceVideoChatStarted(String name);

  /// No description provided for @serviceVideoChatEnded.
  ///
  /// In en, this message translates to:
  /// **'Video chat ended ({duration})'**
  String serviceVideoChatEnded(String duration);

  /// No description provided for @serviceVideoChatScheduled.
  ///
  /// In en, this message translates to:
  /// **'Video chat scheduled'**
  String get serviceVideoChatScheduled;

  /// No description provided for @serviceVideoChatInvited.
  ///
  /// In en, this message translates to:
  /// **'{name} invited {members} to the video chat'**
  String serviceVideoChatInvited(String name, String members);

  /// No description provided for @serviceTopicCreated.
  ///
  /// In en, this message translates to:
  /// **'Topic «{title}» created'**
  String serviceTopicCreated(String title);

  /// No description provided for @serviceTopicEdited.
  ///
  /// In en, this message translates to:
  /// **'{name} changed the topic'**
  String serviceTopicEdited(String name);

  /// No description provided for @serviceContactJoined.
  ///
  /// In en, this message translates to:
  /// **'{name} joined Telegram'**
  String serviceContactJoined(String name);

  /// No description provided for @serviceThemeChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} changed the chat theme'**
  String serviceThemeChanged(String name);

  /// No description provided for @serviceBackgroundChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} changed the chat wallpaper'**
  String serviceBackgroundChanged(String name);

  /// No description provided for @serviceGift.
  ///
  /// In en, this message translates to:
  /// **'{name} sent a gift'**
  String serviceGift(String name);

  /// No description provided for @servicePayment.
  ///
  /// In en, this message translates to:
  /// **'Payment completed'**
  String get servicePayment;

  /// No description provided for @serviceBoost.
  ///
  /// In en, this message translates to:
  /// **'{name} boosted the group'**
  String serviceBoost(String name);

  /// No description provided for @serviceGameScore.
  ///
  /// In en, this message translates to:
  /// **'{name} scored {score}'**
  String serviceGameScore(String name, int score);

  /// No description provided for @serviceOther.
  ///
  /// In en, this message translates to:
  /// **'{name} performed an action that Mollygram can\'t show yet'**
  String serviceOther(String name);

  /// No description provided for @listSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String durationHours(int count);

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String durationDays(int count);

  /// No description provided for @durationWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String durationWeeks(int count);

  /// No description provided for @durationMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String durationMonths(int count);

  /// No description provided for @plugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get plugins;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get settingsSearch;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get myProfile;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @bioHint.
  ///
  /// In en, this message translates to:
  /// **'Any details such as age, occupation or city.'**
  String get bioHint;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'People can find you by this username and contact you without knowing your phone number. You can use a–z, 0–9 and underscores, at least 5 characters.'**
  String get usernameHint;

  /// No description provided for @usernameTooShort.
  ///
  /// In en, this message translates to:
  /// **'A username must have at least 5 characters.'**
  String get usernameTooShort;

  /// No description provided for @usernameTooLong.
  ///
  /// In en, this message translates to:
  /// **'A username can\'t be longer than 32 characters.'**
  String get usernameTooLong;

  /// No description provided for @usernameInvalidCharacter.
  ///
  /// In en, this message translates to:
  /// **'Only a–z, 0–9 and underscores are allowed.'**
  String get usernameInvalidCharacter;

  /// No description provided for @usernameStartsWithLetter.
  ///
  /// In en, this message translates to:
  /// **'A username must start with a letter.'**
  String get usernameStartsWithLetter;

  /// No description provided for @usernameEndsWithUnderscore.
  ///
  /// In en, this message translates to:
  /// **'A username can\'t end with an underscore.'**
  String get usernameEndsWithUnderscore;

  /// No description provided for @usernameChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get usernameChecking;

  /// No description provided for @usernameAvailable.
  ///
  /// In en, this message translates to:
  /// **'@{name} is available.'**
  String usernameAvailable(String name);

  /// No description provided for @usernameOccupied.
  ///
  /// In en, this message translates to:
  /// **'This username is already taken.'**
  String get usernameOccupied;

  /// No description provided for @usernamePurchasable.
  ///
  /// In en, this message translates to:
  /// **'This username is for sale on Fragment.'**
  String get usernamePurchasable;

  /// No description provided for @usernameUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This username can\'t be used.'**
  String get usernameUnavailable;

  /// No description provided for @firstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'A first name is required.'**
  String get firstNameRequired;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the change.'**
  String get saveFailed;

  /// No description provided for @profileFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile.'**
  String get profileFailed;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @logOutButton.
  ///
  /// In en, this message translates to:
  /// **'Log out…'**
  String get logOutButton;

  /// No description provided for @logOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out of Telegram?'**
  String get logOutTitle;

  /// No description provided for @logOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Your chats and media will be removed from this computer. They stay in the Telegram cloud.'**
  String get logOutMessage;

  /// No description provided for @privacyAndSecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get privacyAndSecurity;

  /// No description provided for @activeSessions.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get activeSessions;

  /// No description provided for @activeSessionsHint.
  ///
  /// In en, this message translates to:
  /// **'Devices and apps signed in to your account.'**
  String get activeSessionsHint;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @otherSessions.
  ///
  /// In en, this message translates to:
  /// **'Other sessions'**
  String get otherSessions;

  /// No description provided for @noOtherSessions.
  ///
  /// In en, this message translates to:
  /// **'You\'re signed in on this device only.'**
  String get noOtherSessions;

  /// No description provided for @sessionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the sessions.'**
  String get sessionsFailed;

  /// No description provided for @sessionOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get sessionOnline;

  /// No description provided for @sessionUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'New sign-in'**
  String get sessionUnconfirmed;

  /// No description provided for @terminate.
  ///
  /// In en, this message translates to:
  /// **'Terminate'**
  String get terminate;

  /// No description provided for @terminateSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminate this session?'**
  String get terminateSessionTitle;

  /// No description provided for @terminateOthers.
  ///
  /// In en, this message translates to:
  /// **'Terminate all other sessions'**
  String get terminateOthers;

  /// No description provided for @terminateOthersHint.
  ///
  /// In en, this message translates to:
  /// **'Logs out every device except this one.'**
  String get terminateOthersHint;

  /// No description provided for @terminateOthersTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminate all other sessions?'**
  String get terminateOthersTitle;

  /// No description provided for @logOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t log out. Check the connection and try again.'**
  String get logOutFailed;

  /// No description provided for @connectedBot.
  ///
  /// In en, this message translates to:
  /// **'Connected business bot'**
  String get connectedBot;

  /// No description provided for @connectedBotFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the connected bot'**
  String get connectedBotFailed;

  /// No description provided for @connectedBotHint.
  ///
  /// In en, this message translates to:
  /// **'This bot can read and answer your business chats.'**
  String get connectedBotHint;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @disconnectBotTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect {name}?'**
  String disconnectBotTitle(String name);

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @accentViolet.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get accentViolet;

  /// No description provided for @accentBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get accentBlue;

  /// No description provided for @accentIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get accentIndigo;

  /// No description provided for @accentTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get accentTeal;

  /// No description provided for @accentGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get accentGreen;

  /// No description provided for @accentOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentGraphite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get accentGraphite;

  /// No description provided for @chatWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Chat wallpaper'**
  String get chatWallpaper;

  /// No description provided for @chatWallpaperHint.
  ///
  /// In en, this message translates to:
  /// **'When off, chats sit on a plain background.'**
  String get chatWallpaperHint;

  /// No description provided for @messageTextSize.
  ///
  /// In en, this message translates to:
  /// **'Message text size'**
  String get messageTextSize;

  /// No description provided for @textSizeValue.
  ///
  /// In en, this message translates to:
  /// **'{size} pt'**
  String textSizeValue(String size);

  /// No description provided for @previewSender.
  ///
  /// In en, this message translates to:
  /// **'Anna'**
  String get previewSender;

  /// No description provided for @previewMessage.
  ///
  /// In en, this message translates to:
  /// **'Good morning! The new settings look great.'**
  String get previewMessage;

  /// No description provided for @reduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get reduceMotion;

  /// No description provided for @reduceMotionHint.
  ///
  /// In en, this message translates to:
  /// **'Turns animations off. Mollygram also follows the same setting in macOS Accessibility.'**
  String get reduceMotionHint;

  /// No description provided for @dataAndStorage.
  ///
  /// In en, this message translates to:
  /// **'Data and storage'**
  String get dataAndStorage;

  /// No description provided for @storageUsage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storageUsage;

  /// No description provided for @storageCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get storageCalculating;

  /// No description provided for @storageUsed.
  ///
  /// In en, this message translates to:
  /// **'{size} of media and files'**
  String storageUsed(String size);

  /// No description provided for @storageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No media or files are stored on this computer.'**
  String get storageEmpty;

  /// No description provided for @storagePhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get storagePhotos;

  /// No description provided for @storageVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get storageVideos;

  /// No description provided for @storageFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get storageFiles;

  /// No description provided for @storageVoiceAndMusic.
  ///
  /// In en, this message translates to:
  /// **'Voice and music'**
  String get storageVoiceAndMusic;

  /// No description provided for @storageStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get storageStickers;

  /// No description provided for @storageOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get storageOther;

  /// No description provided for @storageDatabase.
  ///
  /// In en, this message translates to:
  /// **'Message database'**
  String get storageDatabase;

  /// No description provided for @storageHint.
  ///
  /// In en, this message translates to:
  /// **'Cleared media stays in the Telegram cloud and downloads again when needed. Messages are kept.'**
  String get storageHint;

  /// No description provided for @storageFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the storage usage.'**
  String get storageFailed;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache…'**
  String get clearCache;

  /// No description provided for @clearCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear {size} from this computer?'**
  String clearCacheTitle(String size);

  /// No description provided for @clearCacheMessage.
  ///
  /// In en, this message translates to:
  /// **'Media stays in the Telegram cloud and downloads again when you open it.'**
  String get clearCacheMessage;

  /// No description provided for @clearCacheFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t clear the cache.'**
  String get clearCacheFailed;

  /// No description provided for @autoDownload.
  ///
  /// In en, this message translates to:
  /// **'Automatic media download'**
  String get autoDownload;

  /// No description provided for @autoDownloadWifi.
  ///
  /// In en, this message translates to:
  /// **'On Wi-Fi and Ethernet'**
  String get autoDownloadWifi;

  /// No description provided for @autoDownloadOther.
  ///
  /// In en, this message translates to:
  /// **'On other networks'**
  String get autoDownloadOther;

  /// No description provided for @autoDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'Other networks are personal hotspots and other metered connections.'**
  String get autoDownloadHint;

  /// No description provided for @downloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get downloadFolder;

  /// No description provided for @downloadFolderDefault.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadFolderDefault;

  /// No description provided for @chooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get chooseFolder;

  /// No description provided for @downloadFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Files you save from chats go here.'**
  String get downloadFolderHint;

  /// No description provided for @sizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{size} B'**
  String sizeBytes(String size);

  /// No description provided for @sizeKilobytes.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String sizeKilobytes(String size);

  /// No description provided for @sizeMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String sizeMegabytes(String size);

  /// No description provided for @sizeGigabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} GB'**
  String sizeGigabytes(String size);

  /// No description provided for @emojiTab.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get emojiTab;

  /// No description provided for @stickersTab.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get stickersTab;

  /// No description provided for @gifsTab.
  ///
  /// In en, this message translates to:
  /// **'GIFs'**
  String get gifsTab;

  /// No description provided for @customEmojiTab.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customEmojiTab;

  /// No description provided for @emojiSearch.
  ///
  /// In en, this message translates to:
  /// **'Search emoji'**
  String get emojiSearch;

  /// No description provided for @recentlyUsed.
  ///
  /// In en, this message translates to:
  /// **'Recently used'**
  String get recentlyUsed;

  /// No description provided for @noEmojiFound.
  ///
  /// In en, this message translates to:
  /// **'No emoji found'**
  String get noEmojiFound;

  /// No description provided for @stickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search stickers'**
  String get stickerSearch;

  /// No description provided for @noStickersFound.
  ///
  /// In en, this message translates to:
  /// **'No stickers found'**
  String get noStickersFound;

  /// No description provided for @stickerSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get stickerSearchResults;

  /// No description provided for @emojiSmileys.
  ///
  /// In en, this message translates to:
  /// **'Smileys'**
  String get emojiSmileys;

  /// No description provided for @emojiPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get emojiPeople;

  /// No description provided for @emojiAnimals.
  ///
  /// In en, this message translates to:
  /// **'Animals and nature'**
  String get emojiAnimals;

  /// No description provided for @emojiFood.
  ///
  /// In en, this message translates to:
  /// **'Food and drink'**
  String get emojiFood;

  /// No description provided for @emojiTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel and places'**
  String get emojiTravel;

  /// No description provided for @emojiActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get emojiActivities;

  /// No description provided for @emojiObjects.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get emojiObjects;

  /// No description provided for @emojiSymbols.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get emojiSymbols;

  /// No description provided for @emojiFlags.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get emojiFlags;

  /// No description provided for @favoriteStickers.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoriteStickers;

  /// No description provided for @stickersFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load stickers'**
  String get stickersFailed;

  /// No description provided for @noStickerSets.
  ///
  /// In en, this message translates to:
  /// **'No sets yet'**
  String get noStickerSets;

  /// No description provided for @noGifs.
  ///
  /// In en, this message translates to:
  /// **'No saved GIFs yet'**
  String get noGifs;

  /// No description provided for @gifsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load GIFs'**
  String get gifsFailed;

  /// No description provided for @inlineSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get inlineSearching;

  /// No description provided for @inlineNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get inlineNoResults;

  /// No description provided for @forwardedMessages.
  ///
  /// In en, this message translates to:
  /// **'Forwarded messages'**
  String get forwardedMessages;

  /// No description provided for @leaveComment.
  ///
  /// In en, this message translates to:
  /// **'Leave a comment'**
  String get leaveComment;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get commentHint;

  /// No description provided for @commentsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the comments'**
  String get commentsUnavailable;

  /// No description provided for @commentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} comment} other{{count} comments}}'**
  String commentCount(int count);

  /// No description provided for @replies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get replies;

  /// No description provided for @replyHint.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get replyHint;

  /// No description provided for @replyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} reply} other{{count} replies}}'**
  String replyCount(int count);

  /// No description provided for @mediaSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get mediaSaved;

  /// No description provided for @mediaSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the file'**
  String get mediaSaveFailed;

  /// No description provided for @mediaCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get mediaCopied;

  /// No description provided for @mediaCounter.
  ///
  /// In en, this message translates to:
  /// **'{index} of {count}'**
  String mediaCounter(int index, int count);

  /// No description provided for @mediaRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get mediaRotate;

  /// No description provided for @mediaCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get mediaCopy;

  /// No description provided for @mediaSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get mediaSave;

  /// No description provided for @mediaPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get mediaPrevious;

  /// No description provided for @mediaNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get mediaNext;

  /// No description provided for @mediaPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get mediaPause;

  /// No description provided for @mediaPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get mediaPlay;

  /// No description provided for @mediaSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get mediaSpeed;

  /// No description provided for @mediaLoop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get mediaLoop;

  /// No description provided for @mediaUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get mediaUnmute;

  /// No description provided for @mediaMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mediaMute;

  /// No description provided for @unreadMessages.
  ///
  /// In en, this message translates to:
  /// **'Unread messages'**
  String get unreadMessages;

  /// No description provided for @scrollToBottom.
  ///
  /// In en, this message translates to:
  /// **'Scroll to the newest message'**
  String get scrollToBottom;

  /// No description provided for @nextMention.
  ///
  /// In en, this message translates to:
  /// **'Next mention'**
  String get nextMention;

  /// No description provided for @nextReaction.
  ///
  /// In en, this message translates to:
  /// **'Next reaction'**
  String get nextReaction;

  /// No description provided for @linkJoinChannel.
  ///
  /// In en, this message translates to:
  /// **'Join channel'**
  String get linkJoinChannel;

  /// No description provided for @linkJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join group'**
  String get linkJoinGroup;

  /// No description provided for @linkRequestToJoin.
  ///
  /// In en, this message translates to:
  /// **'Request to join'**
  String get linkRequestToJoin;

  /// No description provided for @linkViewChannel.
  ///
  /// In en, this message translates to:
  /// **'View channel'**
  String get linkViewChannel;

  /// No description provided for @linkViewGroup.
  ///
  /// In en, this message translates to:
  /// **'View group'**
  String get linkViewGroup;

  /// No description provided for @linkSubscribers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No subscribers} one{{count} subscriber} other{{count} subscribers}}'**
  String linkSubscribers(int count);

  /// No description provided for @linkMembers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No members} one{{count} member} other{{count} members}}'**
  String linkMembers(int count);

  /// No description provided for @linkApprovalHint.
  ///
  /// In en, this message translates to:
  /// **'An admin has to approve your request.'**
  String get linkApprovalHint;

  /// No description provided for @linkRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get linkRequestSent;

  /// No description provided for @linkRequestSentHint.
  ///
  /// In en, this message translates to:
  /// **'You\'ll join once an admin approves it.'**
  String get linkRequestSentHint;

  /// No description provided for @linkJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t join. Try again later.'**
  String get linkJoinFailed;

  /// No description provided for @linkMissing.
  ///
  /// In en, this message translates to:
  /// **'This link is invalid or has expired.'**
  String get linkMissing;

  /// No description provided for @linkUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Mollygram can\'t open this kind of link yet.'**
  String get linkUnsupported;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @linkForbidden.
  ///
  /// In en, this message translates to:
  /// **'You can\'t view this chat.'**
  String get linkForbidden;

  /// No description provided for @linkCannotSend.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the command.'**
  String get linkCannotSend;

  /// No description provided for @pinnedMessage.
  ///
  /// In en, this message translates to:
  /// **'Pinned message'**
  String get pinnedMessage;

  /// No description provided for @pinnedMessageNumber.
  ///
  /// In en, this message translates to:
  /// **'Pinned message #{number}'**
  String pinnedMessageNumber(int number);

  /// No description provided for @hidePinned.
  ///
  /// In en, this message translates to:
  /// **'Hide pinned messages'**
  String get hidePinned;

  /// No description provided for @backToPrevious.
  ///
  /// In en, this message translates to:
  /// **'Back to where you were'**
  String get backToPrevious;

  /// No description provided for @searchInChat.
  ///
  /// In en, this message translates to:
  /// **'Search in chat'**
  String get searchInChat;

  /// No description provided for @searchByDate.
  ///
  /// In en, this message translates to:
  /// **'Jump to date'**
  String get searchByDate;

  /// No description provided for @searchBySender.
  ///
  /// In en, this message translates to:
  /// **'Search by sender'**
  String get searchBySender;

  /// No description provided for @searchFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter results'**
  String get searchFilter;

  /// No description provided for @searchAllKinds.
  ///
  /// In en, this message translates to:
  /// **'All messages'**
  String get searchAllKinds;

  /// No description provided for @searchCounter.
  ///
  /// In en, this message translates to:
  /// **'{index} of {count}'**
  String searchCounter(int index, int count);

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResults;

  /// No description provided for @searchOlder.
  ///
  /// In en, this message translates to:
  /// **'Previous result'**
  String get searchOlder;

  /// No description provided for @searchNewer.
  ///
  /// In en, this message translates to:
  /// **'Next result'**
  String get searchNewer;

  /// No description provided for @hashtagThisChat.
  ///
  /// In en, this message translates to:
  /// **'This chat'**
  String get hashtagThisChat;

  /// No description provided for @hashtagMyMessages.
  ///
  /// In en, this message translates to:
  /// **'My messages'**
  String get hashtagMyMessages;

  /// No description provided for @hashtagPublicPosts.
  ///
  /// In en, this message translates to:
  /// **'Public posts'**
  String get hashtagPublicPosts;

  /// No description provided for @hashtagEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages with {tag}'**
  String hashtagEmpty(String tag);

  /// No description provided for @hashtagFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not search'**
  String get hashtagFailed;

  /// No description provided for @sharedMedia.
  ///
  /// In en, this message translates to:
  /// **'Shared media'**
  String get sharedMedia;

  /// No description provided for @sharedMediaTab.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get sharedMediaTab;

  /// No description provided for @sharedFilesTab.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get sharedFilesTab;

  /// No description provided for @sharedLinksTab.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get sharedLinksTab;

  /// No description provided for @sharedVoiceTab.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get sharedVoiceTab;

  /// No description provided for @sharedMusicTab.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get sharedMusicTab;

  /// No description provided for @sharedGifsTab.
  ///
  /// In en, this message translates to:
  /// **'GIFs'**
  String get sharedGifsTab;

  /// No description provided for @sharedGroupsTab.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get sharedGroupsTab;

  /// No description provided for @sharedMediaEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos or videos yet'**
  String get sharedMediaEmpty;

  /// No description provided for @sharedFilesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get sharedFilesEmpty;

  /// No description provided for @sharedLinksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No links yet'**
  String get sharedLinksEmpty;

  /// No description provided for @sharedVoiceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No voice messages yet'**
  String get sharedVoiceEmpty;

  /// No description provided for @sharedMusicEmpty.
  ///
  /// In en, this message translates to:
  /// **'No music yet'**
  String get sharedMusicEmpty;

  /// No description provided for @sharedGifsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No GIFs yet'**
  String get sharedGifsEmpty;

  /// No description provided for @sharedGroupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No groups in common'**
  String get sharedGroupsEmpty;

  /// No description provided for @sharedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the list'**
  String get sharedLoadFailed;

  /// No description provided for @showInChat.
  ///
  /// In en, this message translates to:
  /// **'Show in chat'**
  String get showInChat;

  /// No description provided for @playlist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist;

  /// No description provided for @joinChannel.
  ///
  /// In en, this message translates to:
  /// **'Join channel'**
  String get joinChannel;

  /// No description provided for @joinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join group'**
  String get joinGroup;

  /// No description provided for @muteChat.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get muteChat;

  /// No description provided for @unmuteChat.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmuteChat;

  /// No description provided for @chatUnavailable.
  ///
  /// In en, this message translates to:
  /// **'You can\'t take part in this chat'**
  String get chatUnavailable;

  /// No description provided for @textNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Text messages aren\'t allowed in this group'**
  String get textNotAllowed;

  /// No description provided for @restrictedUntil.
  ///
  /// In en, this message translates to:
  /// **'You can\'t write here until {date}'**
  String restrictedUntil(String date);

  /// No description provided for @slowModeWait.
  ///
  /// In en, this message translates to:
  /// **'Slowmode is on, next message in {time}'**
  String slowModeWait(String time);

  /// No description provided for @privacyExtras.
  ///
  /// In en, this message translates to:
  /// **'Privacy extras'**
  String get privacyExtras;

  /// No description provided for @privacyExtrasAbout.
  ///
  /// In en, this message translates to:
  /// **'These switches decide what others see while you use Mollygram on this Mac. Everything you read and send works as usual.'**
  String get privacyExtrasAbout;

  /// No description provided for @privacyExtrasOnlineNote.
  ///
  /// In en, this message translates to:
  /// **'Some things still show: sending a message puts you online for a moment and marks the chat read, files you send show as uploading, and a reaction shows you saw the message.'**
  String get privacyExtrasOnlineNote;

  /// No description provided for @ghostMode.
  ///
  /// In en, this message translates to:
  /// **'Ghost mode'**
  String get ghostMode;

  /// No description provided for @ghostModeHint.
  ///
  /// In en, this message translates to:
  /// **'Turns on everything below at once'**
  String get ghostModeHint;

  /// No description provided for @ghostModeIsOn.
  ///
  /// In en, this message translates to:
  /// **'Ghost mode is on'**
  String get ghostModeIsOn;

  /// No description provided for @privacyExtrasAreOn.
  ///
  /// In en, this message translates to:
  /// **'Some privacy extras are on'**
  String get privacyExtrasAreOn;

  /// No description provided for @hideReadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Don\'t send read receipts'**
  String get hideReadReceipts;

  /// No description provided for @hideReadReceiptsHint.
  ///
  /// In en, this message translates to:
  /// **'Senders won\'t see that you\'ve read their messages'**
  String get hideReadReceiptsHint;

  /// No description provided for @hideTyping.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show typing'**
  String get hideTyping;

  /// No description provided for @hideTypingHint.
  ///
  /// In en, this message translates to:
  /// **'Also hides recording voice and video messages'**
  String get hideTypingHint;

  /// No description provided for @stayOffline.
  ///
  /// In en, this message translates to:
  /// **'Stay offline'**
  String get stayOffline;

  /// No description provided for @stayOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'You won\'t appear online while the app is open'**
  String get stayOfflineHint;

  /// No description provided for @hideContentOpened.
  ///
  /// In en, this message translates to:
  /// **'Don\'t mark voice and video messages as played'**
  String get hideContentOpened;

  /// No description provided for @hideContentOpenedHint.
  ///
  /// In en, this message translates to:
  /// **'Senders won\'t see that you\'ve played them'**
  String get hideContentOpenedHint;

  /// No description provided for @menuSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get menuSelect;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} selected} other{{count} selected}}'**
  String selectedCount(int count);

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @chatFolders.
  ///
  /// In en, this message translates to:
  /// **'Chat folders'**
  String get chatFolders;

  /// No description provided for @chatFoldersHint.
  ///
  /// In en, this message translates to:
  /// **'Sort chats into folders and switch between them in the sidebar.'**
  String get chatFoldersHint;

  /// No description provided for @createFolder.
  ///
  /// In en, this message translates to:
  /// **'Create folder'**
  String get createFolder;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @editFolder.
  ///
  /// In en, this message translates to:
  /// **'Edit folder'**
  String get editFolder;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// No description provided for @folderIcon.
  ///
  /// In en, this message translates to:
  /// **'Folder icon'**
  String get folderIcon;

  /// No description provided for @folderIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included chats'**
  String get folderIncluded;

  /// No description provided for @folderExcluded.
  ///
  /// In en, this message translates to:
  /// **'Excluded chats'**
  String get folderExcluded;

  /// No description provided for @folderAddChats.
  ///
  /// In en, this message translates to:
  /// **'Add chats'**
  String get folderAddChats;

  /// No description provided for @folderExcludeChats.
  ///
  /// In en, this message translates to:
  /// **'Exclude chats'**
  String get folderExcludeChats;

  /// No description provided for @folderIncludedHint.
  ///
  /// In en, this message translates to:
  /// **'Choose chats or kinds of chats that will appear in this folder.'**
  String get folderIncludedHint;

  /// No description provided for @folderExcludedHint.
  ///
  /// In en, this message translates to:
  /// **'Choose chats or kinds of chats that will never appear in this folder.'**
  String get folderExcludedHint;

  /// No description provided for @folderContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get folderContacts;

  /// No description provided for @folderNonContacts.
  ///
  /// In en, this message translates to:
  /// **'Non-contacts'**
  String get folderNonContacts;

  /// No description provided for @folderGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get folderGroups;

  /// No description provided for @folderChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get folderChannels;

  /// No description provided for @folderBots.
  ///
  /// In en, this message translates to:
  /// **'Bots'**
  String get folderBots;

  /// No description provided for @folderMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get folderMuted;

  /// No description provided for @folderRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get folderRead;

  /// No description provided for @folderArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get folderArchived;

  /// No description provided for @folderChatTypes.
  ///
  /// In en, this message translates to:
  /// **'Chat types'**
  String get folderChatTypes;

  /// No description provided for @folderChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get folderChats;

  /// No description provided for @folderBot.
  ///
  /// In en, this message translates to:
  /// **'bot'**
  String get folderBot;

  /// No description provided for @folderGroup.
  ///
  /// In en, this message translates to:
  /// **'group'**
  String get folderGroup;

  /// No description provided for @folderChannel.
  ///
  /// In en, this message translates to:
  /// **'channel'**
  String get folderChannel;

  /// No description provided for @folderSavedMessages.
  ///
  /// In en, this message translates to:
  /// **'Saved Messages'**
  String get folderSavedMessages;

  /// No description provided for @folderRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get folderRemove;

  /// No description provided for @folderAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get folderAdd;

  /// No description provided for @folderReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get folderReorder;

  /// No description provided for @folderReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the handles to change the order of folders in the sidebar.'**
  String get folderReorderHint;

  /// No description provided for @recommendedFolders.
  ///
  /// In en, this message translates to:
  /// **'Recommended folders'**
  String get recommendedFolders;

  /// No description provided for @deleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get deleteFolder;

  /// No description provided for @deleteFolderMessage.
  ///
  /// In en, this message translates to:
  /// **'The chats in it won\'t be deleted.'**
  String get deleteFolderMessage;

  /// No description provided for @deleteFolderLeave.
  ///
  /// In en, this message translates to:
  /// **'The chats in it won\'t be deleted. You can also leave the chats this folder was shared with you through:'**
  String get deleteFolderLeave;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @deleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteFolderTitle(String name);

  /// No description provided for @folderLimit.
  ///
  /// In en, this message translates to:
  /// **'You can have up to {count} folders.'**
  String folderLimit(int count);

  /// No description provided for @folderChatsLimit.
  ///
  /// In en, this message translates to:
  /// **'A folder can have up to {count} chats.'**
  String folderChatsLimit(int count);

  /// No description provided for @folderChatsCounter.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max}'**
  String folderChatsCounter(int count, int max);

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @pinnedList.
  ///
  /// In en, this message translates to:
  /// **'Pinned messages'**
  String get pinnedList;

  /// No description provided for @pinnedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} pinned message} other{{count} pinned messages}}'**
  String pinnedCount(int count);

  /// No description provided for @backToChat.
  ///
  /// In en, this message translates to:
  /// **'Back to the chat'**
  String get backToChat;

  /// No description provided for @backToTopics.
  ///
  /// In en, this message translates to:
  /// **'Back to topics'**
  String get backToTopics;

  /// No description provided for @savedShowAsChats.
  ///
  /// In en, this message translates to:
  /// **'Show as chats'**
  String get savedShowAsChats;

  /// No description provided for @savedShowAsMessages.
  ///
  /// In en, this message translates to:
  /// **'Show as messages'**
  String get savedShowAsMessages;

  /// No description provided for @savedMyNotes.
  ///
  /// In en, this message translates to:
  /// **'My notes'**
  String get savedMyNotes;

  /// No description provided for @savedHiddenAuthor.
  ///
  /// In en, this message translates to:
  /// **'Hidden author'**
  String get savedHiddenAuthor;

  /// No description provided for @savedTagName.
  ///
  /// In en, this message translates to:
  /// **'Name the tag'**
  String get savedTagName;

  /// No description provided for @savedTagClearName.
  ///
  /// In en, this message translates to:
  /// **'Remove the name'**
  String get savedTagClearName;

  /// No description provided for @savedTagFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load these messages'**
  String get savedTagFailed;

  /// No description provided for @savedAllMessages.
  ///
  /// In en, this message translates to:
  /// **'All saved messages'**
  String get savedAllMessages;

  /// No description provided for @deleteSavedTopicConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything saved from {name}?'**
  String deleteSavedTopicConfirm(String name);

  /// No description provided for @noTopics.
  ///
  /// In en, this message translates to:
  /// **'No topics yet'**
  String get noTopics;

  /// No description provided for @topicClosed.
  ///
  /// In en, this message translates to:
  /// **'Topic closed'**
  String get topicClosed;

  /// No description provided for @topicUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this topic'**
  String get topicUnavailable;

  /// No description provided for @newTopic.
  ///
  /// In en, this message translates to:
  /// **'New topic'**
  String get newTopic;

  /// No description provided for @topicName.
  ///
  /// In en, this message translates to:
  /// **'Topic name'**
  String get topicName;

  /// No description provided for @topicNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the topic a name'**
  String get topicNameRequired;

  /// No description provided for @editTopic.
  ///
  /// In en, this message translates to:
  /// **'Edit topic'**
  String get editTopic;

  /// No description provided for @closeTopic.
  ///
  /// In en, this message translates to:
  /// **'Close topic'**
  String get closeTopic;

  /// No description provided for @reopenTopic.
  ///
  /// In en, this message translates to:
  /// **'Reopen topic'**
  String get reopenTopic;

  /// No description provided for @pinTopic.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pinTopic;

  /// No description provided for @unpinTopic.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpinTopic;

  /// No description provided for @deleteTopic.
  ///
  /// In en, this message translates to:
  /// **'Delete topic'**
  String get deleteTopic;

  /// No description provided for @deleteTopicConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete «{name}» with all its messages?'**
  String deleteTopicConfirm(String name);

  /// No description provided for @topicActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the topic'**
  String get topicActionFailed;

  /// No description provided for @sponsored.
  ///
  /// In en, this message translates to:
  /// **'Sponsored'**
  String get sponsored;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @sponsoredOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get sponsoredOpen;

  /// No description provided for @sponsoredAbout.
  ///
  /// In en, this message translates to:
  /// **'Telegram shows this message on behalf of the sponsor. It is picked by the channel\'s topic, not by your data.'**
  String get sponsoredAbout;

  /// No description provided for @unpinAll.
  ///
  /// In en, this message translates to:
  /// **'Unpin all messages'**
  String get unpinAll;

  /// No description provided for @unpinAllTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Unpin {count} message?} other{Unpin all {count} messages?}}'**
  String unpinAllTitle(int count);

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @privacyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the privacy settings.'**
  String get privacyLoadFailed;

  /// No description provided for @privacyPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get privacyPhoneNumber;

  /// No description provided for @privacyFindByPhone.
  ///
  /// In en, this message translates to:
  /// **'Finding by phone number'**
  String get privacyFindByPhone;

  /// No description provided for @privacyLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen and online'**
  String get privacyLastSeen;

  /// No description provided for @privacyProfilePhotos.
  ///
  /// In en, this message translates to:
  /// **'Profile photos'**
  String get privacyProfilePhotos;

  /// No description provided for @privacyForwards.
  ///
  /// In en, this message translates to:
  /// **'Forwarded messages'**
  String get privacyForwards;

  /// No description provided for @privacyCalls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get privacyCalls;

  /// No description provided for @privacyVoiceMessages.
  ///
  /// In en, this message translates to:
  /// **'Voice messages'**
  String get privacyVoiceMessages;

  /// No description provided for @privacyInvites.
  ///
  /// In en, this message translates to:
  /// **'Groups and channels'**
  String get privacyInvites;

  /// No description provided for @privacyBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get privacyBio;

  /// No description provided for @privacyBirthday.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get privacyBirthday;

  /// No description provided for @privacyPhoneNumberQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who can see my phone number?'**
  String get privacyPhoneNumberQuestion;

  /// No description provided for @privacyFindByPhoneQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who can find me by my number?'**
  String get privacyFindByPhoneQuestion;

  /// No description provided for @privacyLastSeenQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who can see my last seen time?'**
  String get privacyLastSeenQuestion;

  /// No description provided for @privacyProfilePhotosQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who can see my profile photos?'**
  String get privacyProfilePhotosQuestion;

  /// No description provided for @privacyForwardsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who can link to my account when forwarding my messages?'**
  String get privacyForwardsQuestion;

  /// No description provided for @privacyCallsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who can call me?'**
  String get privacyCallsQuestion;

  /// No description provided for @privacyVoiceMessagesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who can send me voice and video messages?'**
  String get privacyVoiceMessagesQuestion;

  /// No description provided for @privacyInvitesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who can add me to groups and channels?'**
  String get privacyInvitesQuestion;

  /// No description provided for @privacyBioQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who can see my bio?'**
  String get privacyBioQuestion;

  /// No description provided for @privacyBirthdayQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who can see my date of birth?'**
  String get privacyBirthdayQuestion;

  /// No description provided for @privacyPhoneNumberAbout.
  ///
  /// In en, this message translates to:
  /// **'People who have your number saved in their contacts will also see it on Telegram.'**
  String get privacyPhoneNumberAbout;

  /// No description provided for @privacyFindByPhoneAbout.
  ///
  /// In en, this message translates to:
  /// **'People who add your number to their contacts will see it as your Telegram account only if they\'re in this audience.'**
  String get privacyFindByPhoneAbout;

  /// No description provided for @privacyLastSeenAbout.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see the last seen time of people you don\'t show yours to. An approximate time, such as recently or within a week, shows instead.'**
  String get privacyLastSeenAbout;

  /// No description provided for @privacyForwardsAbout.
  ///
  /// In en, this message translates to:
  /// **'Messages you send won\'t link back to your account when forwarded by people outside this audience.'**
  String get privacyForwardsAbout;

  /// No description provided for @privacyVoiceMessagesAbout.
  ///
  /// In en, this message translates to:
  /// **'Only Telegram Premium subscribers can limit who sends them voice and video messages.'**
  String get privacyVoiceMessagesAbout;

  /// No description provided for @privacyEverybody.
  ///
  /// In en, this message translates to:
  /// **'Everybody'**
  String get privacyEverybody;

  /// No description provided for @privacyMyContacts.
  ///
  /// In en, this message translates to:
  /// **'My contacts'**
  String get privacyMyContacts;

  /// No description provided for @privacyNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody'**
  String get privacyNobody;

  /// No description provided for @privacyExceptions.
  ///
  /// In en, this message translates to:
  /// **'Exceptions'**
  String get privacyExceptions;

  /// No description provided for @privacyExceptionsAbout.
  ///
  /// In en, this message translates to:
  /// **'Exceptions come before the choice above.'**
  String get privacyExceptionsAbout;

  /// No description provided for @privacyAlwaysAllow.
  ///
  /// In en, this message translates to:
  /// **'Always allow'**
  String get privacyAlwaysAllow;

  /// No description provided for @privacyNeverAllow.
  ///
  /// In en, this message translates to:
  /// **'Never allow'**
  String get privacyNeverAllow;

  /// No description provided for @privacyAlwaysAbout.
  ///
  /// In en, this message translates to:
  /// **'These people are allowed, whatever the choice above.'**
  String get privacyAlwaysAbout;

  /// No description provided for @privacyNeverAbout.
  ///
  /// In en, this message translates to:
  /// **'These people are never allowed, whatever the choice above.'**
  String get privacyNeverAbout;

  /// No description provided for @privacyAddPeople.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get privacyAddPeople;

  /// No description provided for @privacyGroupMembers.
  ///
  /// In en, this message translates to:
  /// **'Group members'**
  String get privacyGroupMembers;

  /// No description provided for @privacyPeopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} person} other{{count} people}}'**
  String privacyPeopleCount(int count);

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsers;

  /// No description provided for @blockedUsersAbout.
  ///
  /// In en, this message translates to:
  /// **'Blocked people can\'t message you, call you or add you to groups, and don\'t see your profile photos, online status or last seen time.'**
  String get blockedUsersAbout;

  /// No description provided for @blockedUsersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one is blocked.'**
  String get blockedUsersEmpty;

  /// No description provided for @blockSomeone.
  ///
  /// In en, this message translates to:
  /// **'Block someone'**
  String get blockSomeone;

  /// No description provided for @privacyNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Not loaded'**
  String get privacyNotLoaded;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @blockedShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get blockedShowMore;

  /// No description provided for @keepDeletedMessages.
  ///
  /// In en, this message translates to:
  /// **'Keep deleted messages'**
  String get keepDeletedMessages;

  /// No description provided for @keepDeletedMessagesHint.
  ///
  /// In en, this message translates to:
  /// **'Save messages others delete for everyone'**
  String get keepDeletedMessagesHint;

  /// No description provided for @keepEditHistory.
  ///
  /// In en, this message translates to:
  /// **'Keep edit history'**
  String get keepEditHistory;

  /// No description provided for @keepEditHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Save earlier versions of edited messages'**
  String get keepEditHistoryHint;

  /// No description provided for @storedMessagesAbout.
  ///
  /// In en, this message translates to:
  /// **'Saved encrypted on this computer only, for messages Mollygram saw while it was open. Nothing is sent anywhere. Showing them in chats comes later.'**
  String get storedMessagesAbout;

  /// No description provided for @clearStoredData.
  ///
  /// In en, this message translates to:
  /// **'Stored data'**
  String get clearStoredData;

  /// No description provided for @clearStoredDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the deleted messages and edit history saved on this computer?'**
  String get clearStoredDataTitle;

  /// No description provided for @storedDataUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Stored data can\'t be read'**
  String get storedDataUnreadable;

  /// No description provided for @storedDataUnreadableHint.
  ///
  /// In en, this message translates to:
  /// **'Its key is missing from the keychain. Reset to start again.'**
  String get storedDataUnreadableHint;

  /// No description provided for @resetStoredData.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetStoredData;

  /// No description provided for @resetStoredDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the stored data that can\'t be read and start again?'**
  String get resetStoredDataTitle;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @newChannel.
  ///
  /// In en, this message translates to:
  /// **'New channel'**
  String get newChannel;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @channelName.
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get channelName;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionHint;

  /// No description provided for @descriptionNote.
  ///
  /// In en, this message translates to:
  /// **'Shown on the info panel under the name.'**
  String get descriptionNote;

  /// No description provided for @chatTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get chatTitleRequired;

  /// No description provided for @addMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get addMembersHint;

  /// No description provided for @createFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create it. Try again.'**
  String get createFailed;

  /// No description provided for @editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get editGroup;

  /// No description provided for @editChannel.
  ///
  /// In en, this message translates to:
  /// **'Edit channel'**
  String get editChannel;

  /// No description provided for @setPhoto.
  ///
  /// In en, this message translates to:
  /// **'Set photo'**
  String get setPhoto;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @inviteLinks.
  ///
  /// In en, this message translates to:
  /// **'Invite links'**
  String get inviteLinks;

  /// No description provided for @primaryLink.
  ///
  /// In en, this message translates to:
  /// **'Primary link'**
  String get primaryLink;

  /// No description provided for @createPrimaryLink.
  ///
  /// In en, this message translates to:
  /// **'Generate a link'**
  String get createPrimaryLink;

  /// No description provided for @additionalLinks.
  ///
  /// In en, this message translates to:
  /// **'Additional links'**
  String get additionalLinks;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @revokeLink.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revokeLink;

  /// No description provided for @revokeLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke this link?'**
  String get revokeLinkTitle;

  /// No description provided for @revokeLinkMessage.
  ///
  /// In en, this message translates to:
  /// **'Nobody will be able to join with it any more.'**
  String get revokeLinkMessage;

  /// No description provided for @revokePrimaryMessage.
  ///
  /// In en, this message translates to:
  /// **'Nobody will be able to join with it any more. A new primary link replaces it.'**
  String get revokePrimaryMessage;

  /// No description provided for @createLink.
  ///
  /// In en, this message translates to:
  /// **'Create a new link'**
  String get createLink;

  /// No description provided for @newLink.
  ///
  /// In en, this message translates to:
  /// **'New link'**
  String get newLink;

  /// No description provided for @linkNameHint.
  ///
  /// In en, this message translates to:
  /// **'Link name (only admins see it)'**
  String get linkNameHint;

  /// No description provided for @linkDuration.
  ///
  /// In en, this message translates to:
  /// **'Works for'**
  String get linkDuration;

  /// No description provided for @linkMemberLimit.
  ///
  /// In en, this message translates to:
  /// **'Number of uses'**
  String get linkMemberLimit;

  /// No description provided for @linkRequestApproval.
  ///
  /// In en, this message translates to:
  /// **'Approve new members'**
  String get linkRequestApproval;

  /// No description provided for @noLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get noLimit;

  /// No description provided for @oneDay.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get oneDay;

  /// No description provided for @oneWeek.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get oneWeek;

  /// No description provided for @oneMonth.
  ///
  /// In en, this message translates to:
  /// **'1 month'**
  String get oneMonth;

  /// No description provided for @linkJoined.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{nobody joined} =1{1 joined} other{{count} joined}}'**
  String linkJoined(int count);

  /// No description provided for @linkJoinedOf.
  ///
  /// In en, this message translates to:
  /// **'{count} of {limit} joined'**
  String linkJoinedOf(int count, int limit);

  /// No description provided for @linkApproval.
  ///
  /// In en, this message translates to:
  /// **'with approval'**
  String get linkApproval;

  /// No description provided for @linkExpired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get linkExpired;

  /// No description provided for @linkExpires.
  ///
  /// In en, this message translates to:
  /// **'expires {date}'**
  String linkExpires(String date);

  /// No description provided for @searchMembers.
  ///
  /// In en, this message translates to:
  /// **'Search members'**
  String get searchMembers;

  /// No description provided for @showMoreMembers.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMoreMembers;

  /// No description provided for @promoteToAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get promoteToAdmin;

  /// No description provided for @editAdminRights.
  ///
  /// In en, this message translates to:
  /// **'Edit admin rights'**
  String get editAdminRights;

  /// No description provided for @dismissAdmin.
  ///
  /// In en, this message translates to:
  /// **'Dismiss admin'**
  String get dismissAdmin;

  /// No description provided for @restrictMember.
  ///
  /// In en, this message translates to:
  /// **'Restrict'**
  String get restrictMember;

  /// No description provided for @removeFromGroup.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get removeFromGroup;

  /// No description provided for @removeFromChannel.
  ///
  /// In en, this message translates to:
  /// **'Remove from channel'**
  String get removeFromChannel;

  /// No description provided for @removeMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeMemberTitle(String name);

  /// No description provided for @addAdmin.
  ///
  /// In en, this message translates to:
  /// **'New admin'**
  String get addAdmin;

  /// No description provided for @adminRights.
  ///
  /// In en, this message translates to:
  /// **'Admin rights'**
  String get adminRights;

  /// No description provided for @adminRightsOf.
  ///
  /// In en, this message translates to:
  /// **'What {name} can do'**
  String adminRightsOf(String name);

  /// No description provided for @restrictWhatCan.
  ///
  /// In en, this message translates to:
  /// **'What {name} can still do'**
  String restrictWhatCan(String name);

  /// No description provided for @rightChangeInfo.
  ///
  /// In en, this message translates to:
  /// **'Change group info'**
  String get rightChangeInfo;

  /// No description provided for @rightChangeChannelInfo.
  ///
  /// In en, this message translates to:
  /// **'Change channel info'**
  String get rightChangeChannelInfo;

  /// No description provided for @rightPostMessages.
  ///
  /// In en, this message translates to:
  /// **'Post messages'**
  String get rightPostMessages;

  /// No description provided for @rightEditMessages.
  ///
  /// In en, this message translates to:
  /// **'Edit others\' messages'**
  String get rightEditMessages;

  /// No description provided for @rightDeleteMessages.
  ///
  /// In en, this message translates to:
  /// **'Delete messages'**
  String get rightDeleteMessages;

  /// No description provided for @rightBanUsers.
  ///
  /// In en, this message translates to:
  /// **'Ban users'**
  String get rightBanUsers;

  /// No description provided for @rightInviteUsers.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get rightInviteUsers;

  /// No description provided for @rightAddSubscribers.
  ///
  /// In en, this message translates to:
  /// **'Add subscribers'**
  String get rightAddSubscribers;

  /// No description provided for @rightPinMessages.
  ///
  /// In en, this message translates to:
  /// **'Pin messages'**
  String get rightPinMessages;

  /// No description provided for @rightManageVideoChats.
  ///
  /// In en, this message translates to:
  /// **'Manage video chats'**
  String get rightManageVideoChats;

  /// No description provided for @rightAddAdmins.
  ///
  /// In en, this message translates to:
  /// **'Add new admins'**
  String get rightAddAdmins;

  /// No description provided for @rightAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Remain anonymous'**
  String get rightAnonymous;

  /// No description provided for @permSendMessages.
  ///
  /// In en, this message translates to:
  /// **'Send messages'**
  String get permSendMessages;

  /// No description provided for @permSendMedia.
  ///
  /// In en, this message translates to:
  /// **'Send media'**
  String get permSendMedia;

  /// No description provided for @permSendStickers.
  ///
  /// In en, this message translates to:
  /// **'Send stickers and GIFs'**
  String get permSendStickers;

  /// No description provided for @permSendPolls.
  ///
  /// In en, this message translates to:
  /// **'Send polls'**
  String get permSendPolls;

  /// No description provided for @permEmbedLinks.
  ///
  /// In en, this message translates to:
  /// **'Embed links'**
  String get permEmbedLinks;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// No description provided for @leaveChannel.
  ///
  /// In en, this message translates to:
  /// **'Leave channel'**
  String get leaveChannel;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroup;

  /// No description provided for @deleteChannel.
  ///
  /// In en, this message translates to:
  /// **'Delete channel'**
  String get deleteChannel;

  /// No description provided for @leaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this group?'**
  String get leaveGroupTitle;

  /// No description provided for @leaveChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this channel?'**
  String get leaveChannelTitle;

  /// No description provided for @deleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this group?'**
  String get deleteGroupTitle;

  /// No description provided for @deleteChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this channel?'**
  String get deleteChannelTitle;

  /// No description provided for @membersFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the members.'**
  String get membersFailed;

  /// No description provided for @memberChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make the change. You may not have the right to.'**
  String get memberChangeFailed;

  /// No description provided for @removeRestrictions.
  ///
  /// In en, this message translates to:
  /// **'Remove restrictions'**
  String get removeRestrictions;

  /// No description provided for @rightManageTopics.
  ///
  /// In en, this message translates to:
  /// **'Manage topics'**
  String get rightManageTopics;

  /// No description provided for @notAddedMembers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The group is created, but {names} couldn\'t be added because of their privacy settings.} other{The group is created, but {names} couldn\'t be added because of their privacy settings.}}'**
  String notAddedMembers(int count, String names);

  /// No description provided for @leaveOwnerNote.
  ///
  /// In en, this message translates to:
  /// **'You stay the owner and can come back with an invite link.'**
  String get leaveOwnerNote;

  /// No description provided for @deleteGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Every member loses the group and all its messages. This can\'t be undone.'**
  String get deleteGroupMessage;

  /// No description provided for @deleteChannelMessage.
  ///
  /// In en, this message translates to:
  /// **'Every subscriber loses the channel and all its posts. This can\'t be undone.'**
  String get deleteChannelMessage;

  /// No description provided for @leaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t leave. Try again.'**
  String get leaveFailed;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete it. Try again.'**
  String get deleteFailed;

  /// No description provided for @folderDeletedChat.
  ///
  /// In en, this message translates to:
  /// **'Deleted chat'**
  String get folderDeletedChat;

  /// No description provided for @passcodeLock.
  ///
  /// In en, this message translates to:
  /// **'Passcode lock'**
  String get passcodeLock;

  /// No description provided for @passcodeAbout.
  ///
  /// In en, this message translates to:
  /// **'A passcode locks Mollygram on this Mac. It isn\'t sent to Telegram and works only here.'**
  String get passcodeAbout;

  /// No description provided for @passcodeTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn passcode on'**
  String get passcodeTurnOn;

  /// No description provided for @passcodeTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn passcode off'**
  String get passcodeTurnOff;

  /// No description provided for @passcodeTurnOffAction.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get passcodeTurnOffAction;

  /// No description provided for @passcodeChange.
  ///
  /// In en, this message translates to:
  /// **'Change passcode'**
  String get passcodeChange;

  /// No description provided for @passcodeCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current passcode'**
  String get passcodeCurrent;

  /// No description provided for @passcodeNew.
  ///
  /// In en, this message translates to:
  /// **'New passcode'**
  String get passcodeNew;

  /// No description provided for @passcodeRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat the passcode'**
  String get passcodeRepeat;

  /// No description provided for @passcodeTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 4 characters.'**
  String get passcodeTooShort;

  /// No description provided for @passcodesDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passcodes don\'t match.'**
  String get passcodesDontMatch;

  /// No description provided for @passcodeWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong passcode'**
  String get passcodeWrong;

  /// No description provided for @passcodeAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get passcodeAutoLock;

  /// No description provided for @passcodeAwayHour.
  ///
  /// In en, this message translates to:
  /// **'If away for 1 hour'**
  String get passcodeAwayHour;

  /// No description provided for @passcodeAwayFor.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{If away for {minutes} minute} other{If away for {minutes} minutes}}'**
  String passcodeAwayFor(int minutes);

  /// No description provided for @passcodeLockNowHint.
  ///
  /// In en, this message translates to:
  /// **'Press ⌘L to lock right away.'**
  String get passcodeLockNowHint;

  /// No description provided for @passcodeLocked.
  ///
  /// In en, this message translates to:
  /// **'Mollygram is locked'**
  String get passcodeLocked;

  /// No description provided for @passcodeEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter your passcode to continue.'**
  String get passcodeEnter;

  /// No description provided for @passcodeHint.
  ///
  /// In en, this message translates to:
  /// **'Passcode'**
  String get passcodeHint;

  /// No description provided for @passcodeForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot passcode?'**
  String get passcodeForgot;

  /// No description provided for @passcodeLogOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out to remove the passcode?'**
  String get passcodeLogOutTitle;

  /// No description provided for @passcodeLogOutMessage.
  ///
  /// In en, this message translates to:
  /// **'The passcode can\'t be recovered. Logging out removes it; your chats come back when you sign in again.'**
  String get passcodeLogOutMessage;

  /// No description provided for @twoStep.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification'**
  String get twoStep;

  /// No description provided for @twoStepOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get twoStepOn;

  /// No description provided for @twoStepOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get twoStepOff;

  /// No description provided for @twoStepOffAbout.
  ///
  /// In en, this message translates to:
  /// **'Set a password that Telegram asks for, after the code, when you sign in on a new device.'**
  String get twoStepOffAbout;

  /// No description provided for @twoStepOnAbout.
  ///
  /// In en, this message translates to:
  /// **'Telegram asks for this password, after the code, when you sign in on a new device.'**
  String get twoStepOnAbout;

  /// No description provided for @twoStepLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load two-step verification.'**
  String get twoStepLoadFailed;

  /// No description provided for @twoStepSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get twoStepSetPassword;

  /// No description provided for @twoStepSetPasswordAbout.
  ///
  /// In en, this message translates to:
  /// **'A recovery email lets you reset the password if you forget it.'**
  String get twoStepSetPasswordAbout;

  /// No description provided for @twoStepChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get twoStepChangePassword;

  /// No description provided for @twoStepCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get twoStepCurrentPassword;

  /// No description provided for @twoStepNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get twoStepNewPassword;

  /// No description provided for @twoStepRepeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat the password'**
  String get twoStepRepeatPassword;

  /// No description provided for @twoStepHint.
  ///
  /// In en, this message translates to:
  /// **'Hint (optional)'**
  String get twoStepHint;

  /// No description provided for @twoStepHintIs.
  ///
  /// In en, this message translates to:
  /// **'Hint: {hint}'**
  String twoStepHintIs(String hint);

  /// No description provided for @twoStepHintIsPassword.
  ///
  /// In en, this message translates to:
  /// **'The hint can\'t be the password itself.'**
  String get twoStepHintIsPassword;

  /// No description provided for @twoStepRecoveryEmail.
  ///
  /// In en, this message translates to:
  /// **'Recovery email'**
  String get twoStepRecoveryEmail;

  /// No description provided for @twoStepRecoveryEmailAbout.
  ///
  /// In en, this message translates to:
  /// **'Telegram sends a code to this address to reset the password if you forget it.'**
  String get twoStepRecoveryEmailAbout;

  /// No description provided for @twoStepSetEmail.
  ///
  /// In en, this message translates to:
  /// **'Set recovery email'**
  String get twoStepSetEmail;

  /// No description provided for @twoStepChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change recovery email'**
  String get twoStepChangeEmail;

  /// No description provided for @twoStepEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'This email address isn\'t valid.'**
  String get twoStepEmailInvalid;

  /// No description provided for @twoStepPasswordRejected.
  ///
  /// In en, this message translates to:
  /// **'Telegram didn\'t accept this password. Try another.'**
  String get twoStepPasswordRejected;

  /// No description provided for @twoStepConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Confirm the recovery email'**
  String get twoStepConfirmEmail;

  /// No description provided for @twoStepCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Telegram sent a code to {email}.'**
  String twoStepCodeSent(String email);

  /// No description provided for @twoStepEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get twoStepEnterCode;

  /// No description provided for @twoStepCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get twoStepCode;

  /// No description provided for @twoStepCheckCode.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get twoStepCheckCode;

  /// No description provided for @twoStepResendCode.
  ///
  /// In en, this message translates to:
  /// **'Send the code again'**
  String get twoStepResendCode;

  /// No description provided for @twoStepCancelEmail.
  ///
  /// In en, this message translates to:
  /// **'Don\'t use this email'**
  String get twoStepCancelEmail;

  /// No description provided for @twoStepEmailConfirmed.
  ///
  /// In en, this message translates to:
  /// **'The recovery email is confirmed.'**
  String get twoStepEmailConfirmed;

  /// No description provided for @twoStepPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification is on.'**
  String get twoStepPasswordSet;

  /// No description provided for @twoStepPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'The password is changed.'**
  String get twoStepPasswordChanged;

  /// No description provided for @twoStepTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off two-step verification'**
  String get twoStepTurnOff;

  /// No description provided for @twoStepTurnOffAbout.
  ///
  /// In en, this message translates to:
  /// **'Signing in on a new device will then need only the code.'**
  String get twoStepTurnOffAbout;

  /// No description provided for @twoStepTurnOffAction.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get twoStepTurnOffAction;

  /// No description provided for @twoStepTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification is off.'**
  String get twoStepTurnedOff;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords don\'t match.'**
  String get passwordsDontMatch;

  /// No description provided for @accountTtlTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get accountTtlTitle;

  /// No description provided for @accountTtlRow.
  ///
  /// In en, this message translates to:
  /// **'If away for'**
  String get accountTtlRow;

  /// No description provided for @accountTtlQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete my account if I\'m away for'**
  String get accountTtlQuestion;

  /// No description provided for @accountTtlAbout.
  ///
  /// In en, this message translates to:
  /// **'If you don\'t come online at least once in this period, your account is deleted with all its messages and contacts.'**
  String get accountTtlAbout;

  /// No description provided for @ttlMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} month} other{{count} months}}'**
  String ttlMonths(int count);

  /// No description provided for @ttlDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String ttlDays(int count);

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @accountsAbout.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} accounts, each with its own chats and tabs.'**
  String accountsAbout(int count);

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// No description provided for @accountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account {number}'**
  String accountNumber(int number);

  /// No description provided for @switchToAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch to {name}'**
  String switchToAccount(String name);

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @logOutAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out of {name}?'**
  String logOutAccountTitle(String name);

  /// No description provided for @backToAccount.
  ///
  /// In en, this message translates to:
  /// **'Back to {name}'**
  String backToAccount(String name);

  /// No description provided for @loggingOut.
  ///
  /// In en, this message translates to:
  /// **'Logging out…'**
  String get loggingOut;

  /// No description provided for @accountsFull.
  ///
  /// In en, this message translates to:
  /// **'That\'s the limit of {count} accounts. Log out of one to add another.'**
  String accountsFull(int count);

  /// No description provided for @accountsLegacy.
  ///
  /// In en, this message translates to:
  /// **'The data folder from an earlier version couldn\'t be moved, so only this account can be used. Restart Mollygram to try again.'**
  String get accountsLegacy;

  /// No description provided for @duplicateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} is already signed in here'**
  String duplicateAccountTitle(String name);

  /// No description provided for @duplicateAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Switch to it and log out of this copy?'**
  String get duplicateAccountMessage;

  /// No description provided for @switchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchAccount;

  /// No description provided for @proxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get proxy;

  /// No description provided for @useProxy.
  ///
  /// In en, this message translates to:
  /// **'Use proxy'**
  String get useProxy;

  /// No description provided for @proxyHint.
  ///
  /// In en, this message translates to:
  /// **'Telegram connects through the selected proxy. Ping shows the round trip in milliseconds.'**
  String get proxyHint;

  /// No description provided for @savedProxies.
  ///
  /// In en, this message translates to:
  /// **'Saved proxies'**
  String get savedProxies;

  /// No description provided for @addProxy.
  ///
  /// In en, this message translates to:
  /// **'Add proxy'**
  String get addProxy;

  /// No description provided for @editProxy.
  ///
  /// In en, this message translates to:
  /// **'Edit proxy'**
  String get editProxy;

  /// No description provided for @proxyServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get proxyServer;

  /// No description provided for @proxyPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get proxyPort;

  /// No description provided for @proxyUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get proxyUsername;

  /// No description provided for @proxyPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get proxyPassword;

  /// No description provided for @proxySecret.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get proxySecret;

  /// No description provided for @proxyCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get proxyCheck;

  /// No description provided for @proxyChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get proxyChecking;

  /// No description provided for @proxyPing.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String proxyPing(int ms);

  /// No description provided for @proxyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get proxyUnavailable;

  /// No description provided for @proxyRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove proxy'**
  String get proxyRemove;

  /// No description provided for @proxyRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {address}?'**
  String proxyRemoveTitle(String address);

  /// No description provided for @proxyConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get proxyConnect;

  /// No description provided for @proxyFromLink.
  ///
  /// In en, this message translates to:
  /// **'Add this proxy and connect through it?'**
  String get proxyFromLink;

  /// No description provided for @proxyNone.
  ///
  /// In en, this message translates to:
  /// **'No proxies yet'**
  String get proxyNone;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageHint.
  ///
  /// In en, this message translates to:
  /// **'Changes the language of the app. Chats and messages stay as they are.'**
  String get languageHint;

  /// No description provided for @proxyEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get proxyEditButton;

  /// No description provided for @proxyInvalidSecret.
  ///
  /// In en, this message translates to:
  /// **'Invalid secret'**
  String get proxyInvalidSecret;

  /// No description provided for @proxyRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get proxyRemoveAction;

  /// No description provided for @proxyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the proxies.'**
  String get proxyLoadFailed;

  /// No description provided for @proxyShowSecret.
  ///
  /// In en, this message translates to:
  /// **'Show secret'**
  String get proxyShowSecret;

  /// No description provided for @proxyHideSecret.
  ///
  /// In en, this message translates to:
  /// **'Hide secret'**
  String get proxyHideSecret;

  /// No description provided for @pluginShowMessage.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get pluginShowMessage;

  /// No description provided for @pluginFilteredMessage.
  ///
  /// In en, this message translates to:
  /// **'Filtered by a plugin'**
  String get pluginFilteredMessage;

  /// No description provided for @passcodeWaitSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Too many tries. Try again in {count} second.} other{Too many tries. Try again in {count} seconds.}}'**
  String passcodeWaitSeconds(int count);

  /// No description provided for @passcodeWaitMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Too many tries. Try again in {count} minute.} other{Too many tries. Try again in {count} minutes.}}'**
  String passcodeWaitMinutes(int count);

  /// No description provided for @passcodeForgotNoSession.
  ///
  /// In en, this message translates to:
  /// **'Telegram couldn\'t start, so there is nothing to log out of yet. Try again when it is connected.'**
  String get passcodeForgotNoSession;

  /// No description provided for @passcodeLogOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t log out. The passcode stays until you can.'**
  String get passcodeLogOutFailed;

  /// No description provided for @passcodeUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The passcode couldn\'t be read from the keychain. The window stays locked until it can be.'**
  String get passcodeUnreadable;

  /// No description provided for @passcodeReadAgain.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get passcodeReadAgain;

  /// No description provided for @twoStepPendingAbout.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification turns on once you enter the code sent to the recovery email.'**
  String get twoStepPendingAbout;

  /// No description provided for @twoStepConfirmToFinish.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from the email to turn on two-step verification.'**
  String get twoStepConfirmToFinish;

  /// No description provided for @twoStepPasswordTooFresh.
  ///
  /// In en, this message translates to:
  /// **'The password was changed recently. Try again later.'**
  String get twoStepPasswordTooFresh;

  /// No description provided for @twoStepSessionTooFresh.
  ///
  /// In en, this message translates to:
  /// **'This device signed in recently. Try again later.'**
  String get twoStepSessionTooFresh;

  /// No description provided for @twoStepForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get twoStepForgotPassword;

  /// No description provided for @twoStepRecoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the password'**
  String get twoStepRecoverTitle;

  /// No description provided for @twoStepRecoverAbout.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to {pattern} and a new password.'**
  String twoStepRecoverAbout(String pattern);

  /// No description provided for @twoStepResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the password?'**
  String get twoStepResetTitle;

  /// No description provided for @twoStepResetMessage.
  ///
  /// In en, this message translates to:
  /// **'Without a recovery email, Telegram removes the password after a 7-day wait. Signing in with the password cancels the reset.'**
  String get twoStepResetMessage;

  /// No description provided for @twoStepResetAction.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get twoStepResetAction;

  /// No description provided for @twoStepResetPending.
  ///
  /// In en, this message translates to:
  /// **'The password will be removed on {date}.'**
  String twoStepResetPending(DateTime date);

  /// No description provided for @twoStepResetDeclined.
  ///
  /// In en, this message translates to:
  /// **'Telegram can\'t reset the password now. Try again after {date}.'**
  String twoStepResetDeclined(DateTime date);

  /// No description provided for @twoStepCancelReset.
  ///
  /// In en, this message translates to:
  /// **'Cancel reset'**
  String get twoStepCancelReset;

  /// No description provided for @ttlYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} year} other{{count} years}}'**
  String ttlYears(int count);

  /// No description provided for @accountTtlFooter.
  ///
  /// In en, this message translates to:
  /// **'Your account is deleted if you don\'t come online in this period.'**
  String get accountTtlFooter;

  /// No description provided for @secretChat.
  ///
  /// In en, this message translates to:
  /// **'Secret chat'**
  String get secretChat;

  /// No description provided for @newSecretChat.
  ///
  /// In en, this message translates to:
  /// **'New secret chat'**
  String get newSecretChat;

  /// No description provided for @startSecretChat.
  ///
  /// In en, this message translates to:
  /// **'Start secret chat'**
  String get startSecretChat;

  /// No description provided for @secretChatFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start a secret chat. Try again.'**
  String get secretChatFailed;

  /// No description provided for @secretChatWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name} to come online'**
  String secretChatWaiting(String name);

  /// No description provided for @secretChatExchangingKeys.
  ///
  /// In en, this message translates to:
  /// **'Exchanging encryption keys'**
  String get secretChatExchangingKeys;

  /// No description provided for @secretChatClosed.
  ///
  /// In en, this message translates to:
  /// **'Secret chat closed'**
  String get secretChatClosed;

  /// No description provided for @closeSecretChat.
  ///
  /// In en, this message translates to:
  /// **'Close secret chat'**
  String get closeSecretChat;

  /// No description provided for @deleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get deleteChat;

  /// No description provided for @deleteSecretChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this secret chat? It closes for both of you and its messages are removed here.'**
  String get deleteSecretChatTitle;

  /// No description provided for @encryptionKey.
  ///
  /// In en, this message translates to:
  /// **'Encryption key'**
  String get encryptionKey;

  /// No description provided for @encryptionKeyHint.
  ///
  /// In en, this message translates to:
  /// **'If this picture and these numbers look the same on {name}\'s device, your chat is end-to-end encrypted.'**
  String encryptionKeyHint(String name);

  /// No description provided for @encryptionKeyPending.
  ///
  /// In en, this message translates to:
  /// **'The key appears once the other person\'s app accepts the chat.'**
  String get encryptionKeyPending;

  /// No description provided for @selfDestructTitle.
  ///
  /// In en, this message translates to:
  /// **'Self-destruct timer'**
  String get selfDestructTitle;

  /// No description provided for @selfDestructOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get selfDestructOff;

  /// No description provided for @selfDestructSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 second} other{{count} seconds}}'**
  String selfDestructSeconds(int count);

  /// No description provided for @selfDestructMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 minute} other{{count} minutes}}'**
  String selfDestructMinutes(int count);

  /// No description provided for @selfDestructHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 hour} other{{count} hours}}'**
  String selfDestructHours(int count);

  /// No description provided for @selfDestructDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day} other{{count} days}}'**
  String selfDestructDays(int count);

  /// No description provided for @selfDestructWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 week} other{{count} weeks}}'**
  String selfDestructWeeks(int count);

  /// No description provided for @allowSecretScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Allow screenshots in secret chats'**
  String get allowSecretScreenshots;

  /// No description provided for @allowSecretScreenshotsHint.
  ///
  /// In en, this message translates to:
  /// **'Risky: the other person expects secret chats to stay off screenshots and screen recordings'**
  String get allowSecretScreenshotsHint;

  /// No description provided for @secretScreenshotsOff.
  ///
  /// In en, this message translates to:
  /// **'Secret chats are kept out of screenshots by default; on macOS 15 and later this is best effort'**
  String get secretScreenshotsOff;

  /// No description provided for @selfDestructFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the self-destruct timer. The secret chat isn\'t ready yet, or the connection was lost.'**
  String get selfDestructFailed;

  /// No description provided for @stickersAndEmoji.
  ///
  /// In en, this message translates to:
  /// **'Stickers and emoji'**
  String get stickersAndEmoji;

  /// No description provided for @largeEmoji.
  ///
  /// In en, this message translates to:
  /// **'Large emoji'**
  String get largeEmoji;

  /// No description provided for @largeEmojiHint.
  ///
  /// In en, this message translates to:
  /// **'A message of up to three emoji is shown large.'**
  String get largeEmojiHint;

  /// No description provided for @loopStickers.
  ///
  /// In en, this message translates to:
  /// **'Loop animated stickers'**
  String get loopStickers;

  /// No description provided for @animatedEmoji.
  ///
  /// In en, this message translates to:
  /// **'Animated emoji'**
  String get animatedEmoji;

  /// No description provided for @myStickers.
  ///
  /// In en, this message translates to:
  /// **'My stickers'**
  String get myStickers;

  /// No description provided for @myEmoji.
  ///
  /// In en, this message translates to:
  /// **'My emoji'**
  String get myEmoji;

  /// No description provided for @customEmoji.
  ///
  /// In en, this message translates to:
  /// **'Custom emoji'**
  String get customEmoji;

  /// No description provided for @trendingStickers.
  ///
  /// In en, this message translates to:
  /// **'Trending stickers'**
  String get trendingStickers;

  /// No description provided for @trendingEmoji.
  ///
  /// In en, this message translates to:
  /// **'Trending emoji'**
  String get trendingEmoji;

  /// No description provided for @archivedStickers.
  ///
  /// In en, this message translates to:
  /// **'Archived stickers'**
  String get archivedStickers;

  /// No description provided for @archivedEmoji.
  ///
  /// In en, this message translates to:
  /// **'Archived emoji'**
  String get archivedEmoji;

  /// No description provided for @stickerSetsHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder. Right-click a set to archive or remove it.'**
  String get stickerSetsHint;

  /// No description provided for @archiveSet.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveSet;

  /// No description provided for @restoreSet.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreSet;

  /// No description provided for @addSet.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addSet;

  /// No description provided for @addByLink.
  ///
  /// In en, this message translates to:
  /// **'Add by link'**
  String get addByLink;

  /// No description provided for @openSetLink.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openSetLink;

  /// No description provided for @stickerSetNotFound.
  ///
  /// In en, this message translates to:
  /// **'There is no set at this link.'**
  String get stickerSetNotFound;

  /// No description provided for @noArchivedSets.
  ///
  /// In en, this message translates to:
  /// **'Nothing archived'**
  String get noArchivedSets;

  /// No description provided for @stickerSetLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the sets.'**
  String get stickerSetLoadFailed;

  /// No description provided for @stickerCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} sticker} other{{count} stickers}}'**
  String stickerCount(int count);

  /// No description provided for @emojiCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} emoji} other{{count} emoji}}'**
  String emojiCount(int count);

  /// No description provided for @removeStickerSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this sticker set?'**
  String get removeStickerSetTitle;

  /// No description provided for @removeEmojiSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this emoji set?'**
  String get removeEmojiSetTitle;

  /// No description provided for @stickerSetLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the set. Check your connection and try again.'**
  String get stickerSetLookupFailed;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @shortcutsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search shortcuts'**
  String get shortcutsSearch;

  /// No description provided for @shortcutsHint.
  ///
  /// In en, this message translates to:
  /// **'Click a shortcut, then press the new keys. Esc cancels, Delete removes the shortcut.'**
  String get shortcutsHint;

  /// No description provided for @shortcutsGroupApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get shortcutsGroupApp;

  /// No description provided for @shortcutsGroupChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get shortcutsGroupChat;

  /// No description provided for @shortcutsGroupNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get shortcutsGroupNavigation;

  /// No description provided for @shortcutsGroupAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get shortcutsGroupAccounts;

  /// No description provided for @shortcutsGroupPlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get shortcutsGroupPlugins;

  /// No description provided for @shortcutNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get shortcutNone;

  /// No description provided for @shortcutRecording.
  ///
  /// In en, this message translates to:
  /// **'Type a shortcut'**
  String get shortcutRecording;

  /// No description provided for @shortcutChange.
  ///
  /// In en, this message translates to:
  /// **'Change shortcut'**
  String get shortcutChange;

  /// No description provided for @shortcutNeedsModifier.
  ///
  /// In en, this message translates to:
  /// **'Add Ctrl or Alt to the key'**
  String get shortcutNeedsModifier;

  /// No description provided for @shortcutNeedsModifierMac.
  ///
  /// In en, this message translates to:
  /// **'Add ⌘, ⌃ or ⌥ to the key'**
  String get shortcutNeedsModifierMac;

  /// No description provided for @shortcutReserved.
  ///
  /// In en, this message translates to:
  /// **'Used by the system'**
  String get shortcutReserved;

  /// No description provided for @shortcutReservedMac.
  ///
  /// In en, this message translates to:
  /// **'Used by macOS'**
  String get shortcutReservedMac;

  /// No description provided for @shortcutUsedBy.
  ///
  /// In en, this message translates to:
  /// **'Already used by “{title}”'**
  String shortcutUsedBy(String title);

  /// No description provided for @shortcutReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get shortcutReplace;

  /// No description provided for @shortcutRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore default'**
  String get shortcutRestore;

  /// No description provided for @shortcutsRestoreAll.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get shortcutsRestoreAll;

  /// No description provided for @shortcutsRestoreAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore all shortcuts?'**
  String get shortcutsRestoreAllTitle;

  /// No description provided for @shortcutsRestoreAllMessage.
  ///
  /// In en, this message translates to:
  /// **'Every shortcut you changed goes back to its default.'**
  String get shortcutsRestoreAllMessage;

  /// No description provided for @shortcutsRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get shortcutsRestoreConfirm;

  /// No description provided for @adminTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get adminTitleHint;

  /// No description provided for @adminTitleNote.
  ///
  /// In en, this message translates to:
  /// **'Shown to members in place of \"admin\".'**
  String get adminTitleNote;

  /// No description provided for @permCreateTopics.
  ///
  /// In en, this message translates to:
  /// **'Create topics'**
  String get permCreateTopics;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @permissionsEveryone.
  ///
  /// In en, this message translates to:
  /// **'What members can do'**
  String get permissionsEveryone;

  /// No description provided for @slowMode.
  ///
  /// In en, this message translates to:
  /// **'Slow mode'**
  String get slowMode;

  /// No description provided for @slowModeOffNote.
  ///
  /// In en, this message translates to:
  /// **'Members can send messages as often as they like.'**
  String get slowModeOffNote;

  /// No description provided for @slowModeNote.
  ///
  /// In en, this message translates to:
  /// **'Members can send one message every {interval}.'**
  String slowModeNote(String interval);

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @secondsShort.
  ///
  /// In en, this message translates to:
  /// **'{count}s'**
  String secondsShort(int count);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String minutesShort(int count);

  /// No description provided for @hoursShort.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String hoursShort(int count);

  /// No description provided for @removedUsers.
  ///
  /// In en, this message translates to:
  /// **'Removed users'**
  String get removedUsers;

  /// No description provided for @noRemovedUsers.
  ///
  /// In en, this message translates to:
  /// **'Nobody is banned or restricted.'**
  String get noRemovedUsers;

  /// No description provided for @unban.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get unban;

  /// No description provided for @banned.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get banned;

  /// No description provided for @bannedUntil.
  ///
  /// In en, this message translates to:
  /// **'Banned {until}'**
  String bannedUntil(String until);

  /// No description provided for @restricted.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get restricted;

  /// No description provided for @cannot.
  ///
  /// In en, this message translates to:
  /// **'Can\'t {what}'**
  String cannot(String what);

  /// No description provided for @untilDate.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String untilDate(String date);

  /// No description provided for @joinRequests.
  ///
  /// In en, this message translates to:
  /// **'Join requests'**
  String get joinRequests;

  /// No description provided for @noJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'Nobody is waiting to join.'**
  String get noJoinRequests;

  /// No description provided for @requestedOn.
  ///
  /// In en, this message translates to:
  /// **'Asked {date}'**
  String requestedOn(String date);

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @recentActions.
  ///
  /// In en, this message translates to:
  /// **'Recent actions'**
  String get recentActions;

  /// No description provided for @recentActionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the recent actions.'**
  String get recentActionsFailed;

  /// No description provided for @noRecentActions.
  ///
  /// In en, this message translates to:
  /// **'No recent actions.'**
  String get noRecentActions;

  /// No description provided for @recentActionsNote.
  ///
  /// In en, this message translates to:
  /// **'Actions of the last 48 hours.'**
  String get recentActionsNote;

  /// No description provided for @allAdmins.
  ///
  /// In en, this message translates to:
  /// **'All admins'**
  String get allAdmins;

  /// No description provided for @logMedia.
  ///
  /// In en, this message translates to:
  /// **'a media message'**
  String get logMedia;

  /// No description provided for @logEditedMessage.
  ///
  /// In en, this message translates to:
  /// **'edited a message: {text}'**
  String logEditedMessage(String text);

  /// No description provided for @logDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'deleted a message: {text}'**
  String logDeletedMessage(String text);

  /// No description provided for @logPinnedMessage.
  ///
  /// In en, this message translates to:
  /// **'pinned a message: {text}'**
  String logPinnedMessage(String text);

  /// No description provided for @logUnpinnedMessage.
  ///
  /// In en, this message translates to:
  /// **'unpinned a message'**
  String get logUnpinnedMessage;

  /// No description provided for @logStoppedPoll.
  ///
  /// In en, this message translates to:
  /// **'stopped a poll'**
  String get logStoppedPoll;

  /// No description provided for @logJoined.
  ///
  /// In en, this message translates to:
  /// **'joined'**
  String get logJoined;

  /// No description provided for @logJoinedByLink.
  ///
  /// In en, this message translates to:
  /// **'joined by the link {link}'**
  String logJoinedByLink(String link);

  /// No description provided for @logJoinedByRequest.
  ///
  /// In en, this message translates to:
  /// **'joined, approved by {name}'**
  String logJoinedByRequest(String name);

  /// No description provided for @logInvited.
  ///
  /// In en, this message translates to:
  /// **'added {name}'**
  String logInvited(String name);

  /// No description provided for @logLeft.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get logLeft;

  /// No description provided for @logPromoted.
  ///
  /// In en, this message translates to:
  /// **'made {name} an admin or changed their rights'**
  String logPromoted(String name);

  /// No description provided for @logDemoted.
  ///
  /// In en, this message translates to:
  /// **'dismissed {name} as admin'**
  String logDemoted(String name);

  /// No description provided for @logBanned.
  ///
  /// In en, this message translates to:
  /// **'banned {name}'**
  String logBanned(String name);

  /// No description provided for @logRestricted.
  ///
  /// In en, this message translates to:
  /// **'restricted {name}'**
  String logRestricted(String name);

  /// No description provided for @logUnrestricted.
  ///
  /// In en, this message translates to:
  /// **'lifted the restrictions of {name}'**
  String logUnrestricted(String name);

  /// No description provided for @logTitleChanged.
  ///
  /// In en, this message translates to:
  /// **'gave {name} the title {title}'**
  String logTitleChanged(String name, String title);

  /// No description provided for @logTitleSet.
  ///
  /// In en, this message translates to:
  /// **'renamed the chat to {title}'**
  String logTitleSet(String title);

  /// No description provided for @logDescriptionChanged.
  ///
  /// In en, this message translates to:
  /// **'changed the description'**
  String get logDescriptionChanged;

  /// No description provided for @logPhotoChanged.
  ///
  /// In en, this message translates to:
  /// **'changed the photo'**
  String get logPhotoChanged;

  /// No description provided for @logPhotoRemoved.
  ///
  /// In en, this message translates to:
  /// **'removed the photo'**
  String get logPhotoRemoved;

  /// No description provided for @logMadePrivate.
  ///
  /// In en, this message translates to:
  /// **'made the chat private'**
  String get logMadePrivate;

  /// No description provided for @logMadePublic.
  ///
  /// In en, this message translates to:
  /// **'made the chat public at t.me/{username}'**
  String logMadePublic(String username);

  /// No description provided for @logUsernamesChanged.
  ///
  /// In en, this message translates to:
  /// **'changed the links'**
  String get logUsernamesChanged;

  /// No description provided for @logPermissionsChanged.
  ///
  /// In en, this message translates to:
  /// **'changed the permissions'**
  String get logPermissionsChanged;

  /// No description provided for @logSlowModeOff.
  ///
  /// In en, this message translates to:
  /// **'turned slow mode off'**
  String get logSlowModeOff;

  /// No description provided for @logSlowModeOn.
  ///
  /// In en, this message translates to:
  /// **'set slow mode to {interval}'**
  String logSlowModeOn(String interval);

  /// No description provided for @logLinked.
  ///
  /// In en, this message translates to:
  /// **'linked a chat'**
  String get logLinked;

  /// No description provided for @logUnlinked.
  ///
  /// In en, this message translates to:
  /// **'unlinked the chat'**
  String get logUnlinked;

  /// No description provided for @logReactionsChanged.
  ///
  /// In en, this message translates to:
  /// **'changed the allowed reactions'**
  String get logReactionsChanged;

  /// No description provided for @logHistoryShown.
  ///
  /// In en, this message translates to:
  /// **'made the history visible to new members'**
  String get logHistoryShown;

  /// No description provided for @logHistoryHidden.
  ///
  /// In en, this message translates to:
  /// **'hid the history from new members'**
  String get logHistoryHidden;

  /// No description provided for @logInvitesOn.
  ///
  /// In en, this message translates to:
  /// **'let members add others'**
  String get logInvitesOn;

  /// No description provided for @logInvitesOff.
  ///
  /// In en, this message translates to:
  /// **'stopped members adding others'**
  String get logInvitesOff;

  /// No description provided for @logSignaturesOn.
  ///
  /// In en, this message translates to:
  /// **'turned signatures on'**
  String get logSignaturesOn;

  /// No description provided for @logSignaturesOff.
  ///
  /// In en, this message translates to:
  /// **'turned signatures off'**
  String get logSignaturesOff;

  /// No description provided for @logProtectedOn.
  ///
  /// In en, this message translates to:
  /// **'turned forwarding off'**
  String get logProtectedOn;

  /// No description provided for @logProtectedOff.
  ///
  /// In en, this message translates to:
  /// **'turned forwarding on'**
  String get logProtectedOff;

  /// No description provided for @logLinkEdited.
  ///
  /// In en, this message translates to:
  /// **'edited the link {link}'**
  String logLinkEdited(String link);

  /// No description provided for @logLinkRevoked.
  ///
  /// In en, this message translates to:
  /// **'revoked the link {link}'**
  String logLinkRevoked(String link);

  /// No description provided for @logLinkDeleted.
  ///
  /// In en, this message translates to:
  /// **'deleted the link {link}'**
  String logLinkDeleted(String link);

  /// No description provided for @logVideoChatStarted.
  ///
  /// In en, this message translates to:
  /// **'started a video chat'**
  String get logVideoChatStarted;

  /// No description provided for @logVideoChatEnded.
  ///
  /// In en, this message translates to:
  /// **'ended the video chat'**
  String get logVideoChatEnded;

  /// No description provided for @logTopicsOn.
  ///
  /// In en, this message translates to:
  /// **'turned topics on'**
  String get logTopicsOn;

  /// No description provided for @logTopicsOff.
  ///
  /// In en, this message translates to:
  /// **'turned topics off'**
  String get logTopicsOff;

  /// No description provided for @logTopicCreated.
  ///
  /// In en, this message translates to:
  /// **'created the topic {name}'**
  String logTopicCreated(String name);

  /// No description provided for @logTopicEdited.
  ///
  /// In en, this message translates to:
  /// **'edited the topic {name}'**
  String logTopicEdited(String name);

  /// No description provided for @logTopicDeleted.
  ///
  /// In en, this message translates to:
  /// **'deleted the topic {name}'**
  String logTopicDeleted(String name);

  /// No description provided for @logTopicToggled.
  ///
  /// In en, this message translates to:
  /// **'closed or reopened the topic {name}'**
  String logTopicToggled(String name);

  /// No description provided for @logTopicPinned.
  ///
  /// In en, this message translates to:
  /// **'pinned or unpinned a topic'**
  String get logTopicPinned;

  /// No description provided for @logStickerSetChanged.
  ///
  /// In en, this message translates to:
  /// **'changed the sticker set'**
  String get logStickerSetChanged;

  /// No description provided for @logAutoDeleteChanged.
  ///
  /// In en, this message translates to:
  /// **'changed the auto-delete timer'**
  String get logAutoDeleteChanged;

  /// No description provided for @logOther.
  ///
  /// In en, this message translates to:
  /// **'changed a setting'**
  String get logOther;

  /// No description provided for @groupType.
  ///
  /// In en, this message translates to:
  /// **'Group type'**
  String get groupType;

  /// No description provided for @channelType.
  ///
  /// In en, this message translates to:
  /// **'Channel type'**
  String get channelType;

  /// No description provided for @privateChat.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateChat;

  /// No description provided for @publicChat.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get publicChat;

  /// No description provided for @privateGroupNote.
  ///
  /// In en, this message translates to:
  /// **'Only people with an invite link can join.'**
  String get privateGroupNote;

  /// No description provided for @publicGroupNote.
  ///
  /// In en, this message translates to:
  /// **'Anyone can find the group in search and join.'**
  String get publicGroupNote;

  /// No description provided for @privateChannelNote.
  ///
  /// In en, this message translates to:
  /// **'Only people with an invite link can subscribe.'**
  String get privateChannelNote;

  /// No description provided for @publicChannelNote.
  ///
  /// In en, this message translates to:
  /// **'Anyone can find the channel in search and subscribe.'**
  String get publicChannelNote;

  /// No description provided for @usernameTaken.
  ///
  /// In en, this message translates to:
  /// **'This link is already taken.'**
  String get usernameTaken;

  /// No description provided for @usernameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 5 to 32 letters, digits and underscores, starting with a letter.'**
  String get usernameInvalid;

  /// No description provided for @usernameTooMany.
  ///
  /// In en, this message translates to:
  /// **'You have too many public chats. Make one private first.'**
  String get usernameTooMany;

  /// No description provided for @usernameNotSet.
  ///
  /// In en, this message translates to:
  /// **'The channel is created, but t.me/{username} is taken. Pick another link in its info.'**
  String usernameNotSet(String username);

  /// No description provided for @publicLinkOptional.
  ///
  /// In en, this message translates to:
  /// **'public link (optional)'**
  String get publicLinkOptional;

  /// No description provided for @reactions.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get reactions;

  /// No description provided for @reactionsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reactionsAll;

  /// No description provided for @reactionsSome.
  ///
  /// In en, this message translates to:
  /// **'Some'**
  String get reactionsSome;

  /// No description provided for @reactionsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get reactionsNone;

  /// No description provided for @reactionsAllNote.
  ///
  /// In en, this message translates to:
  /// **'Members can react with any emoji.'**
  String get reactionsAllNote;

  /// No description provided for @reactionsSomeNote.
  ///
  /// In en, this message translates to:
  /// **'Members can react only with the emoji picked here.'**
  String get reactionsSomeNote;

  /// No description provided for @reactionsNoneNote.
  ///
  /// In en, this message translates to:
  /// **'Nobody can react to messages.'**
  String get reactionsNoneNote;

  /// No description provided for @discussionGroup.
  ///
  /// In en, this message translates to:
  /// **'Discussion group'**
  String get discussionGroup;

  /// No description provided for @linkedChannel.
  ///
  /// In en, this message translates to:
  /// **'Linked channel'**
  String get linkedChannel;

  /// No description provided for @discussionGroupNote.
  ///
  /// In en, this message translates to:
  /// **'Comments under posts go to this group.'**
  String get discussionGroupNote;

  /// No description provided for @linkedChannelNote.
  ///
  /// In en, this message translates to:
  /// **'This group holds the comments of the channel.'**
  String get linkedChannelNote;

  /// No description provided for @pickDiscussionGroup.
  ///
  /// In en, this message translates to:
  /// **'Pick a group you manage for the comments under posts.'**
  String get pickDiscussionGroup;

  /// No description provided for @noSuitableGroups.
  ///
  /// In en, this message translates to:
  /// **'You have no group to link. Create one first.'**
  String get noSuitableGroups;

  /// No description provided for @unlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlink;

  /// No description provided for @unlinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlink?'**
  String get unlinkTitle;

  /// No description provided for @unlinkGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Posts will have no comments until another group is linked.'**
  String get unlinkGroupMessage;

  /// No description provided for @unlinkChannelMessage.
  ///
  /// In en, this message translates to:
  /// **'The group will no longer hold the channel\'s comments.'**
  String get unlinkChannelMessage;

  /// No description provided for @addMembers.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get addMembers;

  /// No description provided for @addSubscribers.
  ///
  /// In en, this message translates to:
  /// **'Add subscribers'**
  String get addSubscribers;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @editLink.
  ///
  /// In en, this message translates to:
  /// **'Edit link'**
  String get editLink;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @historyForNewMembers.
  ///
  /// In en, this message translates to:
  /// **'Show history to new members'**
  String get historyForNewMembers;

  /// No description provided for @topics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get topics;

  /// No description provided for @approveNewMembers.
  ///
  /// In en, this message translates to:
  /// **'Approve new members'**
  String get approveNewMembers;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @ofCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}'**
  String ofCount(int count, int total);

  /// No description provided for @chatLinkHint.
  ///
  /// In en, this message translates to:
  /// **'link'**
  String get chatLinkHint;

  /// No description provided for @chatLinkAvailable.
  ///
  /// In en, this message translates to:
  /// **'This link is available.'**
  String get chatLinkAvailable;

  /// No description provided for @chatBackground.
  ///
  /// In en, this message translates to:
  /// **'Chat background'**
  String get chatBackground;

  /// No description provided for @chatBackgroundHint.
  ///
  /// In en, this message translates to:
  /// **'Gradients follow the theme. A picture of your own is dimmed a little in the dark theme.'**
  String get chatBackgroundHint;

  /// No description provided for @wallpaperMist.
  ///
  /// In en, this message translates to:
  /// **'Mist'**
  String get wallpaperMist;

  /// No description provided for @wallpaperSage.
  ///
  /// In en, this message translates to:
  /// **'Sage'**
  String get wallpaperSage;

  /// No description provided for @wallpaperLinen.
  ///
  /// In en, this message translates to:
  /// **'Linen'**
  String get wallpaperLinen;

  /// No description provided for @wallpaperClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get wallpaperClassic;

  /// No description provided for @wallpaperOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get wallpaperOcean;

  /// No description provided for @wallpaperLavender.
  ///
  /// In en, this message translates to:
  /// **'Lavender'**
  String get wallpaperLavender;

  /// No description provided for @wallpaperSand.
  ///
  /// In en, this message translates to:
  /// **'Sand'**
  String get wallpaperSand;

  /// No description provided for @wallpaperGraphite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get wallpaperGraphite;

  /// No description provided for @wallpaperPlain.
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get wallpaperPlain;

  /// No description provided for @wallpaperPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get wallpaperPicture;

  /// No description provided for @choosePicture.
  ///
  /// In en, this message translates to:
  /// **'Choose picture…'**
  String get choosePicture;

  /// No description provided for @changePicture.
  ///
  /// In en, this message translates to:
  /// **'Change picture…'**
  String get changePicture;

  /// No description provided for @blurPicture.
  ///
  /// In en, this message translates to:
  /// **'Blur picture'**
  String get blurPicture;

  /// No description provided for @nightSchedule.
  ///
  /// In en, this message translates to:
  /// **'Dark theme by schedule'**
  String get nightSchedule;

  /// No description provided for @nightScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'Switches to the dark theme between these hours, whatever the theme above says.'**
  String get nightScheduleHint;

  /// No description provided for @nightFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get nightFrom;

  /// No description provided for @nightTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get nightTo;

  /// No description provided for @blurTheme.
  ///
  /// In en, this message translates to:
  /// **'Vesper Blur'**
  String get blurTheme;

  /// No description provided for @blurThemeHint.
  ///
  /// In en, this message translates to:
  /// **'A dark, matte window that blurs the desktop behind it. Replaces the theme above while on.'**
  String get blurThemeHint;

  /// No description provided for @blurOpacity.
  ///
  /// In en, this message translates to:
  /// **'Window opacity'**
  String get blurOpacity;

  /// No description provided for @layout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get layout;

  /// No description provided for @mediaCorners.
  ///
  /// In en, this message translates to:
  /// **'Media corners'**
  String get mediaCorners;

  /// No description provided for @cornerSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get cornerSmall;

  /// No description provided for @cornerMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get cornerMedium;

  /// No description provided for @cornerLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get cornerLarge;

  /// No description provided for @compactLayout.
  ///
  /// In en, this message translates to:
  /// **'Compact layout'**
  String get compactLayout;

  /// No description provided for @compactLayoutHint.
  ///
  /// In en, this message translates to:
  /// **'Tighter rows in the chat list and less air between messages.'**
  String get compactLayoutHint;

  /// No description provided for @appIcon.
  ///
  /// In en, this message translates to:
  /// **'App icon'**
  String get appIcon;

  /// No description provided for @appIconHint.
  ///
  /// In en, this message translates to:
  /// **'The icon in the Dock while Mollygram runs. Finder keeps the one the app ships with.'**
  String get appIconHint;

  /// No description provided for @appIconCrimson.
  ///
  /// In en, this message translates to:
  /// **'Crimson'**
  String get appIconCrimson;

  /// No description provided for @appIconBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get appIconBlue;

  /// No description provided for @appIconGraphite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get appIconGraphite;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @downloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No downloads'**
  String get downloadsEmpty;

  /// No description provided for @downloadsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Files you save from chats will show up here.'**
  String get downloadsEmptyHint;

  /// No description provided for @pauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause all'**
  String get pauseAll;

  /// No description provided for @resumeAll.
  ///
  /// In en, this message translates to:
  /// **'Resume all'**
  String get resumeAll;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @clearFinished.
  ///
  /// In en, this message translates to:
  /// **'Clear finished'**
  String get clearFinished;

  /// No description provided for @removeFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get removeFromList;

  /// No description provided for @downloadPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadPaused;

  /// No description provided for @downloadProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String downloadProgress(String done, String total);

  /// No description provided for @downloadsActive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file downloading} other{{count} files downloading}}'**
  String downloadsActive(int count);

  /// No description provided for @downloadsAllPaused.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} download paused} other{{count} downloads paused}}'**
  String downloadsAllPaused(int count);

  /// No description provided for @downloadsFinished.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file downloaded} other{{count} files downloaded}}'**
  String downloadsFinished(int count);

  /// No description provided for @translateTo.
  ///
  /// In en, this message translates to:
  /// **'Translate to {language}'**
  String translateTo(String language);

  /// No description provided for @translatedFrom.
  ///
  /// In en, this message translates to:
  /// **'Translated from {language}'**
  String translatedFrom(String language);

  /// No description provided for @translated.
  ///
  /// In en, this message translates to:
  /// **'Translated'**
  String get translated;

  /// No description provided for @translating.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get translating;

  /// No description provided for @translateShowOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get translateShowOriginal;

  /// No description provided for @translateOptions.
  ///
  /// In en, this message translates to:
  /// **'Translation options'**
  String get translateOptions;

  /// No description provided for @translateChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Translate to…'**
  String get translateChooseLanguage;

  /// No description provided for @translateSkipLanguage.
  ///
  /// In en, this message translates to:
  /// **'Don\'t translate {language}'**
  String translateSkipLanguage(String language);

  /// No description provided for @translateHideBar.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get translateHideBar;

  /// No description provided for @translateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t translate some messages'**
  String get translateFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
