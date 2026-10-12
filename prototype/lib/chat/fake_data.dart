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
  });

  final String name;
  final String initials;
  final String last;
  final String time;
  final int unread;
  final bool muted;
  final String status;
}

const _phrases = [
  'Привет',
  'Ок',
  'Да, давай',
  'Сейчас посмотрю',
  'Ты в субботу во сколько освободишься?',
  'Часам к трём, потом свободна',
  'Скинула фотки с выходных, там есть пара хороших',
  'Можешь кинуть без сжатия? Хочу распечатать',
  'Завтра созвон в 16:30, не забудь',
  'Я опаздываю минут на десять',
  'Купи, пожалуйста, хлеб и молоко по дороге',
  'Посмотрела макеты, в целом нравится, но отступы в списке чатов кажутся крупными',
  'Там ещё нужно поправить текст на второй странице',
  'Спасибо!',
  'Договорились',
  'А где встречаемся?',
  'У входа в парк, где фонтан',
  'Слушай, а ты не помнишь, как называлась та кофейня на углу, где мы сидели в прошлом месяце?',
  'Отправила договор, проверь, всё ли верно',
  'Вечером в субботу собираемся у Лёши, возьми настолку, если не сложно',
  'Ага',
  'Сегодня не получится, давай завтра',
  'Я уже дома',
  'Билеты взяла, места в седьмом ряду',
  'Перезвоню через час',
  'Отличная идея',
  'Нет, это было в четверг',
  'Пришли, пожалуйста, адрес ещё раз',
  'Кажется, сборка падает только на маке, на линуксе всё зелёное',
  'Посмотри, что я нашла',
  'Хорошо, тогда в восемь',
  'Не знаю, надо подумать',
  'Звучит как план',
  'Я написала в поддержку, ответили, что починят к понедельнику',
  'Кто заберёт ключи?',
  'Я заберу',
];

const _files = [
  'IMG_2041.HEIC',
  'договор_аренды.pdf',
  'отчёт_сентябрь.xlsx',
  'presentation_v3.key',
  'scan_0012.pdf',
];

/// Детерминированная лента: 0 — самое новое сообщение (список перевёрнут).
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
          text: day == 0 ? 'Сегодня' : (day == 1 ? 'Вчера' : _dayName(day)),
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
  const names = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  if (day < 7) return names[(10 - day) % 7];
  final d = 1 + (40 - day) % 28;
  const months = ['сентября', 'августа', 'июля', 'июня', 'мая'];
  return '$d ${months[(day ~/ 30) % months.length]}';
}

const fakeChats = [
  FakeChat(
    'Команда продукта',
    'КП',
    'Вика: ок, тогда созвон в 16:30',
    '14:12',
    unread: 3,
    status: '8 участников',
  ),
  FakeChat('Аня Морозова', 'АМ', 'Видеосообщение', '14:03', status: 'в сети'),
  FakeChat('Денис', 'Д', 'Вы: спасибо, вернул', '13:20'),
  FakeChat('Папа', 'П', 'Позвони, как будет минутка', '12:47', unread: 2),
  FakeChat(
    'Книжный клуб',
    'КК',
    'Ира: голосуем за книгу на ноябрь',
    '11:30',
    unread: 12,
    muted: true,
  ),
  FakeChat('Избранное', 'И', 'договор_аренды.pdf', 'вчера'),
  FakeChat(
    'Flutter Dev',
    'FD',
    'Что нового на десктопе',
    'вчера',
    unread: 4,
    muted: true,
  ),
  FakeChat(
    'Дом, 2-й подъезд',
    'Д2',
    'Завтра отключат горячую воду',
    'пн',
    unread: 28,
    muted: true,
  ),
  FakeChat('Оля Ким', 'ОК', 'Посмотришь макеты до вечера?', 'пн'),
  FakeChat('Марина', 'М', 'Фото', 'вс'),
  FakeChat('Работа, общий', 'РО', 'Саша: релиз переносим на среду', 'вс'),
  FakeChat('Костя', 'К', 'Вы: ок', 'сб'),
  FakeChat('Бег по субботам', 'БС', 'Сбор в 9:00 у входа', 'сб', muted: true),
  FakeChat('Лёша', 'Л', 'Голосовое сообщение', 'пт'),
  FakeChat('Бабушка', 'Б', 'Спасибо, внученька', 'пт'),
  FakeChat('Студия йоги', 'СЙ', 'Расписание на неделю', 'чт', muted: true),
  FakeChat('Игорь', 'И', 'Вы: перезвоню', 'чт'),
  FakeChat('Ремонт', 'Р', 'Плитку привезут в среду', 'ср'),
  FakeChat('Настя', 'Н', 'Ахаха', 'ср'),
  FakeChat(
    'Новости района',
    'НР',
    'Перекрытие улицы до 20:00',
    'вт',
    muted: true,
  ),
  FakeChat('Вика', 'В', 'Отправила договор', 'вт'),
  FakeChat('Семья', 'С', 'Мама: в воскресенье обед у нас', 'пн'),
];
