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
  String get menuEdit => 'Edit';

  @override
  String get menuCopyText => 'Copy text';

  @override
  String get menuCopyLink => 'Copy link';

  @override
  String get menuForward => 'Forward';

  @override
  String get menuDelete => 'Delete';

  @override
  String get cancel => 'Cancel';

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
  String get forwardTitle => 'Forward to chat';

  @override
  String get forwardSearch => 'Search chats';

  @override
  String get noChatsFound => 'No chats found';

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
  String get sendAsFiles => 'Send as files';

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
  String get statusOnline => 'online';

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
  String get statusBot => 'bot';

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
  String get blockUser => 'Block user';

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
  String get contentGame => 'Game';

  @override
  String get contentInvoice => 'Invoice';

  @override
  String get contentStory => 'Story';

  @override
  String get contentChecklist => 'Checklist';

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
  String get emojiTab => 'Emoji';

  @override
  String get stickersTab => 'Stickers';

  @override
  String get emojiSearch => 'Search emoji';

  @override
  String get recentlyUsed => 'Recently used';

  @override
  String get noEmojiFound => 'No emoji found';

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
  String get noStickerSets => 'No stickers yet';
}
