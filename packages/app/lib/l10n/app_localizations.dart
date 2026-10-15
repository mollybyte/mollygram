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
  /// **'Sending a message still shows you online for a moment; Telegram does that for every app.'**
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
