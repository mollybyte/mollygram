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

  /// No description provided for @noChatsFound.
  ///
  /// In en, this message translates to:
  /// **'No chats found'**
  String get noChatsFound;

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

  /// No description provided for @sendAsFiles.
  ///
  /// In en, this message translates to:
  /// **'Send as files'**
  String get sendAsFiles;

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

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get statusOnline;

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

  /// No description provided for @statusBot.
  ///
  /// In en, this message translates to:
  /// **'bot'**
  String get statusBot;

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

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get blockUser;

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

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

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
  /// **'No stickers yet'**
  String get noStickerSets;

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

  /// No description provided for @commentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} comment} other{{count} comments}}'**
  String commentCount(int count);

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

  /// No description provided for @chatActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t do that, try again'**
  String get chatActionFailed;

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

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

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
