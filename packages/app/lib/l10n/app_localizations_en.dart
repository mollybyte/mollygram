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
  String sidebarSearchHint(String shortcut) {
    return 'Search or $shortcut';
  }

  @override
  String get folderAll => 'All';

  @override
  String get noChats => 'No chats yet';

  @override
  String get connectionWaitingForNetwork => 'Waiting for network…';

  @override
  String get connectionConnectingToProxy => 'Connecting to proxy…';

  @override
  String get connectionConnecting => 'Connecting…';

  @override
  String get connectionUpdating => 'Updating…';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get draftLabel => 'Draft:';

  @override
  String get newMessage => 'New message';

  @override
  String get contacts => 'Contacts';

  @override
  String get peopleSearchHint => 'Name or username';

  @override
  String get recentChats => 'Recent';

  @override
  String get globalSearch => 'Global search';

  @override
  String get noContacts => 'No contacts yet';

  @override
  String get presenceOnline => 'online';

  @override
  String get presenceJustNow => 'last seen just now';

  @override
  String presenceMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'last seen $count minutes ago',
      one: 'last seen $count minute ago',
    );
    return '$_temp0';
  }

  @override
  String presenceToday(Object time) {
    return 'last seen today at $time';
  }

  @override
  String presenceYesterday(Object time) {
    return 'last seen yesterday at $time';
  }

  @override
  String presenceDate(Object date) {
    return 'last seen $date';
  }

  @override
  String get presenceRecently => 'last seen recently';

  @override
  String get presenceLastWeek => 'last seen within a week';

  @override
  String get presenceLastMonth => 'last seen within a month';

  @override
  String get presenceLongAgo => 'last seen a long time ago';

  @override
  String get presenceBot => 'bot';

  @override
  String get addContact => 'Add contact';

  @override
  String get contactFirstName => 'First name';

  @override
  String get contactLastName => 'Last name (optional)';

  @override
  String get contactPhone => 'Phone number';

  @override
  String get contactAdd => 'Add';

  @override
  String get contactFirstNameRequired => 'Enter a first name';

  @override
  String get contactPhoneRequired => 'Enter a phone number';

  @override
  String get contactNotOnTelegram => 'This number is not on Telegram';

  @override
  String get contactAddFailed =>
      'Couldn\'t add the contact. Check the connection and try again.';

  @override
  String get deleteContact => 'Delete contact';

  @override
  String deleteContactTitle(Object name) {
    return 'Delete $name from contacts?';
  }

  @override
  String get deleteContactFailed => 'Couldn\'t delete the contact';

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
  String get voiceHoldToRecord => 'Hold to record a voice message';

  @override
  String get voiceReleaseToCancel => 'Release to cancel';

  @override
  String get voiceDelete => 'Delete recording';

  @override
  String get voiceMicrophoneDenied =>
      'Mollygram has no access to the microphone.';

  @override
  String get voiceOpenSettings => 'Open System Settings';

  @override
  String get voiceRecordFailed => 'Couldn\'t start recording';

  @override
  String get voiceSendFailed => 'Couldn\'t send the voice message';

  @override
  String get videoHoldToRecord => 'Hold to record a video message';

  @override
  String get videoCameraDenied => 'Mollygram has no access to the camera.';

  @override
  String get videoSwitchCamera => 'Switch camera';

  @override
  String get senderYou => 'You';

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
  String get transcribe => 'Transcribe';

  @override
  String get hideTranscript => 'Hide transcript';

  @override
  String get transcribing => 'Transcribing…';

  @override
  String get transcriptionFailed => 'Couldn\'t transcribe this message';

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
  String get notifications => 'Notifications';

  @override
  String get notificationsSectionAlerts => 'Alerts';

  @override
  String get notificationsSectionBadge => 'Dock icon';

  @override
  String get notificationsShow => 'Show notifications';

  @override
  String get notificationsShowHint =>
      'Banners appear while Mollygram is in the background. Muted chats stay silent.';

  @override
  String get notificationsPreview => 'Show message text';

  @override
  String get notificationsPreviewHint =>
      'When off, a notification only says who wrote.';

  @override
  String get notificationsSound => 'Play sound';

  @override
  String get notificationsBadge => 'Show unread count';

  @override
  String get notificationsBadgeMuted => 'Include muted chats';

  @override
  String get notificationsBadgeMessages => 'Count messages instead of chats';

  @override
  String get notificationsDenied =>
      'Notifications for Mollygram are turned off in System Settings.';

  @override
  String get notificationsOpenSystemSettings => 'Open System Settings';

  @override
  String get notificationHiddenText => 'New message';

  @override
  String get notificationReply => 'Reply';

  @override
  String get notificationSend => 'Send';

  @override
  String get notificationReplyPlaceholder => 'Message';

  @override
  String get notificationMarkRead => 'Mark as read';

  @override
  String get sendFailed => 'The message wasn\'t sent. Try again';

  @override
  String get noMessages => 'No messages here yet';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get edited => 'edited';

  @override
  String forwardedFrom(String name) {
    return 'Forwarded from $name';
  }

  @override
  String get deletedMessage => 'Deleted message';

  @override
  String get deletedMark => 'deleted';

  @override
  String deletedAt(String time) {
    return 'Deleted $time';
  }

  @override
  String get menuEditHistory => 'Edit history';

  @override
  String get editHistoryTitle => 'Edit history';

  @override
  String get editHistoryCurrent => 'Current version';

  @override
  String get editHistoryEmpty => 'No earlier versions were kept';

  @override
  String get loadingMessage => 'Loading…';

  @override
  String get unknownSender => 'Unknown';

  @override
  String get hiddenAccount => 'Hidden account';

  @override
  String get download => 'Download';

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get openFile => 'Open';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get menuReply => 'Reply';

  @override
  String get menuQuote => 'Quote';

  @override
  String get menuReport => 'Report';

  @override
  String get moreReactions => 'More reactions';

  @override
  String get reportDetailsTitle => 'Add details';

  @override
  String get reportDetailsOptional =>
      'You can add details, or send the report as it is.';

  @override
  String get reportDetailsHint => 'What is wrong with this message?';

  @override
  String get reportSent => 'Thank you, the report is on its way.';

  @override
  String seenBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Seen by $count',
      one: 'Seen by $count',
    );
    return '$_temp0';
  }

  @override
  String reactedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reactions',
      one: '$count reaction',
    );
    return '$_temp0';
  }

  @override
  String readAt(String time) {
    return 'Read $time';
  }

  @override
  String get notReadYet => 'Not read yet';

  @override
  String editedAt(String time) {
    return 'Edited $time';
  }

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuCopyText => 'Copy text';

  @override
  String get menuCopyLink => 'Copy link';

  @override
  String get menuForward => 'Forward';

  @override
  String get menuChooseChat => 'Choose chat…';

  @override
  String get menuSaveAs => 'Save as…';

  @override
  String get menuSaveToDownloads => 'Save to Downloads';

  @override
  String get menuShowInFinder => 'Show in Finder';

  @override
  String get menuShowInFolder => 'Show in folder';

  @override
  String get menuQuickLook => 'Quick Look';

  @override
  String get sendWithoutSound => 'Send without sound';

  @override
  String get scheduleMessage => 'Schedule message…';

  @override
  String get sendWhenOnline => 'Send when online';

  @override
  String get scheduledWhenOnline => 'Will be sent when they come online';

  @override
  String get scheduleTitle => 'Schedule message';

  @override
  String get scheduleHint => 'Pick the day and the time it goes out.';

  @override
  String get scheduleTimeHint => 'HH:MM';

  @override
  String get scheduleAction => 'Schedule';

  @override
  String get scheduledList => 'Scheduled messages';

  @override
  String scheduledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scheduled messages',
      one: '$count scheduled message',
    );
    return '$_temp0';
  }

  @override
  String get menuSendNow => 'Send now';

  @override
  String get menuReschedule => 'Reschedule…';

  @override
  String scheduledFor(String date) {
    return 'Scheduled for $date';
  }

  @override
  String get menuDelete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get formatBold => 'Bold';

  @override
  String get formatItalic => 'Italic';

  @override
  String get formatUnderline => 'Underline';

  @override
  String get formatStrikethrough => 'Strikethrough';

  @override
  String get formatMonospace => 'Monospace';

  @override
  String get formatSpoiler => 'Spoiler';

  @override
  String get formatQuote => 'Quote';

  @override
  String get formatLink => 'Link…';

  @override
  String get formatPlain => 'Plain text';

  @override
  String get linkTitle => 'Add link';

  @override
  String get linkHint => 'URL';

  @override
  String get linkApply => 'Apply';

  @override
  String get deleteMessageTitle => 'Delete message?';

  @override
  String deleteMessagesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count messages?',
      one: 'Delete $count message?',
    );
    return '$_temp0';
  }

  @override
  String get deleteForEveryone => 'Delete for everyone';

  @override
  String deleteAlsoFor(String name) {
    return 'Also delete for $name';
  }

  @override
  String get editingMessage => 'Editing';

  @override
  String get linkPreviewAboveText => 'Show the preview above the text';

  @override
  String get linkPreviewBelowText => 'Show the preview below the text';

  @override
  String get removeLinkPreview => 'Remove the link preview';

  @override
  String get forwardTitle => 'Forward to chat';

  @override
  String get forwardSearch => 'Search chats';

  @override
  String get forwardHideSender => 'Hide sender names';

  @override
  String get forwardHideCaptions => 'Hide captions';

  @override
  String get forwardComment => 'Add a comment…';

  @override
  String get noChatsFound => 'No chats found';

  @override
  String get statusOnline => 'online';

  @override
  String get statusJustNow => 'last seen just now';

  @override
  String statusMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'last seen $count minutes ago',
      one: 'last seen $count minute ago',
    );
    return '$_temp0';
  }

  @override
  String statusToday(String time) {
    return 'last seen today at $time';
  }

  @override
  String statusYesterday(String time) {
    return 'last seen yesterday at $time';
  }

  @override
  String statusOnDate(String date) {
    return 'last seen $date';
  }

  @override
  String get statusRecently => 'last seen recently';

  @override
  String get statusLastWeek => 'last seen within a week';

  @override
  String get statusLastMonth => 'last seen within a month';

  @override
  String get statusLongAgo => 'last seen a long time ago';

  @override
  String get statusBot => 'bot';

  @override
  String get statusService => 'service notifications';

  @override
  String get statusGroup => 'group';

  @override
  String get statusChannel => 'channel';

  @override
  String statusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String statusMembersOnline(String members, String online) {
    return '$members, $online online';
  }

  @override
  String statusSubscribers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscribers',
      one: '$count subscriber',
    );
    return '$_temp0';
  }

  @override
  String get activityTyping => 'typing';

  @override
  String get activityRecordingVoice => 'recording a voice message';

  @override
  String get activityRecordingVideoNote => 'recording a video message';

  @override
  String get activityRecordingVideo => 'recording a video';

  @override
  String get activitySendingPhoto => 'sending a photo';

  @override
  String get activitySendingVideo => 'sending a video';

  @override
  String get activitySendingVoice => 'sending a voice message';

  @override
  String get activitySendingVideoNote => 'sending a video message';

  @override
  String get activitySendingFile => 'sending a file';

  @override
  String get activityChoosingSticker => 'choosing a sticker';

  @override
  String get activityChoosingLocation => 'choosing a location';

  @override
  String get activityChoosingContact => 'choosing a contact';

  @override
  String get activityPlayingGame => 'playing a game';

  @override
  String get activityWatchingAnimations => 'watching an animation';

  @override
  String activityByOne(String name, String activity) {
    return '$name is $activity';
  }

  @override
  String activityByTwo(String first, String second) {
    return '$first and $second are typing';
  }

  @override
  String activityByMany(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name and $count others are typing',
      one: '$name and $count other are typing',
    );
    return '$_temp0';
  }

  @override
  String get archivedChats => 'Archived chats';

  @override
  String get noArchivedChats => 'No archived chats';

  @override
  String get menuPin => 'Pin';

  @override
  String get menuUnpin => 'Unpin';

  @override
  String get menuMute => 'Mute';

  @override
  String get menuUnmute => 'Unmute';

  @override
  String get muteFor1Hour => 'For 1 hour';

  @override
  String get muteFor8Hours => 'For 8 hours';

  @override
  String get muteFor3Days => 'For 3 days';

  @override
  String get muteForever => 'Forever';

  @override
  String get menuArchive => 'Archive';

  @override
  String get menuUnarchive => 'Unarchive';

  @override
  String get menuMarkRead => 'Mark as read';

  @override
  String get menuMarkUnread => 'Mark as unread';

  @override
  String get menuMarkAllRead => 'Mark all as read';

  @override
  String get menuHideArchive => 'Hide archive';

  @override
  String get menuShowArchive => 'Show archive';

  @override
  String get showArchiveRow => 'Archive in the chat list';

  @override
  String get showArchiveRowHint =>
      'Archived chats stay in the rail and in search while the row is hidden.';

  @override
  String get menuClearHistory => 'Clear history';

  @override
  String get menuDeleteChat => 'Delete chat';

  @override
  String get menuDeleteAndLeave => 'Delete and leave';

  @override
  String get menuLeaveGroup => 'Leave group';

  @override
  String get menuLeaveChannel => 'Leave channel';

  @override
  String get clearHistoryTitle => 'Clear history?';

  @override
  String clearHistoryMessage(String name) {
    return 'Messages in $name will be deleted for you.';
  }

  @override
  String clearAlsoFor(String name) {
    return 'Also clear for $name';
  }

  @override
  String get clear => 'Clear';

  @override
  String get deleteChatTitle => 'Delete chat?';

  @override
  String deleteChatMessage(String name) {
    return 'The chat with $name will be deleted for you.';
  }

  @override
  String leaveTitle(String name) {
    return 'Leave $name?';
  }

  @override
  String get leave => 'Leave';

  @override
  String deleteAndLeaveTitle(String name) {
    return 'Delete and leave $name?';
  }

  @override
  String get chatActionFailed => 'Couldn\'t do that, try again';

  @override
  String get editFailed => 'Couldn\'t save the changes';

  @override
  String attachTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count files',
      one: 'Send $count file',
    );
    return '$_temp0';
  }

  @override
  String attachPhotosTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count photos',
      one: 'Send $count photo',
    );
    return '$_temp0';
  }

  @override
  String get attachAddMore => 'Add more';

  @override
  String get groupAlbum => 'Group as an album';

  @override
  String get removeFromSend => 'Remove';

  @override
  String get cancelUpload => 'Cancel sending';

  @override
  String get retryUpload => 'Try again';

  @override
  String get discardUpload => 'Delete';

  @override
  String get sendAsFiles => 'Send as files';

  @override
  String get hideWithSpoiler => 'Hide with a spoiler';

  @override
  String get viewOnce => 'View once';

  @override
  String get captionHint => 'Add a caption';

  @override
  String get dropFiles => 'Drop files here to send them';

  @override
  String get attachFailed => 'Couldn\'t send the files';

  @override
  String get hiddenMedia => 'Hidden media, tap to show';

  @override
  String get spoilerMedia => 'Spoiler';

  @override
  String get secretMedia => 'Tap to view';

  @override
  String get sensitiveMedia => '18+';

  @override
  String get forwardFailed => 'Couldn\'t forward the message';

  @override
  String get close => 'Close';

  @override
  String get peerInfo => 'Info';

  @override
  String get lastSeenJustNow => 'last seen just now';

  @override
  String lastSeenMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'last seen $count minutes ago',
      one: 'last seen 1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String lastSeenToday(String time) {
    return 'last seen today at $time';
  }

  @override
  String lastSeenYesterday(String time) {
    return 'last seen yesterday at $time';
  }

  @override
  String lastSeenDate(String date) {
    return 'last seen $date';
  }

  @override
  String get lastSeenRecently => 'last seen recently';

  @override
  String get lastSeenWeek => 'last seen within a week';

  @override
  String get lastSeenMonth => 'last seen within a month';

  @override
  String get lastSeenLongAgo => 'last seen a long time ago';

  @override
  String get deletedAccount => 'Deleted account';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'no members',
    );
    return '$_temp0';
  }

  @override
  String subscribersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscribers',
      one: '1 subscriber',
      zero: 'no subscribers',
    );
    return '$_temp0';
  }

  @override
  String get infoBio => 'Bio';

  @override
  String get infoUsername => 'Username';

  @override
  String get infoPhone => 'Mobile';

  @override
  String get infoBirthday => 'Birthday';

  @override
  String get infoDescription => 'Description';

  @override
  String get infoLink => 'Link';

  @override
  String get copied => 'Copied';

  @override
  String get infoMessage => 'Message';

  @override
  String get infoMute => 'Mute';

  @override
  String get infoUnmute => 'Unmute';

  @override
  String muteForHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'For $count hours',
      one: 'For 1 hour',
    );
    return '$_temp0';
  }

  @override
  String muteForDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'For $count days',
      one: 'For 1 day',
    );
    return '$_temp0';
  }

  @override
  String get muteUntilEnabled => 'Until I turn it back on';

  @override
  String get autoDeleteTitle => 'Auto-delete messages';

  @override
  String get blockUser => 'Block user';

  @override
  String get infoShareContact => 'Share contact';

  @override
  String get unblockUser => 'Unblock user';

  @override
  String blockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockConfirmMessage =>
      'They won\'t be able to send you messages or call you.';

  @override
  String get block => 'Block';

  @override
  String get memberOwner => 'owner';

  @override
  String get memberAdmin => 'admin';

  @override
  String get infoFailed => 'Couldn\'t load the info';

  @override
  String fileSizeBytes(String size) {
    return '$size B';
  }

  @override
  String fileSizeKb(String size) {
    return '$size KB';
  }

  @override
  String fileSizeMb(String size) {
    return '$size MB';
  }

  @override
  String fileSizeGb(String size) {
    return '$size GB';
  }

  @override
  String fileProgress(String done, String total) {
    return '$done of $total';
  }

  @override
  String get contentLocation => 'Location';

  @override
  String get contentLiveLocation => 'Live location';

  @override
  String get liveLocationEnded => 'Live location ended';

  @override
  String liveMinutesLeft(int minutes) {
    return '$minutes min left';
  }

  @override
  String liveHoursLeft(int hours) {
    return '$hours h left';
  }

  @override
  String get contentContact => 'Contact';

  @override
  String get contentPoll => 'Poll';

  @override
  String get contentQuiz => 'Quiz';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: 'No votes',
    );
    return '$_temp0';
  }

  @override
  String get pollAnonymous => 'Anonymous poll';

  @override
  String get pollAnonymousQuiz => 'Anonymous quiz';

  @override
  String get pollFinalResults => 'Final results';

  @override
  String get pollVote => 'Vote';

  @override
  String get pollRetractVote => 'Retract vote';

  @override
  String quizAnswers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count answered',
      one: '1 answered',
      zero: 'Nobody answered yet',
    );
    return '$_temp0';
  }

  @override
  String get menuStopPoll => 'Stop poll';

  @override
  String get stopPollTitle => 'Stop this poll?';

  @override
  String get stopPollMessage => 'Nobody will be able to vote in it any more.';

  @override
  String get botMenu => 'Menu';

  @override
  String get webAppUnavailable => 'Couldn\'t open the bot\'s app';

  @override
  String get sendAs => 'Send as';

  @override
  String get sendAsPersonal => 'Personal account';

  @override
  String get sendAsChannel => 'Channel';

  @override
  String get sendAsPremium => 'Telegram Premium';

  @override
  String get botKeyboard => 'Bot keyboard';

  @override
  String get botNoAnswer => 'The bot did not answer';

  @override
  String get sharePhoneTitle => 'Share your phone number?';

  @override
  String sharePhoneMessage(String bot) {
    return '$bot will receive the phone number of your account.';
  }

  @override
  String get share => 'Share';

  @override
  String get attachFile => 'File…';

  @override
  String get attachPoll => 'Poll…';

  @override
  String get attachContact => 'Contact…';

  @override
  String get sendContactTitle => 'Send contact';

  @override
  String get attachLocation => 'Location…';

  @override
  String get sendLocationTitle => 'Send location';

  @override
  String get locationSearchHint => 'Place, address or coordinates';

  @override
  String get locationStartHint =>
      'Enter coordinates or paste a map link to pick a place, then search for venues around it';

  @override
  String get sendThisLocation => 'Send this location';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get newPollTitle => 'New poll';

  @override
  String get newQuizTitle => 'New quiz';

  @override
  String get pollQuestionHint => 'Ask a question';

  @override
  String get pollOptionsTitle => 'Options';

  @override
  String get pollOptionHint => 'Add an option';

  @override
  String get pollRemoveOption => 'Remove option';

  @override
  String get pollCorrectAnswer => 'Correct answer';

  @override
  String get pollAnonymousVoting => 'Anonymous voting';

  @override
  String get pollMultipleAnswers => 'Multiple answers';

  @override
  String get pollQuizMode => 'Quiz mode';

  @override
  String get pollExplanationHint => 'Explanation (optional)';

  @override
  String get pollQuizHint =>
      'Mark the correct answer; voters see the explanation after answering.';

  @override
  String get pollCreate => 'Create';

  @override
  String get startBot => 'Start';

  @override
  String get contentGame => 'Game';

  @override
  String get contentInvoice => 'Invoice';

  @override
  String get contentStory => 'Story';

  @override
  String get contentChecklist => 'Checklist';

  @override
  String checklistProgress(int done, int total) {
    return '$done of $total completed';
  }

  @override
  String get contentGiveaway => 'Giveaway';

  @override
  String get contentPaidMedia => 'Paid media';

  @override
  String get contentExpiredPhoto => 'The photo has expired';

  @override
  String get contentExpiredVideo => 'The video has expired';

  @override
  String get contentExpiredVideoNote => 'The video message has expired';

  @override
  String get contentExpiredVoiceNote => 'The voice message has expired';

  @override
  String get contentUnsupported =>
      'This message isn\'t supported in Mollygram yet';

  @override
  String get callOutgoing => 'Outgoing call';

  @override
  String get callIncoming => 'Incoming call';

  @override
  String get callVideoOutgoing => 'Outgoing video call';

  @override
  String get callVideoIncoming => 'Incoming video call';

  @override
  String get callMissed => 'Missed call';

  @override
  String get callDeclined => 'Declined call';

  @override
  String get callCancelled => 'Cancelled call';

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String durationSeconds(int count) {
    return '$count s';
  }

  @override
  String serviceGroupCreated(String name, String title) {
    return '$name created the group «$title»';
  }

  @override
  String get serviceChannelCreated => 'Channel created';

  @override
  String serviceTitleChanged(String name, String title) {
    return '$name changed the group name to «$title»';
  }

  @override
  String serviceChannelTitleChanged(String title) {
    return 'Channel name changed to «$title»';
  }

  @override
  String servicePhotoChanged(String name) {
    return '$name updated the group photo';
  }

  @override
  String get serviceChannelPhotoChanged => 'Channel photo updated';

  @override
  String servicePhotoRemoved(String name) {
    return '$name removed the group photo';
  }

  @override
  String get serviceChannelPhotoRemoved => 'Channel photo removed';

  @override
  String serviceJoined(String name) {
    return '$name joined the group';
  }

  @override
  String serviceAdded(String name, String members) {
    return '$name added $members';
  }

  @override
  String serviceJoinedByLink(String name) {
    return '$name joined the group via invite link';
  }

  @override
  String serviceJoinedByRequest(String name) {
    return '$name was accepted to the group';
  }

  @override
  String serviceLeft(String name) {
    return '$name left the group';
  }

  @override
  String serviceRemoved(String name, String member) {
    return '$name removed $member';
  }

  @override
  String servicePinned(String name, String text) {
    return '$name pinned «$text»';
  }

  @override
  String servicePinnedMessage(String name) {
    return '$name pinned a message';
  }

  @override
  String serviceScreenshot(String name) {
    return '$name took a screenshot';
  }

  @override
  String serviceAutoDeleteOn(String name, String time) {
    return '$name set messages to auto-delete after $time';
  }

  @override
  String serviceAutoDeleteOff(String name) {
    return '$name turned off auto-delete';
  }

  @override
  String get serviceUpgraded => 'The group was upgraded to a supergroup';

  @override
  String serviceVideoChatStarted(String name) {
    return '$name started a video chat';
  }

  @override
  String serviceVideoChatEnded(String duration) {
    return 'Video chat ended ($duration)';
  }

  @override
  String get serviceVideoChatScheduled => 'Video chat scheduled';

  @override
  String serviceVideoChatInvited(String name, String members) {
    return '$name invited $members to the video chat';
  }

  @override
  String serviceTopicCreated(String title) {
    return 'Topic «$title» created';
  }

  @override
  String serviceTopicEdited(String name) {
    return '$name changed the topic';
  }

  @override
  String serviceContactJoined(String name) {
    return '$name joined Telegram';
  }

  @override
  String serviceThemeChanged(String name) {
    return '$name changed the chat theme';
  }

  @override
  String serviceBackgroundChanged(String name) {
    return '$name changed the chat wallpaper';
  }

  @override
  String serviceGift(String name) {
    return '$name sent a gift';
  }

  @override
  String get servicePayment => 'Payment completed';

  @override
  String serviceBoost(String name) {
    return '$name boosted the group';
  }

  @override
  String serviceGameScore(String name, int score) {
    return '$name scored $score';
  }

  @override
  String serviceOther(String name) {
    return '$name performed an action that Mollygram can\'t show yet';
  }

  @override
  String get listSeparator => ', ';

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String durationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String durationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get plugins => 'Plugins';

  @override
  String get settings => 'Settings';

  @override
  String get settingsSearch => 'Search';

  @override
  String get myProfile => 'My profile';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get username => 'Username';

  @override
  String get bio => 'Bio';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get bioHint => 'Any details such as age, occupation or city.';

  @override
  String get usernameHint =>
      'People can find you by this username and contact you without knowing your phone number. You can use a–z, 0–9 and underscores, at least 5 characters.';

  @override
  String get usernameTooShort => 'A username must have at least 5 characters.';

  @override
  String get usernameTooLong =>
      'A username can\'t be longer than 32 characters.';

  @override
  String get usernameInvalidCharacter =>
      'Only a–z, 0–9 and underscores are allowed.';

  @override
  String get usernameStartsWithLetter => 'A username must start with a letter.';

  @override
  String get usernameEndsWithUnderscore =>
      'A username can\'t end with an underscore.';

  @override
  String get usernameChecking => 'Checking…';

  @override
  String usernameAvailable(String name) {
    return '@$name is available.';
  }

  @override
  String get usernameOccupied => 'This username is already taken.';

  @override
  String get usernamePurchasable => 'This username is for sale on Fragment.';

  @override
  String get usernameUnavailable => 'This username can\'t be used.';

  @override
  String get firstNameRequired => 'A first name is required.';

  @override
  String get saveFailed => 'Couldn\'t save the change.';

  @override
  String get profileFailed => 'Couldn\'t load your profile.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get logOut => 'Log out';

  @override
  String get logOutButton => 'Log out…';

  @override
  String get logOutTitle => 'Log out of Telegram?';

  @override
  String get logOutMessage =>
      'Your chats and media will be removed from this computer. They stay in the Telegram cloud.';

  @override
  String get privacyAndSecurity => 'Privacy and security';

  @override
  String get activeSessions => 'Active sessions';

  @override
  String get activeSessionsHint =>
      'Devices and apps signed in to your account.';

  @override
  String get thisDevice => 'This device';

  @override
  String get otherSessions => 'Other sessions';

  @override
  String get noOtherSessions => 'You\'re signed in on this device only.';

  @override
  String get sessionsFailed => 'Couldn\'t load the sessions.';

  @override
  String get sessionOnline => 'online';

  @override
  String get sessionUnconfirmed => 'New sign-in';

  @override
  String get terminate => 'Terminate';

  @override
  String get terminateSessionTitle => 'Terminate this session?';

  @override
  String get terminateOthers => 'Terminate all other sessions';

  @override
  String get terminateOthersHint => 'Logs out every device except this one.';

  @override
  String get terminateOthersTitle => 'Terminate all other sessions?';

  @override
  String get logOutFailed =>
      'Couldn\'t log out. Check the connection and try again.';

  @override
  String get connectedBot => 'Connected business bot';

  @override
  String get connectedBotFailed => 'Couldn\'t load the connected bot';

  @override
  String get connectedBotHint =>
      'This bot can read and answer your business chats.';

  @override
  String get disconnect => 'Disconnect';

  @override
  String disconnectBotTitle(String name) {
    return 'Disconnect $name?';
  }

  @override
  String get appearance => 'Appearance';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accentColor => 'Accent color';

  @override
  String get accentViolet => 'Violet';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentGraphite => 'Graphite';

  @override
  String get chatWallpaper => 'Chat wallpaper';

  @override
  String get chatWallpaperHint => 'When off, chats sit on a plain background.';

  @override
  String get messageTextSize => 'Message text size';

  @override
  String textSizeValue(String size) {
    return '$size pt';
  }

  @override
  String get previewSender => 'Anna';

  @override
  String get previewMessage => 'Good morning! The new settings look great.';

  @override
  String get reduceMotion => 'Reduce motion';

  @override
  String get reduceMotionHint =>
      'Turns animations off. Mollygram also follows the same setting in macOS Accessibility.';

  @override
  String get dataAndStorage => 'Data and storage';

  @override
  String get storageUsage => 'Storage';

  @override
  String get storageCalculating => 'Calculating…';

  @override
  String storageUsed(String size) {
    return '$size of media and files';
  }

  @override
  String get storageEmpty => 'No media or files are stored on this computer.';

  @override
  String get storagePhotos => 'Photos';

  @override
  String get storageVideos => 'Videos';

  @override
  String get storageFiles => 'Files';

  @override
  String get storageVoiceAndMusic => 'Voice and music';

  @override
  String get storageStickers => 'Stickers';

  @override
  String get storageOther => 'Other';

  @override
  String get storageDatabase => 'Message database';

  @override
  String get storageHint =>
      'Cleared media stays in the Telegram cloud and downloads again when needed. Messages are kept.';

  @override
  String get storageFailed => 'Couldn\'t read the storage usage.';

  @override
  String get clearCache => 'Clear cache…';

  @override
  String clearCacheTitle(String size) {
    return 'Clear $size from this computer?';
  }

  @override
  String get clearCacheMessage =>
      'Media stays in the Telegram cloud and downloads again when you open it.';

  @override
  String get clearCacheFailed => 'Couldn\'t clear the cache.';

  @override
  String get autoDownload => 'Automatic media download';

  @override
  String get autoDownloadWifi => 'On Wi-Fi and Ethernet';

  @override
  String get autoDownloadOther => 'On other networks';

  @override
  String get autoDownloadHint =>
      'Other networks are personal hotspots and other metered connections.';

  @override
  String get downloadFolder => 'Download folder';

  @override
  String get downloadFolderDefault => 'Downloads';

  @override
  String get chooseFolder => 'Choose…';

  @override
  String get downloadFolderHint => 'Files you save from chats go here.';

  @override
  String sizeBytes(String size) {
    return '$size B';
  }

  @override
  String sizeKilobytes(String size) {
    return '$size KB';
  }

  @override
  String sizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String sizeGigabytes(String size) {
    return '$size GB';
  }

  @override
  String get emojiTab => 'Emoji';

  @override
  String get stickersTab => 'Stickers';

  @override
  String get gifsTab => 'GIFs';

  @override
  String get customEmojiTab => 'Custom';

  @override
  String get emojiSearch => 'Search emoji';

  @override
  String get recentlyUsed => 'Recently used';

  @override
  String get noEmojiFound => 'No emoji found';

  @override
  String get stickerSearch => 'Search stickers';

  @override
  String get noStickersFound => 'No stickers found';

  @override
  String get stickerSearchResults => 'Found';

  @override
  String get emojiSmileys => 'Smileys';

  @override
  String get emojiPeople => 'People';

  @override
  String get emojiAnimals => 'Animals and nature';

  @override
  String get emojiFood => 'Food and drink';

  @override
  String get emojiTravel => 'Travel and places';

  @override
  String get emojiActivities => 'Activities';

  @override
  String get emojiObjects => 'Objects';

  @override
  String get emojiSymbols => 'Symbols';

  @override
  String get emojiFlags => 'Flags';

  @override
  String get favoriteStickers => 'Favorites';

  @override
  String get stickersFailed => 'Couldn\'t load stickers';

  @override
  String get noStickerSets => 'No sets yet';

  @override
  String get noGifs => 'No saved GIFs yet';

  @override
  String get gifsFailed => 'Couldn\'t load GIFs';

  @override
  String get inlineSearching => 'Searching…';

  @override
  String get inlineNoResults => 'No results';

  @override
  String get forwardedMessages => 'Forwarded messages';

  @override
  String get leaveComment => 'Leave a comment';

  @override
  String get comments => 'Comments';

  @override
  String get commentHint => 'Comment';

  @override
  String get commentsUnavailable => 'Couldn\'t open the comments';

  @override
  String commentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '$count comment',
    );
    return '$_temp0';
  }

  @override
  String get replies => 'Replies';

  @override
  String get replyHint => 'Reply';

  @override
  String replyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '$count reply',
    );
    return '$_temp0';
  }

  @override
  String get mediaSaved => 'Saved';

  @override
  String get mediaSaveFailed => 'Couldn\'t save the file';

  @override
  String get mediaCopied => 'Copied';

  @override
  String mediaCounter(int index, int count) {
    return '$index of $count';
  }

  @override
  String get mediaRotate => 'Rotate';

  @override
  String get mediaCopy => 'Copy';

  @override
  String get mediaSave => 'Save';

  @override
  String get mediaPrevious => 'Previous';

  @override
  String get mediaNext => 'Next';

  @override
  String get mediaPause => 'Pause';

  @override
  String get mediaPlay => 'Play';

  @override
  String get mediaSpeed => 'Playback speed';

  @override
  String get mediaLoop => 'Loop';

  @override
  String get mediaUnmute => 'Unmute';

  @override
  String get mediaMute => 'Mute';

  @override
  String get unreadMessages => 'Unread messages';

  @override
  String get scrollToBottom => 'Scroll to the newest message';

  @override
  String get nextMention => 'Next mention';

  @override
  String get nextReaction => 'Next reaction';

  @override
  String get linkJoinChannel => 'Join channel';

  @override
  String get linkJoinGroup => 'Join group';

  @override
  String get linkRequestToJoin => 'Request to join';

  @override
  String get linkViewChannel => 'View channel';

  @override
  String get linkViewGroup => 'View group';

  @override
  String linkSubscribers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString subscribers',
      one: '$countString subscriber',
      zero: 'No subscribers',
    );
    return '$_temp0';
  }

  @override
  String linkMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString members',
      one: '$countString member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String get linkApprovalHint => 'An admin has to approve your request.';

  @override
  String get linkRequestSent => 'Request sent';

  @override
  String get linkRequestSentHint => 'You\'ll join once an admin approves it.';

  @override
  String get linkJoinFailed => 'Couldn\'t join. Try again later.';

  @override
  String get linkMissing => 'This link is invalid or has expired.';

  @override
  String get linkUnsupported => 'Mollygram can\'t open this kind of link yet.';

  @override
  String get done => 'Done';

  @override
  String get linkForbidden => 'You can\'t view this chat.';

  @override
  String get linkCannotSend => 'Couldn\'t send the command.';

  @override
  String get pinnedMessage => 'Pinned message';

  @override
  String pinnedMessageNumber(int number) {
    return 'Pinned message #$number';
  }

  @override
  String get hidePinned => 'Hide pinned messages';

  @override
  String get backToPrevious => 'Back to where you were';

  @override
  String get searchInChat => 'Search in chat';

  @override
  String get searchByDate => 'Jump to date';

  @override
  String get searchBySender => 'Search by sender';

  @override
  String get searchFilter => 'Filter results';

  @override
  String get searchAllKinds => 'All messages';

  @override
  String searchCounter(int index, int count) {
    return '$index of $count';
  }

  @override
  String get searchNoResults => 'No results';

  @override
  String get searchOlder => 'Previous result';

  @override
  String get searchNewer => 'Next result';

  @override
  String get hashtagThisChat => 'This chat';

  @override
  String get hashtagMyMessages => 'My messages';

  @override
  String get hashtagPublicPosts => 'Public posts';

  @override
  String hashtagEmpty(String tag) {
    return 'No messages with $tag';
  }

  @override
  String get hashtagFailed => 'Could not search';

  @override
  String get sharedMedia => 'Shared media';

  @override
  String get sharedMediaTab => 'Media';

  @override
  String get sharedFilesTab => 'Files';

  @override
  String get sharedLinksTab => 'Links';

  @override
  String get sharedVoiceTab => 'Voice';

  @override
  String get sharedMusicTab => 'Music';

  @override
  String get sharedGifsTab => 'GIFs';

  @override
  String get sharedGroupsTab => 'Groups';

  @override
  String get sharedMediaEmpty => 'No photos or videos yet';

  @override
  String get sharedFilesEmpty => 'No files yet';

  @override
  String get sharedLinksEmpty => 'No links yet';

  @override
  String get sharedVoiceEmpty => 'No voice messages yet';

  @override
  String get sharedMusicEmpty => 'No music yet';

  @override
  String get sharedGifsEmpty => 'No GIFs yet';

  @override
  String get sharedGroupsEmpty => 'No groups in common';

  @override
  String get sharedLoadFailed => 'Couldn\'t load the list';

  @override
  String get showInChat => 'Show in chat';

  @override
  String get playlist => 'Playlist';

  @override
  String get joinChannel => 'Join channel';

  @override
  String get joinGroup => 'Join group';

  @override
  String get muteChat => 'Mute';

  @override
  String get unmuteChat => 'Unmute';

  @override
  String get chatUnavailable => 'You can\'t take part in this chat';

  @override
  String get textNotAllowed => 'Text messages aren\'t allowed in this group';

  @override
  String restrictedUntil(String date) {
    return 'You can\'t write here until $date';
  }

  @override
  String slowModeWait(String time) {
    return 'Slowmode is on, next message in $time';
  }

  @override
  String get privacyExtras => 'Privacy extras';

  @override
  String get privacyExtrasAbout =>
      'These switches decide what others see while you use Mollygram on this Mac. Everything you read and send works as usual.';

  @override
  String get privacyExtrasOnlineNote =>
      'Some things still show: sending a message puts you online for a moment and marks the chat read, files you send show as uploading, and a reaction shows you saw the message.';

  @override
  String get ghostMode => 'Ghost mode';

  @override
  String get ghostModeHint => 'Turns on everything below at once';

  @override
  String get ghostModeIsOn => 'Ghost mode is on';

  @override
  String get privacyExtrasAreOn => 'Some privacy extras are on';

  @override
  String get hideReadReceipts => 'Don\'t send read receipts';

  @override
  String get hideReadReceiptsHint =>
      'Senders won\'t see that you\'ve read their messages';

  @override
  String get hideTyping => 'Don\'t show typing';

  @override
  String get hideTypingHint => 'Also hides recording voice and video messages';

  @override
  String get stayOffline => 'Stay offline';

  @override
  String get stayOfflineHint =>
      'You won\'t appear online while the app is open';

  @override
  String get hideContentOpened =>
      'Don\'t mark voice and video messages as played';

  @override
  String get hideContentOpenedHint =>
      'Senders won\'t see that you\'ve played them';

  @override
  String get menuSelect => 'Select';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '$count selected',
    );
    return '$_temp0';
  }

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get copy => 'Copy';

  @override
  String get chatFolders => 'Chat folders';

  @override
  String get chatFoldersHint =>
      'Sort chats into folders and switch between them in the sidebar.';

  @override
  String get createFolder => 'Create folder';

  @override
  String get newFolder => 'New folder';

  @override
  String get editFolder => 'Edit folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get folderIcon => 'Folder icon';

  @override
  String get folderIncluded => 'Included chats';

  @override
  String get folderExcluded => 'Excluded chats';

  @override
  String get folderAddChats => 'Add chats';

  @override
  String get folderExcludeChats => 'Exclude chats';

  @override
  String get folderIncludedHint =>
      'Choose chats or kinds of chats that will appear in this folder.';

  @override
  String get folderExcludedHint =>
      'Choose chats or kinds of chats that will never appear in this folder.';

  @override
  String get folderContacts => 'Contacts';

  @override
  String get folderNonContacts => 'Non-contacts';

  @override
  String get folderGroups => 'Groups';

  @override
  String get folderChannels => 'Channels';

  @override
  String get folderBots => 'Bots';

  @override
  String get folderMuted => 'Muted';

  @override
  String get folderRead => 'Read';

  @override
  String get folderArchived => 'Archived';

  @override
  String get folderChatTypes => 'Chat types';

  @override
  String get folderChats => 'Chats';

  @override
  String get folderBot => 'bot';

  @override
  String get folderGroup => 'group';

  @override
  String get folderChannel => 'channel';

  @override
  String get folderSavedMessages => 'Saved Messages';

  @override
  String get folderRemove => 'Remove';

  @override
  String get folderAdd => 'Add';

  @override
  String get folderReorder => 'Drag to reorder';

  @override
  String get folderReorderHint =>
      'Drag the handles to change the order of folders in the sidebar.';

  @override
  String get recommendedFolders => 'Recommended folders';

  @override
  String get deleteFolder => 'Delete folder';

  @override
  String get deleteFolderMessage => 'The chats in it won\'t be deleted.';

  @override
  String get deleteFolderLeave =>
      'The chats in it won\'t be deleted. You can also leave the chats this folder was shared with you through:';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String deleteFolderTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String folderLimit(int count) {
    return 'You can have up to $count folders.';
  }

  @override
  String folderChatsLimit(int count) {
    return 'A folder can have up to $count chats.';
  }

  @override
  String folderChatsCounter(int count, int max) {
    return '$count of $max';
  }

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get pinnedList => 'Pinned messages';

  @override
  String pinnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pinned messages',
      one: '$count pinned message',
    );
    return '$_temp0';
  }

  @override
  String get backToChat => 'Back to the chat';

  @override
  String get backToTopics => 'Back to topics';

  @override
  String get savedShowAsChats => 'Show as chats';

  @override
  String get savedShowAsMessages => 'Show as messages';

  @override
  String get savedMyNotes => 'My notes';

  @override
  String get savedHiddenAuthor => 'Hidden author';

  @override
  String get savedTagName => 'Name the tag';

  @override
  String get savedTagClearName => 'Remove the name';

  @override
  String get savedTagFailed => 'Couldn\'t load these messages';

  @override
  String get savedAllMessages => 'All saved messages';

  @override
  String deleteSavedTopicConfirm(String name) {
    return 'Delete everything saved from $name?';
  }

  @override
  String get noTopics => 'No topics yet';

  @override
  String get topicClosed => 'Topic closed';

  @override
  String get topicUnavailable => 'Couldn\'t open this topic';

  @override
  String get newTopic => 'New topic';

  @override
  String get topicName => 'Topic name';

  @override
  String get topicNameRequired => 'Give the topic a name';

  @override
  String get editTopic => 'Edit topic';

  @override
  String get closeTopic => 'Close topic';

  @override
  String get reopenTopic => 'Reopen topic';

  @override
  String get pinTopic => 'Pin';

  @override
  String get unpinTopic => 'Unpin';

  @override
  String get deleteTopic => 'Delete topic';

  @override
  String deleteTopicConfirm(String name) {
    return 'Delete «$name» with all its messages?';
  }

  @override
  String get topicActionFailed => 'Couldn\'t change the topic';

  @override
  String get sponsored => 'Sponsored';

  @override
  String get recommended => 'Recommended';

  @override
  String get sponsoredOpen => 'Open';

  @override
  String get sponsoredAbout =>
      'Telegram shows this message on behalf of the sponsor. It is picked by the channel\'s topic, not by your data.';

  @override
  String get unpinAll => 'Unpin all messages';

  @override
  String unpinAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Unpin all $count messages?',
      one: 'Unpin $count message?',
    );
    return '$_temp0';
  }

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyLoadFailed => 'Couldn\'t load the privacy settings.';

  @override
  String get privacyPhoneNumber => 'Phone number';

  @override
  String get privacyFindByPhone => 'Finding by phone number';

  @override
  String get privacyLastSeen => 'Last seen and online';

  @override
  String get privacyProfilePhotos => 'Profile photos';

  @override
  String get privacyForwards => 'Forwarded messages';

  @override
  String get privacyCalls => 'Calls';

  @override
  String get privacyVoiceMessages => 'Voice messages';

  @override
  String get privacyInvites => 'Groups and channels';

  @override
  String get privacyBio => 'Bio';

  @override
  String get privacyBirthday => 'Date of birth';

  @override
  String get privacyPhoneNumberQuestion => 'Who can see my phone number?';

  @override
  String get privacyFindByPhoneQuestion => 'Who can find me by my number?';

  @override
  String get privacyLastSeenQuestion => 'Who can see my last seen time?';

  @override
  String get privacyProfilePhotosQuestion => 'Who can see my profile photos?';

  @override
  String get privacyForwardsQuestion =>
      'Who can link to my account when forwarding my messages?';

  @override
  String get privacyCallsQuestion => 'Who can call me?';

  @override
  String get privacyVoiceMessagesQuestion =>
      'Who can send me voice and video messages?';

  @override
  String get privacyInvitesQuestion => 'Who can add me to groups and channels?';

  @override
  String get privacyBioQuestion => 'Who can see my bio?';

  @override
  String get privacyBirthdayQuestion => 'Who can see my date of birth?';

  @override
  String get privacyPhoneNumberAbout =>
      'People who have your number saved in their contacts will also see it on Telegram.';

  @override
  String get privacyFindByPhoneAbout =>
      'People who add your number to their contacts will see it as your Telegram account only if they\'re in this audience.';

  @override
  String get privacyLastSeenAbout =>
      'You won\'t see the last seen time of people you don\'t show yours to. An approximate time, such as recently or within a week, shows instead.';

  @override
  String get privacyForwardsAbout =>
      'Messages you send won\'t link back to your account when forwarded by people outside this audience.';

  @override
  String get privacyVoiceMessagesAbout =>
      'Only Telegram Premium subscribers can limit who sends them voice and video messages.';

  @override
  String get privacyEverybody => 'Everybody';

  @override
  String get privacyMyContacts => 'My contacts';

  @override
  String get privacyNobody => 'Nobody';

  @override
  String get privacyExceptions => 'Exceptions';

  @override
  String get privacyExceptionsAbout =>
      'Exceptions come before the choice above.';

  @override
  String get privacyAlwaysAllow => 'Always allow';

  @override
  String get privacyNeverAllow => 'Never allow';

  @override
  String get privacyAlwaysAbout =>
      'These people are allowed, whatever the choice above.';

  @override
  String get privacyNeverAbout =>
      'These people are never allowed, whatever the choice above.';

  @override
  String get privacyAddPeople => 'Add people';

  @override
  String get privacyGroupMembers => 'Group members';

  @override
  String privacyPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return '$_temp0';
  }

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get blockedUsersAbout =>
      'Blocked people can\'t message you, call you or add you to groups, and don\'t see your profile photos, online status or last seen time.';

  @override
  String get blockedUsersEmpty => 'No one is blocked.';

  @override
  String get blockSomeone => 'Block someone';

  @override
  String get privacyNotLoaded => 'Not loaded';

  @override
  String get unblock => 'Unblock';

  @override
  String get blockedShowMore => 'Show more';

  @override
  String get keepDeletedMessages => 'Keep deleted messages';

  @override
  String get keepDeletedMessagesHint =>
      'Save messages others delete for everyone';

  @override
  String get keepEditHistory => 'Keep edit history';

  @override
  String get keepEditHistoryHint => 'Save earlier versions of edited messages';

  @override
  String get storedMessagesAbout =>
      'Saved encrypted on this computer only, for messages Mollygram saw while it was open. Nothing is sent anywhere. Showing them in chats comes later.';

  @override
  String get clearStoredData => 'Stored data';

  @override
  String get clearStoredDataTitle =>
      'Clear the deleted messages and edit history saved on this computer?';

  @override
  String get storedDataUnreadable => 'Stored data can\'t be read';

  @override
  String get storedDataUnreadableHint =>
      'Its key is missing from the keychain. Reset to start again.';

  @override
  String get resetStoredData => 'Reset';

  @override
  String get resetStoredDataTitle =>
      'Delete the stored data that can\'t be read and start again?';

  @override
  String get edit => 'Edit';

  @override
  String get create => 'Create';

  @override
  String get remove => 'Remove';

  @override
  String get newGroup => 'New group';

  @override
  String get newChannel => 'New channel';

  @override
  String get groupName => 'Group name';

  @override
  String get channelName => 'Channel name';

  @override
  String get descriptionHint => 'Description (optional)';

  @override
  String get descriptionNote => 'Shown on the info panel under the name.';

  @override
  String get chatTitleRequired => 'Enter a name';

  @override
  String get addMembersHint => 'Add members';

  @override
  String get createFailed => 'Couldn\'t create it. Try again.';

  @override
  String get editGroup => 'Edit group';

  @override
  String get editChannel => 'Edit channel';

  @override
  String get setPhoto => 'Set photo';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get inviteLinks => 'Invite links';

  @override
  String get primaryLink => 'Primary link';

  @override
  String get createPrimaryLink => 'Generate a link';

  @override
  String get additionalLinks => 'Additional links';

  @override
  String get copyLink => 'Copy link';

  @override
  String get revokeLink => 'Revoke';

  @override
  String get revokeLinkTitle => 'Revoke this link?';

  @override
  String get revokeLinkMessage =>
      'Nobody will be able to join with it any more.';

  @override
  String get revokePrimaryMessage =>
      'Nobody will be able to join with it any more. A new primary link replaces it.';

  @override
  String get createLink => 'Create a new link';

  @override
  String get newLink => 'New link';

  @override
  String get linkNameHint => 'Link name (only admins see it)';

  @override
  String get linkDuration => 'Works for';

  @override
  String get linkMemberLimit => 'Number of uses';

  @override
  String get linkRequestApproval => 'Approve new members';

  @override
  String get noLimit => 'No limit';

  @override
  String get oneDay => '1 day';

  @override
  String get oneWeek => '1 week';

  @override
  String get oneMonth => '1 month';

  @override
  String linkJoined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count joined',
      one: '1 joined',
      zero: 'nobody joined',
    );
    return '$_temp0';
  }

  @override
  String linkJoinedOf(int count, int limit) {
    return '$count of $limit joined';
  }

  @override
  String get linkApproval => 'with approval';

  @override
  String get linkExpired => 'expired';

  @override
  String linkExpires(String date) {
    return 'expires $date';
  }

  @override
  String get searchMembers => 'Search members';

  @override
  String get showMoreMembers => 'Show more';

  @override
  String get promoteToAdmin => 'Make admin';

  @override
  String get editAdminRights => 'Edit admin rights';

  @override
  String get dismissAdmin => 'Dismiss admin';

  @override
  String get restrictMember => 'Restrict';

  @override
  String get removeFromGroup => 'Remove from group';

  @override
  String get removeFromChannel => 'Remove from channel';

  @override
  String removeMemberTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get addAdmin => 'New admin';

  @override
  String get adminRights => 'Admin rights';

  @override
  String adminRightsOf(String name) {
    return 'What $name can do';
  }

  @override
  String restrictWhatCan(String name) {
    return 'What $name can still do';
  }

  @override
  String get rightChangeInfo => 'Change group info';

  @override
  String get rightChangeChannelInfo => 'Change channel info';

  @override
  String get rightPostMessages => 'Post messages';

  @override
  String get rightEditMessages => 'Edit others\' messages';

  @override
  String get rightDeleteMessages => 'Delete messages';

  @override
  String get rightBanUsers => 'Ban users';

  @override
  String get rightInviteUsers => 'Add members';

  @override
  String get rightAddSubscribers => 'Add subscribers';

  @override
  String get rightPinMessages => 'Pin messages';

  @override
  String get rightManageVideoChats => 'Manage video chats';

  @override
  String get rightAddAdmins => 'Add new admins';

  @override
  String get rightAnonymous => 'Remain anonymous';

  @override
  String get permSendMessages => 'Send messages';

  @override
  String get permSendMedia => 'Send media';

  @override
  String get permSendStickers => 'Send stickers and GIFs';

  @override
  String get permSendPolls => 'Send polls';

  @override
  String get permEmbedLinks => 'Embed links';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String get leaveChannel => 'Leave channel';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get deleteChannel => 'Delete channel';

  @override
  String get leaveGroupTitle => 'Leave this group?';

  @override
  String get leaveChannelTitle => 'Leave this channel?';

  @override
  String get deleteGroupTitle => 'Delete this group?';

  @override
  String get deleteChannelTitle => 'Delete this channel?';

  @override
  String get membersFailed => 'Couldn\'t load the members.';

  @override
  String get memberChangeFailed =>
      'Couldn\'t make the change. You may not have the right to.';

  @override
  String get removeRestrictions => 'Remove restrictions';

  @override
  String get rightManageTopics => 'Manage topics';

  @override
  String notAddedMembers(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The group is created, but $names couldn\'t be added because of their privacy settings.',
      one:
          'The group is created, but $names couldn\'t be added because of their privacy settings.',
    );
    return '$_temp0';
  }

  @override
  String get leaveOwnerNote =>
      'You stay the owner and can come back with an invite link.';

  @override
  String get deleteGroupMessage =>
      'Every member loses the group and all its messages. This can\'t be undone.';

  @override
  String get deleteChannelMessage =>
      'Every subscriber loses the channel and all its posts. This can\'t be undone.';

  @override
  String get leaveFailed => 'Couldn\'t leave. Try again.';

  @override
  String get deleteFailed => 'Couldn\'t delete it. Try again.';

  @override
  String get folderDeletedChat => 'Deleted chat';

  @override
  String get passcodeLock => 'Passcode lock';

  @override
  String get passcodeAbout =>
      'A passcode locks Mollygram on this Mac. It isn\'t sent to Telegram and works only here.';

  @override
  String get passcodeTurnOn => 'Turn passcode on';

  @override
  String get passcodeTurnOff => 'Turn passcode off';

  @override
  String get passcodeTurnOffAction => 'Turn off';

  @override
  String get passcodeChange => 'Change passcode';

  @override
  String get passcodeCurrent => 'Current passcode';

  @override
  String get passcodeNew => 'New passcode';

  @override
  String get passcodeRepeat => 'Repeat the passcode';

  @override
  String get passcodeTooShort => 'Use at least 4 characters.';

  @override
  String get passcodesDontMatch => 'The passcodes don\'t match.';

  @override
  String get passcodeWrong => 'Wrong passcode';

  @override
  String get passcodeAutoLock => 'Auto-lock';

  @override
  String get passcodeAwayHour => 'If away for 1 hour';

  @override
  String passcodeAwayFor(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'If away for $minutes minutes',
      one: 'If away for $minutes minute',
    );
    return '$_temp0';
  }

  @override
  String get passcodeLockNowHint => 'Press ⌘L to lock right away.';

  @override
  String get passcodeLocked => 'Mollygram is locked';

  @override
  String get passcodeEnter => 'Enter your passcode to continue.';

  @override
  String get passcodeHint => 'Passcode';

  @override
  String get passcodeForgot => 'Forgot passcode?';

  @override
  String get passcodeLogOutTitle => 'Log out to remove the passcode?';

  @override
  String get passcodeLogOutMessage =>
      'The passcode can\'t be recovered. Logging out removes it; your chats come back when you sign in again.';

  @override
  String get twoStep => 'Two-step verification';

  @override
  String get twoStepOn => 'On';

  @override
  String get twoStepOff => 'Off';

  @override
  String get twoStepOffAbout =>
      'Set a password that Telegram asks for, after the code, when you sign in on a new device.';

  @override
  String get twoStepOnAbout =>
      'Telegram asks for this password, after the code, when you sign in on a new device.';

  @override
  String get twoStepLoadFailed => 'Couldn\'t load two-step verification.';

  @override
  String get twoStepSetPassword => 'Set password';

  @override
  String get twoStepSetPasswordAbout =>
      'A recovery email lets you reset the password if you forget it.';

  @override
  String get twoStepChangePassword => 'Change password';

  @override
  String get twoStepCurrentPassword => 'Current password';

  @override
  String get twoStepNewPassword => 'New password';

  @override
  String get twoStepRepeatPassword => 'Repeat the password';

  @override
  String get twoStepHint => 'Hint (optional)';

  @override
  String twoStepHintIs(String hint) {
    return 'Hint: $hint';
  }

  @override
  String get twoStepHintIsPassword => 'The hint can\'t be the password itself.';

  @override
  String get twoStepRecoveryEmail => 'Recovery email';

  @override
  String get twoStepRecoveryEmailAbout =>
      'Telegram sends a code to this address to reset the password if you forget it.';

  @override
  String get twoStepSetEmail => 'Set recovery email';

  @override
  String get twoStepChangeEmail => 'Change recovery email';

  @override
  String get twoStepEmailInvalid => 'This email address isn\'t valid.';

  @override
  String get twoStepPasswordRejected =>
      'Telegram didn\'t accept this password. Try another.';

  @override
  String get twoStepConfirmEmail => 'Confirm the recovery email';

  @override
  String twoStepCodeSent(String email) {
    return 'Telegram sent a code to $email.';
  }

  @override
  String get twoStepEnterCode => 'Enter the code';

  @override
  String get twoStepCode => 'Code';

  @override
  String get twoStepCheckCode => 'Confirm';

  @override
  String get twoStepResendCode => 'Send the code again';

  @override
  String get twoStepCancelEmail => 'Don\'t use this email';

  @override
  String get twoStepEmailConfirmed => 'The recovery email is confirmed.';

  @override
  String get twoStepPasswordSet => 'Two-step verification is on.';

  @override
  String get twoStepPasswordChanged => 'The password is changed.';

  @override
  String get twoStepTurnOff => 'Turn off two-step verification';

  @override
  String get twoStepTurnOffAbout =>
      'Signing in on a new device will then need only the code.';

  @override
  String get twoStepTurnOffAction => 'Turn off';

  @override
  String get twoStepTurnedOff => 'Two-step verification is off.';

  @override
  String get passwordsDontMatch => 'The passwords don\'t match.';

  @override
  String get accountTtlTitle => 'Delete my account';

  @override
  String get accountTtlRow => 'If away for';

  @override
  String get accountTtlQuestion => 'Delete my account if I\'m away for';

  @override
  String get accountTtlAbout =>
      'If you don\'t come online at least once in this period, your account is deleted with all its messages and contacts.';

  @override
  String ttlMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '$count month',
    );
    return '$_temp0';
  }

  @override
  String ttlDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String get accounts => 'Accounts';

  @override
  String accountsAbout(int count) {
    return 'Up to $count accounts, each with its own chats and tabs.';
  }

  @override
  String get addAccount => 'Add account';

  @override
  String accountNumber(int number) {
    return 'Account $number';
  }

  @override
  String switchToAccount(String name) {
    return 'Switch to $name';
  }

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String logOutAccountTitle(String name) {
    return 'Log out of $name?';
  }

  @override
  String backToAccount(String name) {
    return 'Back to $name';
  }

  @override
  String get loggingOut => 'Logging out…';

  @override
  String accountsFull(int count) {
    return 'That\'s the limit of $count accounts. Log out of one to add another.';
  }

  @override
  String get accountsLegacy =>
      'The data folder from an earlier version couldn\'t be moved, so only this account can be used. Restart Mollygram to try again.';

  @override
  String duplicateAccountTitle(String name) {
    return '$name is already signed in here';
  }

  @override
  String get duplicateAccountMessage =>
      'Switch to it and log out of this copy?';

  @override
  String get switchAccount => 'Switch';

  @override
  String get proxy => 'Proxy';

  @override
  String get useProxy => 'Use proxy';

  @override
  String get proxyHint =>
      'Telegram connects through the selected proxy. Ping shows the round trip in milliseconds.';

  @override
  String get savedProxies => 'Saved proxies';

  @override
  String get addProxy => 'Add proxy';

  @override
  String get editProxy => 'Edit proxy';

  @override
  String get proxyServer => 'Server';

  @override
  String get proxyPort => 'Port';

  @override
  String get proxyUsername => 'Username';

  @override
  String get proxyPassword => 'Password';

  @override
  String get proxySecret => 'Secret';

  @override
  String get proxyCheck => 'Check';

  @override
  String get proxyChecking => 'Checking…';

  @override
  String proxyPing(int ms) {
    return '$ms ms';
  }

  @override
  String get proxyUnavailable => 'Unavailable';

  @override
  String get proxyRemove => 'Remove proxy';

  @override
  String proxyRemoveTitle(String address) {
    return 'Remove $address?';
  }

  @override
  String get proxyConnect => 'Connect';

  @override
  String get proxyFromLink => 'Add this proxy and connect through it?';

  @override
  String get proxyNone => 'No proxies yet';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageHint =>
      'Changes the language of the app. Chats and messages stay as they are.';

  @override
  String get proxyEditButton => 'Edit';

  @override
  String get proxyInvalidSecret => 'Invalid secret';

  @override
  String get proxyRemoveAction => 'Remove';

  @override
  String get proxyLoadFailed => 'Couldn\'t load the proxies.';

  @override
  String get proxyShowSecret => 'Show secret';

  @override
  String get proxyHideSecret => 'Hide secret';

  @override
  String get pluginShowMessage => 'Show';

  @override
  String get pluginFilteredMessage => 'Filtered by a plugin';

  @override
  String passcodeWaitSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Too many tries. Try again in $count seconds.',
      one: 'Too many tries. Try again in $count second.',
    );
    return '$_temp0';
  }

  @override
  String passcodeWaitMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Too many tries. Try again in $count minutes.',
      one: 'Too many tries. Try again in $count minute.',
    );
    return '$_temp0';
  }

  @override
  String get passcodeForgotNoSession =>
      'Telegram couldn\'t start, so there is nothing to log out of yet. Try again when it is connected.';

  @override
  String get passcodeLogOutFailed =>
      'Couldn\'t log out. The passcode stays until you can.';

  @override
  String get passcodeUnreadable =>
      'The passcode couldn\'t be read from the keychain. The window stays locked until it can be.';

  @override
  String get passcodeReadAgain => 'Read again';

  @override
  String get twoStepPendingAbout =>
      'Two-step verification turns on once you enter the code sent to the recovery email.';

  @override
  String get twoStepConfirmToFinish =>
      'Enter the code from the email to turn on two-step verification.';

  @override
  String get twoStepPasswordTooFresh =>
      'The password was changed recently. Try again later.';

  @override
  String get twoStepSessionTooFresh =>
      'This device signed in recently. Try again later.';

  @override
  String get twoStepForgotPassword => 'Forgot password?';

  @override
  String get twoStepRecoverTitle => 'Reset the password';

  @override
  String twoStepRecoverAbout(String pattern) {
    return 'Enter the code sent to $pattern and a new password.';
  }

  @override
  String get twoStepResetTitle => 'Reset the password?';

  @override
  String get twoStepResetMessage =>
      'Without a recovery email, Telegram removes the password after a 7-day wait. Signing in with the password cancels the reset.';

  @override
  String get twoStepResetAction => 'Reset';

  @override
  String twoStepResetPending(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'The password will be removed on $dateString.';
  }

  @override
  String twoStepResetDeclined(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Telegram can\'t reset the password now. Try again after $dateString.';
  }

  @override
  String get twoStepCancelReset => 'Cancel reset';

  @override
  String ttlYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '$count year',
    );
    return '$_temp0';
  }

  @override
  String get accountTtlFooter =>
      'Your account is deleted if you don\'t come online in this period.';

  @override
  String get secretChat => 'Secret chat';

  @override
  String get newSecretChat => 'New secret chat';

  @override
  String get startSecretChat => 'Start secret chat';

  @override
  String get secretChatFailed => 'Couldn\'t start a secret chat. Try again.';

  @override
  String secretChatWaiting(String name) {
    return 'Waiting for $name to come online';
  }

  @override
  String get secretChatExchangingKeys => 'Exchanging encryption keys';

  @override
  String get secretChatClosed => 'Secret chat closed';

  @override
  String get closeSecretChat => 'Close secret chat';

  @override
  String get deleteChat => 'Delete chat';

  @override
  String get deleteSecretChatTitle =>
      'Delete this secret chat? It closes for both of you and its messages are removed here.';

  @override
  String get encryptionKey => 'Encryption key';

  @override
  String encryptionKeyHint(String name) {
    return 'If this picture and these numbers look the same on $name\'s device, your chat is end-to-end encrypted.';
  }

  @override
  String get encryptionKeyPending =>
      'The key appears once the other person\'s app accepts the chat.';

  @override
  String get selfDestructTitle => 'Self-destruct timer';

  @override
  String get selfDestructOff => 'Off';

  @override
  String selfDestructSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String selfDestructMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String selfDestructHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String selfDestructDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String selfDestructWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get allowSecretScreenshots => 'Allow screenshots in secret chats';

  @override
  String get allowSecretScreenshotsHint =>
      'Risky: the other person expects secret chats to stay off screenshots and screen recordings';

  @override
  String get secretScreenshotsOff =>
      'Secret chats are kept out of screenshots by default; on macOS 15 and later this is best effort';

  @override
  String get selfDestructFailed =>
      'Couldn\'t change the self-destruct timer. The secret chat isn\'t ready yet, or the connection was lost.';

  @override
  String get stickersAndEmoji => 'Stickers and emoji';

  @override
  String get largeEmoji => 'Large emoji';

  @override
  String get largeEmojiHint => 'A message of up to three emoji is shown large.';

  @override
  String get loopStickers => 'Loop animated stickers';

  @override
  String get animatedEmoji => 'Animated emoji';

  @override
  String get myStickers => 'My stickers';

  @override
  String get myEmoji => 'My emoji';

  @override
  String get customEmoji => 'Custom emoji';

  @override
  String get trendingStickers => 'Trending stickers';

  @override
  String get trendingEmoji => 'Trending emoji';

  @override
  String get archivedStickers => 'Archived stickers';

  @override
  String get archivedEmoji => 'Archived emoji';

  @override
  String get stickerSetsHint =>
      'Drag to reorder. Right-click a set to archive or remove it.';

  @override
  String get archiveSet => 'Archive';

  @override
  String get restoreSet => 'Restore';

  @override
  String get addSet => 'Add';

  @override
  String get addByLink => 'Add by link';

  @override
  String get openSetLink => 'Open';

  @override
  String get stickerSetNotFound => 'There is no set at this link.';

  @override
  String get noArchivedSets => 'Nothing archived';

  @override
  String get stickerSetLoadFailed => 'Couldn\'t load the sets.';

  @override
  String stickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stickers',
      one: '$count sticker',
    );
    return '$_temp0';
  }

  @override
  String emojiCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count emoji',
      one: '$count emoji',
    );
    return '$_temp0';
  }

  @override
  String get removeStickerSetTitle => 'Remove this sticker set?';

  @override
  String get removeEmojiSetTitle => 'Remove this emoji set?';

  @override
  String get stickerSetLookupFailed =>
      'Couldn\'t open the set. Check your connection and try again.';

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get shortcutsSearch => 'Search shortcuts';

  @override
  String get shortcutsHint =>
      'Click a shortcut, then press the new keys. Esc cancels, Delete removes the shortcut.';

  @override
  String get shortcutsGroupApp => 'App';

  @override
  String get shortcutsGroupChat => 'Chat';

  @override
  String get shortcutsGroupNavigation => 'Navigation';

  @override
  String get shortcutsGroupAccounts => 'Accounts';

  @override
  String get shortcutsGroupPlugins => 'Plugins';

  @override
  String get shortcutNone => 'None';

  @override
  String get shortcutRecording => 'Type a shortcut';

  @override
  String get shortcutChange => 'Change shortcut';

  @override
  String get shortcutNeedsModifier => 'Add Ctrl or Alt to the key';

  @override
  String get shortcutNeedsModifierMac => 'Add ⌘, ⌃ or ⌥ to the key';

  @override
  String get shortcutReserved => 'Used by the system';

  @override
  String get shortcutReservedMac => 'Used by macOS';

  @override
  String shortcutUsedBy(String title) {
    return 'Already used by “$title”';
  }

  @override
  String get shortcutReplace => 'Replace';

  @override
  String get shortcutRestore => 'Restore default';

  @override
  String get shortcutsRestoreAll => 'Restore defaults';

  @override
  String get shortcutsRestoreAllTitle => 'Restore all shortcuts?';

  @override
  String get shortcutsRestoreAllMessage =>
      'Every shortcut you changed goes back to its default.';

  @override
  String get shortcutsRestoreConfirm => 'Restore';

  @override
  String get adminTitleHint => 'Title (optional)';

  @override
  String get adminTitleNote => 'Shown to members in place of \"admin\".';

  @override
  String get permCreateTopics => 'Create topics';

  @override
  String get permissions => 'Permissions';

  @override
  String get permissionsEveryone => 'What members can do';

  @override
  String get slowMode => 'Slow mode';

  @override
  String get slowModeOffNote =>
      'Members can send messages as often as they like.';

  @override
  String slowModeNote(String interval) {
    return 'Members can send one message every $interval.';
  }

  @override
  String get off => 'Off';

  @override
  String secondsShort(int count) {
    return '${count}s';
  }

  @override
  String minutesShort(int count) {
    return '${count}m';
  }

  @override
  String hoursShort(int count) {
    return '${count}h';
  }

  @override
  String get removedUsers => 'Removed users';

  @override
  String get noRemovedUsers => 'Nobody is banned or restricted.';

  @override
  String get unban => 'Unban';

  @override
  String get banned => 'Banned';

  @override
  String bannedUntil(String until) {
    return 'Banned $until';
  }

  @override
  String get restricted => 'Restricted';

  @override
  String cannot(String what) {
    return 'Can\'t $what';
  }

  @override
  String untilDate(String date) {
    return 'until $date';
  }

  @override
  String get joinRequests => 'Join requests';

  @override
  String get noJoinRequests => 'Nobody is waiting to join.';

  @override
  String requestedOn(String date) {
    return 'Asked $date';
  }

  @override
  String get approve => 'Approve';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get recentActions => 'Recent actions';

  @override
  String get recentActionsFailed => 'Couldn\'t load the recent actions.';

  @override
  String get noRecentActions => 'No recent actions.';

  @override
  String get recentActionsNote => 'Actions of the last 48 hours.';

  @override
  String get allAdmins => 'All admins';

  @override
  String get logMedia => 'a media message';

  @override
  String logEditedMessage(String text) {
    return 'edited a message: $text';
  }

  @override
  String logDeletedMessage(String text) {
    return 'deleted a message: $text';
  }

  @override
  String logPinnedMessage(String text) {
    return 'pinned a message: $text';
  }

  @override
  String get logUnpinnedMessage => 'unpinned a message';

  @override
  String get logStoppedPoll => 'stopped a poll';

  @override
  String get logJoined => 'joined';

  @override
  String logJoinedByLink(String link) {
    return 'joined by the link $link';
  }

  @override
  String logJoinedByRequest(String name) {
    return 'joined, approved by $name';
  }

  @override
  String logInvited(String name) {
    return 'added $name';
  }

  @override
  String get logLeft => 'left';

  @override
  String logPromoted(String name) {
    return 'made $name an admin or changed their rights';
  }

  @override
  String logDemoted(String name) {
    return 'dismissed $name as admin';
  }

  @override
  String logBanned(String name) {
    return 'banned $name';
  }

  @override
  String logRestricted(String name) {
    return 'restricted $name';
  }

  @override
  String logUnrestricted(String name) {
    return 'lifted the restrictions of $name';
  }

  @override
  String logTitleChanged(String name, String title) {
    return 'gave $name the title $title';
  }

  @override
  String logTitleSet(String title) {
    return 'renamed the chat to $title';
  }

  @override
  String get logDescriptionChanged => 'changed the description';

  @override
  String get logPhotoChanged => 'changed the photo';

  @override
  String get logPhotoRemoved => 'removed the photo';

  @override
  String get logMadePrivate => 'made the chat private';

  @override
  String logMadePublic(String username) {
    return 'made the chat public at t.me/$username';
  }

  @override
  String get logUsernamesChanged => 'changed the links';

  @override
  String get logPermissionsChanged => 'changed the permissions';

  @override
  String get logSlowModeOff => 'turned slow mode off';

  @override
  String logSlowModeOn(String interval) {
    return 'set slow mode to $interval';
  }

  @override
  String get logLinked => 'linked a chat';

  @override
  String get logUnlinked => 'unlinked the chat';

  @override
  String get logReactionsChanged => 'changed the allowed reactions';

  @override
  String get logHistoryShown => 'made the history visible to new members';

  @override
  String get logHistoryHidden => 'hid the history from new members';

  @override
  String get logInvitesOn => 'let members add others';

  @override
  String get logInvitesOff => 'stopped members adding others';

  @override
  String get logSignaturesOn => 'turned signatures on';

  @override
  String get logSignaturesOff => 'turned signatures off';

  @override
  String get logProtectedOn => 'turned forwarding off';

  @override
  String get logProtectedOff => 'turned forwarding on';

  @override
  String logLinkEdited(String link) {
    return 'edited the link $link';
  }

  @override
  String logLinkRevoked(String link) {
    return 'revoked the link $link';
  }

  @override
  String logLinkDeleted(String link) {
    return 'deleted the link $link';
  }

  @override
  String get logVideoChatStarted => 'started a video chat';

  @override
  String get logVideoChatEnded => 'ended the video chat';

  @override
  String get logTopicsOn => 'turned topics on';

  @override
  String get logTopicsOff => 'turned topics off';

  @override
  String logTopicCreated(String name) {
    return 'created the topic $name';
  }

  @override
  String logTopicEdited(String name) {
    return 'edited the topic $name';
  }

  @override
  String logTopicDeleted(String name) {
    return 'deleted the topic $name';
  }

  @override
  String logTopicToggled(String name) {
    return 'closed or reopened the topic $name';
  }

  @override
  String get logTopicPinned => 'pinned or unpinned a topic';

  @override
  String get logStickerSetChanged => 'changed the sticker set';

  @override
  String get logAutoDeleteChanged => 'changed the auto-delete timer';

  @override
  String get logOther => 'changed a setting';

  @override
  String get groupType => 'Group type';

  @override
  String get channelType => 'Channel type';

  @override
  String get privateChat => 'Private';

  @override
  String get publicChat => 'Public';

  @override
  String get privateGroupNote => 'Only people with an invite link can join.';

  @override
  String get publicGroupNote => 'Anyone can find the group in search and join.';

  @override
  String get privateChannelNote =>
      'Only people with an invite link can subscribe.';

  @override
  String get publicChannelNote =>
      'Anyone can find the channel in search and subscribe.';

  @override
  String get usernameTaken => 'This link is already taken.';

  @override
  String get usernameInvalid =>
      'Use 5 to 32 letters, digits and underscores, starting with a letter.';

  @override
  String get usernameTooMany =>
      'You have too many public chats. Make one private first.';

  @override
  String usernameNotSet(String username) {
    return 'The channel is created, but t.me/$username is taken. Pick another link in its info.';
  }

  @override
  String get publicLinkOptional => 'public link (optional)';

  @override
  String get reactions => 'Reactions';

  @override
  String get reactionsAll => 'All';

  @override
  String get reactionsSome => 'Some';

  @override
  String get reactionsNone => 'None';

  @override
  String get reactionsAllNote => 'Members can react with any emoji.';

  @override
  String get reactionsSomeNote =>
      'Members can react only with the emoji picked here.';

  @override
  String get reactionsNoneNote => 'Nobody can react to messages.';

  @override
  String get discussionGroup => 'Discussion group';

  @override
  String get linkedChannel => 'Linked channel';

  @override
  String get discussionGroupNote => 'Comments under posts go to this group.';

  @override
  String get linkedChannelNote =>
      'This group holds the comments of the channel.';

  @override
  String get pickDiscussionGroup =>
      'Pick a group you manage for the comments under posts.';

  @override
  String get noSuitableGroups => 'You have no group to link. Create one first.';

  @override
  String get unlink => 'Unlink';

  @override
  String get unlinkTitle => 'Unlink?';

  @override
  String get unlinkGroupMessage =>
      'Posts will have no comments until another group is linked.';

  @override
  String get unlinkChannelMessage =>
      'The group will no longer hold the channel\'s comments.';

  @override
  String get addMembers => 'Add members';

  @override
  String get addSubscribers => 'Add subscribers';

  @override
  String get add => 'Add';

  @override
  String get editLink => 'Edit link';

  @override
  String get manage => 'Manage';

  @override
  String get historyForNewMembers => 'Show history to new members';

  @override
  String get topics => 'Topics';

  @override
  String get approveNewMembers => 'Approve new members';

  @override
  String get none => 'None';

  @override
  String ofCount(int count, int total) {
    return '$count of $total';
  }

  @override
  String get chatLinkHint => 'link';

  @override
  String get chatLinkAvailable => 'This link is available.';

  @override
  String get chatBackground => 'Chat background';

  @override
  String get chatBackgroundHint =>
      'Gradients follow the theme. A picture of your own is dimmed a little in the dark theme.';

  @override
  String get wallpaperMist => 'Mist';

  @override
  String get wallpaperSage => 'Sage';

  @override
  String get wallpaperLinen => 'Linen';

  @override
  String get wallpaperClassic => 'Classic';

  @override
  String get wallpaperOcean => 'Ocean';

  @override
  String get wallpaperLavender => 'Lavender';

  @override
  String get wallpaperSand => 'Sand';

  @override
  String get wallpaperGraphite => 'Graphite';

  @override
  String get wallpaperPlain => 'Plain';

  @override
  String get wallpaperPicture => 'Picture';

  @override
  String get choosePicture => 'Choose picture…';

  @override
  String get changePicture => 'Change picture…';

  @override
  String get blurPicture => 'Blur picture';

  @override
  String get nightSchedule => 'Dark theme by schedule';

  @override
  String get nightScheduleHint =>
      'Switches to the dark theme between these hours, whatever the theme above says.';

  @override
  String get nightFrom => 'From';

  @override
  String get nightTo => 'To';

  @override
  String get blurTheme => 'Vesper Blur';

  @override
  String get blurThemeHint =>
      'A dark, matte window that blurs the desktop behind it. Replaces the theme above while on.';

  @override
  String get blurOpacity => 'Window opacity';

  @override
  String get layout => 'Layout';

  @override
  String get mediaCorners => 'Media corners';

  @override
  String get cornerSmall => 'Small';

  @override
  String get cornerMedium => 'Medium';

  @override
  String get cornerLarge => 'Large';

  @override
  String get compactLayout => 'Compact layout';

  @override
  String get compactLayoutHint =>
      'Tighter rows in the chat list and less air between messages.';

  @override
  String get appIcon => 'App icon';

  @override
  String get appIconHint =>
      'The icon in the Dock while Mollygram runs. Finder keeps the one the app ships with.';

  @override
  String get appIconCrimson => 'Crimson';

  @override
  String get appIconBlue => 'Blue';

  @override
  String get appIconGraphite => 'Graphite';

  @override
  String get downloads => 'Downloads';

  @override
  String get downloadsEmpty => 'No downloads';

  @override
  String get downloadsEmptyHint =>
      'Files you save from chats will show up here.';

  @override
  String get pauseAll => 'Pause all';

  @override
  String get resumeAll => 'Resume all';

  @override
  String get resume => 'Resume';

  @override
  String get clearFinished => 'Clear finished';

  @override
  String get removeFromList => 'Remove from list';

  @override
  String get downloadPaused => 'Paused';

  @override
  String downloadProgress(String done, String total) {
    return '$done of $total';
  }

  @override
  String downloadsActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files downloading',
      one: '$count file downloading',
    );
    return '$_temp0';
  }

  @override
  String downloadsAllPaused(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads paused',
      one: '$count download paused',
    );
    return '$_temp0';
  }

  @override
  String downloadsFinished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files downloaded',
      one: '$count file downloaded',
    );
    return '$_temp0';
  }

  @override
  String translateTo(String language) {
    return 'Translate to $language';
  }

  @override
  String translatedFrom(String language) {
    return 'Translated from $language';
  }

  @override
  String get translated => 'Translated';

  @override
  String get translating => 'Translating…';

  @override
  String get translateShowOriginal => 'Show original';

  @override
  String get translateOptions => 'Translation options';

  @override
  String get translateChooseLanguage => 'Translate to…';

  @override
  String translateSkipLanguage(String language) {
    return 'Don\'t translate $language';
  }

  @override
  String get translateHideBar => 'Hide';

  @override
  String get translateFailed => 'Couldn\'t translate some messages';
}
