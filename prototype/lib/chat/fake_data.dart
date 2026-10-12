import 'dart:math';

enum MsgKind { text, photos, file, voice, circle, liveCircle, date }

class FakeMessage {
  const FakeMessage({
    required this.kind,
    required this.out,
    this.text = '',
    this.time = '',
    this.read = true,
    this.deleted = false,
    this.photoCount = 0,
    this.wave = const [],
  });

  final MsgKind kind;
  final bool out;
  final String text;
  final String time;
  final bool read;
  final bool deleted;
  final int photoCount;
  final List<int> wave;
}

class FakeChat {
  const FakeChat(
    this.name,
    this.initials,
    this.last,
    this.time, {
    this.unread = 0,
    this.muted = false,
    this.status = '',
    this.id = 0,
  });

  final String name;
  final String initials;
  final String last;
  final String time;
  final int unread;
  final bool muted;
  final String status;
  final int id;
}

const _phrases = [
  'Hi',
  'Ok',
  "Sure, let's do it",
  'Let me check',
  'What time are you free on Saturday?',
  "Around three, then I'm free",
  'Sent the photos from the weekend, a couple of them are good',
  'Could you send them uncompressed? I want to print them',
  "Call tomorrow at 4:30, don't forget",
  "I'm running about ten minutes late",
  'Could you grab bread and milk on the way?',
  'Looked through the mockups, I like them overall, but the padding in the chat list feels too large',
  'The text on the second page still needs fixing',
  'Thanks!',
  'Deal',
  'Where are we meeting?',
  'At the park entrance, by the fountain',
  'Do you remember the name of that coffee place on the corner where we sat last month?',
  'Sent the contract, please check that everything is right',
  "We're meeting at Alex's on Saturday evening, bring a board game if you can",
  'Yep',
  "Can't make it today, let's do tomorrow",
  "I'm home already",
  'Got the tickets, seats in row seven',
  "I'll call back in an hour",
  'Great idea',
  'No, that was on Thursday',
  'Could you send the address again?',
  'Looks like the build only fails on macOS, Linux is all green',
  'Look what I found',
  'Fine, eight then',
  'Not sure, need to think about it',
  'Sounds like a plan',
  'I wrote to support, they said it will be fixed by Monday',
  "Who's picking up the keys?",
  'I will',
];

const _files = [
  'IMG_2041.HEIC',
  'lease_agreement.pdf',
  'report_september.xlsx',
  'presentation_v3.key',
  'scan_0012.pdf',
];

/// Builds a deterministic message list where 0 is the newest message (the
/// list is reversed).
List<FakeMessage> buildMessages(int count) {
  final rnd = Random(7);
  final list = <FakeMessage>[];
  var out = false;
  var minutes = 14 * 60 + 12;
  var day = 0;
  for (var i = 0; i < count; i++) {
    if (i == 2) {
      list.add(const FakeMessage(kind: MsgKind.liveCircle, out: false));
      continue;
    }
    if (i > 0 && rnd.nextDouble() < 0.025) {
      list.add(
        FakeMessage(
          kind: MsgKind.date,
          out: false,
          text: day == 0 ? 'Today' : (day == 1 ? 'Yesterday' : _dayName(day)),
        ),
      );
      day++;
      minutes = 23 * 60 - rnd.nextInt(10 * 60);
      continue;
    }
    if (rnd.nextDouble() < 0.4) out = !out;
    minutes -= rnd.nextInt(6);
    if (minutes < 8 * 60) minutes = 8 * 60;
    final time =
        '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
    final roll = rnd.nextDouble();
    MsgKind kind;
    if (roll < 0.78) {
      kind = MsgKind.text;
    } else if (roll < 0.86) {
      kind = MsgKind.photos;
    } else if (roll < 0.91) {
      kind = MsgKind.voice;
    } else if (roll < 0.95) {
      kind = MsgKind.file;
    } else {
      kind = MsgKind.circle;
    }
    final parts = 1 + (rnd.nextDouble() < 0.3 ? rnd.nextInt(4) : 0);
    final text = kind == MsgKind.file
        ? _files[rnd.nextInt(_files.length)]
        : List.generate(
            parts,
            (_) => _phrases[rnd.nextInt(_phrases.length)],
          ).join('. ');
    list.add(
      FakeMessage(
        kind: kind,
        out: out,
        text: text,
        time: time,
        read: i > 1 || !out,
        deleted: !out && kind == MsgKind.text && rnd.nextDouble() < 0.01,
        photoCount: 1 + rnd.nextInt(6),
        wave: List.generate(34, (_) => 4 + rnd.nextInt(15)),
      ),
    );
  }
  return list;
}

String _dayName(int day) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  if (day < 7) return names[(10 - day) % 7];
  final d = 1 + (40 - day) % 28;
  const months = ['September', 'August', 'July', 'June', 'May'];
  return '${months[(day ~/ 30) % months.length]} $d';
}

const fakeChats = [
  FakeChat(
    'Product Team',
    'PT',
    'Vicky: ok, call at 4:30 then',
    '14:12',
    unread: 3,
    status: '8 members',
  ),
  FakeChat('Anna Morris', 'AM', 'Video message', '14:03', status: 'online'),
  FakeChat('Dennis', 'D', 'You: thanks, sent it back', '13:20'),
  FakeChat('Dad', 'D', 'Call me when you have a minute', '12:47', unread: 2),
  FakeChat(
    'Book Club',
    'BC',
    'Irene: voting on the November book',
    '11:30',
    unread: 12,
    muted: true,
  ),
  FakeChat('Saved Messages', 'S', 'lease_agreement.pdf', 'Yesterday'),
  FakeChat(
    'Flutter Dev',
    'FD',
    "What's new on desktop",
    'Yesterday',
    unread: 4,
    muted: true,
  ),
  FakeChat(
    'Building, Entrance 2',
    'B2',
    'Hot water will be off tomorrow',
    'Mon',
    unread: 28,
    muted: true,
  ),
  FakeChat('Olivia Kim', 'OK', 'Can you look at the mockups tonight?', 'Mon'),
  FakeChat('Marina', 'M', 'Photo', 'Sun'),
  FakeChat('Work, General', 'WG', 'Sam: release moves to Wednesday', 'Sun'),
  FakeChat('Kevin', 'K', 'You: ok', 'Sat'),
  FakeChat(
    'Saturday Runs',
    'SR',
    'Meet at 9:00 by the entrance',
    'Sat',
    muted: true,
  ),
  FakeChat('Alex', 'A', 'Voice message', 'Fri'),
  FakeChat('Grandma', 'G', 'Thank you, dear', 'Fri'),
  FakeChat('Yoga Studio', 'YS', 'Schedule for the week', 'Thu', muted: true),
  FakeChat('Igor', 'I', "You: I'll call back", 'Thu'),
  FakeChat('Renovation', 'R', 'Tiles arrive on Wednesday', 'Wed'),
  FakeChat('Nastya', 'N', 'Haha', 'Wed'),
  FakeChat(
    'Neighborhood News',
    'NN',
    'Street closed until 20:00',
    'Tue',
    muted: true,
  ),
  FakeChat('Vicky', 'V', 'Sent the contract', 'Tue'),
  FakeChat('Family', 'F', 'Mom: lunch at our place on Sunday', 'Mon'),
];
