// App screens drawn in HTML and CSS, ported from design/website/AppShot.dc.html.
// Each export returns the markup for one screen; build.mjs inlines it into
// the page so the site ships no screenshots and follows the visitor's theme.

const icon = (d, { size = 16, sw = 1.8, extra = '' } = {}) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" ${extra}>${d}</svg>`;

const I = {
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
  compose: '<path d="M12 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-6"/><path d="M17.5 3.5a2.1 2.1 0 0 1 3 3L12 15l-4 1 1-4z"/>',
  phone: '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2"/>',
  ghost: '<path d="M6 20V10a6 6 0 0 1 12 0v10l-2-1.5-2 1.5-2-1.5-2 1.5-2-1.5z"/><path d="M10 10h.01M14 10h.01" stroke-width="2.4"/>',
  clip: '<path d="M21 11.5 12.5 20a5 5 0 0 1-7-7l8.5-8.5a3.3 3.3 0 0 1 4.7 4.7L10.2 17.7a1.7 1.7 0 0 1-2.4-2.4L15.5 7.6"/>',
  video: '<rect x="3" y="6" width="13" height="12" rx="3"/><path d="m16 10 5-3v10l-5-3"/>',
  down: '<path d="M12 5v12M7 12l5 5 5-5"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
};

const lights = '<span class="mw-lights"><span></span><span></span><span></span></span>';

const CHATS = [
  { id: 'team', ini: 'PT', name: 'Product team', last: 'Vicky: Call at 16:30 then', time: '14:12', unread: 3 },
  { id: 'anna', ini: 'AM', name: 'Anna Morris', last: 'Voice message', time: '14:03' },
  { id: 'dennis', ini: 'D', name: 'Dennis', last: 'You: thanks, sent it back', time: '13:20' },
  { id: 'dad', ini: 'D', name: 'Dad', last: 'Call me when you have a minute', time: '12:47', unread: 2 },
  { id: 'book', ini: 'BC', name: 'Book club', last: 'Irene: voting on the November book', time: '11:30', unread: 12, muted: true },
  { id: 'saved', ini: 'S', name: 'Saved Messages', last: 'lease_agreement.pdf', time: 'Yesterday' },
  { id: 'flutter', ini: 'FD', name: 'Flutter Dev', last: 'What’s new on desktop', time: 'Yesterday', unread: 4, muted: true },
  { id: 'olivia', ini: 'OK', name: 'Olivia Kim', last: 'Could you look at the mockups tonight?', time: 'Mon' },
  { id: 'house', ini: 'B2', name: 'Building, entrance 2', last: 'Hot water is off tomorrow', time: 'Mon', unread: 28, muted: true },
];

function sidebar(selected) {
  const rows = CHATS.map(
    (c) => `<div class="mw-row${c.id === selected ? ' on' : ''}">
  <span class="mw-av" style="--s:40px">${c.ini}</span>
  <span class="mw-rt"><span class="mw-rl"><b>${c.name}</b><span class="s mw-time">${c.time}</span></span>
  <span class="mw-rl"><span class="s mw-last">${c.last}</span>${c.unread ? `<span class="mw-badge${c.muted ? ' m' : ''}">${c.unread}</span>` : ''}</span></span>
</div>`,
  ).join('');
  return `<div class="mw-glass mw-side">
  <div class="mw-sidetop">${lights}<span class="mw-ib">${icon(I.compose, { sw: 1.7 })}</span></div>
  <div class="mw-search">${icon(I.search, { size: 13, sw: 2.2 })}<span>Search</span><span class="k">⌘K</span></div>
  <div class="mw-folders"><span class="mw-tab on">All</span><span class="mw-tab">Personal <small>2</small></span><span class="mw-tab">Work <small>3</small></span><span class="mw-tab">Channels</span></div>
  <div class="mw-list">${rows}</div>
</div>`;
}

const header = (ini, name, status, buttons) => `<div class="mw-head">
  <div class="mw-glass mw-who"><span class="mw-av" style="--s:30px">${ini}</span><span class="mw-col"><b>${name}</b><span class="s">${status}</span></span></div>
  <div class="mw-glass mw-tools">${buttons}</div>
</div>`;

const sender = (name) => `<div class="mw-from">${name}</div>`;

const WAVE = [5, 8, 13, 10, 16, 12, 7, 14, 18, 12, 8, 11, 15, 9, 6, 13, 17, 10, 7, 12, 15, 9, 6, 10, 14, 8, 11, 7, 9, 6];

function round(size, label) {
  const r = size / 2 - (size > 200 ? 4 : 3);
  const len = Math.round(2 * Math.PI * r);
  const sw = size > 200 ? 4 : 3;
  return `<div class="mw-round" style="--s:${size}px">
  <div class="mw-face"></div>
  <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}"><circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="rgba(255,255,255,.35)" stroke-width="${sw}"/><circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="#fff" stroke-width="${sw}" stroke-linecap="round" stroke-dasharray="${len}" stroke-dashoffset="${Math.round(len * 0.667)}" transform="rotate(-90 ${size / 2} ${size / 2})"/></svg>
  <span class="mw-dur">${label}</span>
</div>`;
}

export { round };

function annaChat() {
  const wave = WAVE.map((h, i) => `<span style="height:${h}px${i < 12 ? '' : ';opacity:.35'}"></span>`).join('');
  return `<div class="mw-main">
  <div class="mw-scroll"><div class="mw-msgs">
    <div class="mw-in">Sent the photos from the weekend, a couple of them came out really well<div class="mw-meta">13:55</div></div>
    <div class="mw-album"><div><span class="ph1"></span><span class="ph2"></span></div><span class="mw-stamp">13:56</span></div>
    <div class="mw-out gap">The second one is great. Can you send it as a file? I want to print it<div class="mw-meta">13:58 ✓✓</div></div>
    <div class="mw-in mw-file gap" style="width:260px"><span class="mw-fi">${icon(I.down, { size: 17, sw: 2 })}</span><span class="mw-grow"><b>IMG_2041.HEIC</b><span class="mw-meta mw-split"><span>6.8 MB, original</span><span>14:01</span></span></span></div>
    <div class="gap">${round(184, '0:04 / 0:12 · 120 fps')}</div>
    <div class="mw-in mw-voice gap"><div class="mw-vrow"><span class="mw-play"><svg width="13" height="13" viewBox="0 0 24 24"><path d="M7 4.5v15l13-7.5z" fill="#fff"/></svg></span><span class="mw-wave">${wave}</span><span class="s">0:18</span></div><div style="margin-top:6px">We’re meeting at Alex’s on Saturday evening, bring that board game if you can</div></div>
    <div class="mw-out gap">Will do. See you there<div class="mw-meta">14:05 ✓</div></div>
  </div></div>
  ${header('AM', 'Anna Morris', 'online', `<span class="mw-ib">${icon(I.search)}</span><span class="mw-ib">${icon(I.phone)}</span><span class="mw-ib">${icon(I.ghost)}</span>`)}
  <div class="mw-foot"><div class="mw-glass mw-composer"><span class="mw-ib">${icon(I.clip, { size: 17 })}</span><span class="mw-grow s">Message</span><span class="mw-ib">${icon(I.video, { size: 17 })}</span></div></div>
</div>`;
}

const palette = `<div class="mw-pal">
  <div class="mw-palin">${icon(I.search, { size: 17, sw: 2 })}<span class="mw-q">&gt; spl<i></i></span><span class="s">Commands</span></div>
  <div class="mw-palbody">
    <div class="mw-sec">Commands</div>
    <div class="mw-it on">${icon('<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M12 4v16"/>')}Split view with Product team<span class="k">⌘\\</span></div>
    <div class="mw-it">${icon('<rect x="3" y="6" width="18" height="14" rx="3"/><path d="M3 10h18M8 6V3"/>')}Open chat in a new tab<span class="k">⌘T</span></div>
    <div class="mw-it">${icon('<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M15 4v16"/>')}Split view: close the right pane<span class="k">⇧⌘\\</span></div>
    <div class="mw-sec">Messages</div>
    <div class="mw-it"><span class="mw-av" style="--s:22px">VS</span><span>split the release notes by platform</span><span class="k">Product team</span></div>
  </div>
  <div class="mw-palfoot"><span>&gt; commands</span><span>@ people</span><span># messages</span></div>
</div>`;

const TEAM = [
  ['Vicky Stone', 'Build 214 is up. Can someone check sign-in on an Intel Mac?', '14:08'],
  ['Adam Lewis', 'Works on my 2019 MacBook Pro, QR code too', '14:09'],
];

function split() {
  const tab = (ini, name, on) => `<span class="mw-tab big${on ? ' on' : ''}">${ini ? `<span class="mw-av" style="--s:18px">${ini}</span>` : ''}${name}</span>`;
  return `<div class="mw-main">
  <div class="mw-tabs"><div class="mw-glass">${tab('AM', 'Anna Morris', true)}${tab('PT', 'Product team', true)}${tab('FD', 'Flutter Dev')}${tab('', 'Olivia Kim')}<span class="mw-ib">${icon(I.plus, { size: 14, sw: 2 })}</span></div></div>
  <div class="mw-panes">
    <div class="mw-pane">
      <div class="mw-in">Sent the photos from the weekend, a couple of them came out really well<div class="mw-meta">13:55</div></div>
      <div class="mw-out">The second one is great. Can you send it as a file? I want to print it<div class="mw-meta">13:58 ✓✓</div></div>
      <div class="mw-in mw-file" style="width:230px"><span class="mw-fi">${icon(I.down, { sw: 2 })}</span><span class="mw-grow"><b>IMG_2041.HEIC</b><span class="mw-meta" style="text-align:left">6.8 MB, original</span></span></div>
      <div class="mw-out">Will do. See you there<div class="mw-meta">14:05 ✓</div></div>
      <div class="mw-glass mw-mini">Message Anna</div>
    </div>
    <div class="mw-pane">
      ${TEAM.map(([n, t, h]) => `<div class="mw-in">${sender(n)}${t}<div class="mw-meta">${h}</div></div>`).join('')}
      <div class="mw-out">Great. Let’s split the release notes by platform<div class="mw-meta">14:11 ✓✓</div></div>
      <div class="mw-in">${sender('Vicky Stone')}Call at 16:30 then<div class="mw-meta">14:12</div></div>
      <div class="mw-glass mw-mini">Message Product team</div>
    </div>
  </div>
</div>`;
}

function privacy() {
  return `<div class="mw-main">
  <div class="mw-scroll"><div class="mw-msgs">
    ${TEAM.map(([n, t, h]) => `<div class="mw-in">${sender(n)}${t}<div class="mw-meta">${h}</div></div>`).join('')}
    <div class="mw-in" style="opacity:.6">${sender('Adam Lewis')}Also, the staging password is in the pinned message<div class="mw-meta mw-split"><span class="mw-del">${icon(I.trash, { size: 11, sw: 2 })}deleted at 14:10, kept on this Mac</span><span>14:09</span></div></div>
    <div class="mw-out gap">Great. Let’s split the release notes by platform<div class="mw-meta">14:11 ✓✓</div></div>
    <div class="mw-edits gap">
      <div class="mw-in">${sender('Vicky Stone')}Call at 16:30 then<div class="mw-meta">edited 14:12</div></div>
      <div class="mw-hist">
        <div class="mw-sec">Edit history</div>
        <div><span>14:12</span>Call at 16:30 then</div>
        <div class="old"><span>14:10</span><s>Call at 16:00 then</s></div>
        <div class="old"><span>14:10</span><s>Call at 4 then</s></div>
      </div>
    </div>
  </div></div>
  ${header('PT', 'Product team', '8 members · you are invisible', `<span class="mw-ib">${icon(I.search)}</span><span class="mw-ib on">${icon(I.ghost)}</span>`)}
  <div class="mw-foot"><div class="mw-glass mw-composer pad"><span class="mw-grow">Message</span><small>Read receipts off</small></div></div>
</div>`;
}

const PLUGINS = [
  ['Transcribe voice', 'Built in · voice and video messages to text, on device', 'M9 5h6a3 3 0 0 1 3 3v3a6 6 0 0 1-12 0V8a3 3 0 0 1 3-3zM12 17v4', true],
  ['Translate', 'Built in · messages and the composer, any provider you set', 'M4 5h9M8.5 3v2M6 5c1 4 4 7 7 8M11 5c-1 4-4 7-7 8M13 21l4-9 4 9M14.5 18h5', true],
  ['Chat filters', 'Built in · hide messages by keyword, sender or type', 'M4 5h16l-6 7v6l-4 2v-8z', false],
  ['Quiet hours', 'tools.calm.quiet · mutes notifications on a schedule', 'M20 14A8 8 0 1 1 10 4a6 6 0 0 0 10 10z', true],
];

function plugins() {
  const nav = ['Account', 'Notifications', 'Privacy and security', 'Ghost mode', 'Media', 'Appearance', 'Windows and tabs', 'Plugins']
    .map((l) => `<div class="mw-it${l === 'Plugins' ? ' on' : ''}">${l}</div>`).join('');
  const rows = PLUGINS.map(
    ([name, desc, d, on]) => `<div class="mw-prow"><span class="mw-pi">${icon(`<path d="${d}"/>`)}</span><span class="mw-grow mw-col"><b>${name}</b><span class="s mw-last">${desc}</span></span><span class="mw-sw${on ? ' on' : ''}"><span></span></span></div>`,
  ).join('');
  const perm = (d, text, off) => `<div class="mw-perm${off ? ' s' : ''}">${icon(d, { size: 15 })}<span>${text}</span></div>`;
  return `<div class="mw-settings">
  <div class="mw-nav">${lights}${nav}</div>
  <div class="mw-pane-s">
    <div class="mw-title">Plugins</div>
    <div class="mw-card">${rows}</div>
    <div class="mw-sec">Transcribe voice can</div>
    <div class="mw-card">
      ${perm('<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0"/>', 'Read voice and video messages you open')}
      ${perm('<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M8 9h8M8 13h5"/>', 'Keep up to 1 MB of its own data')}
      ${perm('<circle cx="12" cy="12" r="9"/><path d="M5.6 5.6l12.8 12.8"/>', 'No network access', true)}
    </div>
    <pre>id: dev.mollygram.transcribe
runtime: js
permissions:
  media.read: [voice, round]
  storage: 1mb</pre>
  </div>
</div>`;
}

const LABELS = {
  Chat: 'Mollygram window: chat list in a glass sidebar, a chat with photos, a file sent in original quality, a round video message and a voice message.',
  Palette: 'Mollygram command palette open over a chat, filtering commands for split view.',
  Split: 'Mollygram with four chats open as tabs and two of them side by side in split view.',
  Privacy: 'A group chat in ghost mode: a deleted message is kept and greyed out, and an edited message shows its edit history.',
  Plugins: 'Plugin settings styled like macOS System Settings, listing plugins with switches and the permissions of the transcription plugin.',
};

/** Returns the figure for one screen: "Chat", "Palette", "Split", "Privacy" or "Plugins". */
export function shot(screen, size = 'md') {
  let inner;
  switch (screen) {
    case 'Chat': inner = sidebar('anna') + annaChat(); break;
    case 'Palette': inner = sidebar('anna') + annaChat() + palette; break;
    case 'Split': inner = sidebar('anna') + split(); break;
    case 'Privacy': inner = sidebar('team') + privacy(); break;
    case 'Plugins': inner = plugins(); break;
    default: throw new Error(`unknown screen ${screen}`);
  }
  const cls = `mw mw-${size}${screen === 'Plugins' ? ' mw-win' : ''}${screen === 'Palette' ? ' mw-has-pal' : ''}`;
  return `<div class="${cls}" role="img" aria-label="${LABELS[screen]}"><div class="mw-box">${inner}</div></div>`;
}
