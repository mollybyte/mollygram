# Privacy store

Mollygram's own database, kept next to TDLib's, for what TDLib forgets:
messages others delete for everyone, and earlier versions of edited
messages. It is written only while the matching switch is on (Settings,
Privacy extras: "Keep deleted messages", "Keep edit history"); both are off
by default.

Code: [packages/core/lib/src/store](../packages/core/lib/src/store).

## Storage

- One file per account: `accounts/<slot>/mollygram.db` under the
  application support folder, beside the account's TDLib `database/` and
  `files/` ([AccountStorage](../packages/core/lib/src/account_storage.dart)).
- Encrypted with SQLCipher. `package:sqlite3` bundles a prebuilt SQLCipher
  through its build hook (`hooks: user_defines: sqlite3: source: sqlcipher`
  in the root `pubspec.yaml`). The store refuses to open when the loaded
  SQLite has no `cipher_version`, so it is never written in the clear.
- The key is 32 random bytes in the system keychain, under
  `mollygram.store.database-key.v1.account-<slot>`, next to the TDLib key.
- drift runs the queries on a background isolate
  (`NativeDatabase.createInBackground`), so opening, writes and `VACUUM`
  never hold up a frame. The schema is plain SQL, without generated table
  classes.
- There is no way to change the key of an existing store (no `rekey`). A
  key that no longer opens the file (the keychain entry was lost or reset)
  is reported as `StoreKeyLost`; no new key is made while the file exists.
  Privacy extras then shows "Stored data can't be read" with a Reset
  button, which deletes the file and the key; the next thing kept starts a
  new store.

## Schema (version 1)

```sql
CREATE TABLE deleted_messages (
  chat_id INTEGER NOT NULL,
  message_id INTEGER NOT NULL,
  sender_id INTEGER NOT NULL,  -- user id, or a negative chat id
  date INTEGER NOT NULL,       -- sent, Unix seconds
  deleted_at INTEGER NOT NULL, -- Unix seconds
  message TEXT NOT NULL,       -- the whole td_api message as JSON
  PRIMARY KEY (chat_id, message_id)
) WITHOUT ROWID;

CREATE TABLE message_versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chat_id INTEGER NOT NULL,
  message_id INTEGER NOT NULL,
  date INTEGER NOT NULL,        -- when this version was written
  replaced_at INTEGER NOT NULL, -- the edit that replaced it
  content TEXT NOT NULL,        -- td_api messageContent as JSON
  UNIQUE (chat_id, message_id, replaced_at)
);
```

Rows that no longer decode after a TDLib update are skipped, not fatal.
A later schema adds a migration step in `StoreDatabase.migration`; version 1
files must keep opening (there is a test for it).

## Capture

With both switches off the capture does nothing at all. Otherwise, since
TDLib cannot return a message after it is deleted, `MessageCapture`
remembers recently seen messages in memory (100 per chat, 100 chats, least
recently used first out): from `updateNewMessage` and from every response
that carries messages, through `TdClient.responses`. A search across chats
only refreshes chats already remembered. Then:

- `updateDeleteMessages` with `is_permanent` and not `from_cache` keeps the
  remembered messages, in one transaction per update.
- `updateMessageContent` followed by `updateMessageEdited` keeps the
  content that was replaced. A content change without an edit, such as poll
  votes, is not a version; a later edit keeps the latest content before it.
- `updateMessageSendSucceeded` and `updateMessageSendFailed` move a message
  to its new id.

Not kept:

- Messages deleted from this app: `deleteMessages` by id, and bulk
  deletions (`deleteChatHistory`, `deleteChat`,
  `deleteChatMessagesBySender` for that sender only,
  `deleteChatMessagesByDate`, `deleteForumTopic`, the saved messages and
  direct messages topic deletions). A bulk deletion covers matching
  updates for one minute after it is asked for.
- The user's own messages in private and secret chats: TDLib reports a
  deletion from another of the user's devices the same way as one by the
  other person, so these are left out. In groups and channels the user's
  own messages can still be kept when deleted from another device; TDLib
  gives no way to tell those apart.
- Scheduled messages (sending one deletes the scheduled copy for good),
  messages still sending or failed, and messages that delete themselves on
  a timer or by auto-delete.
- Anything the app did not see while it was open.

A failed write closes the store and tries again, up to three times with a
growing wait. A lost key is not retried; it is shown on the page.

In the chat, while "Keep deleted messages" is on, a kept deleted message
stays where it was (`deleted.watchChat`), dimmed and marked "deleted",
with the deletion time on hover; while "Keep edit history" is on, an
edited message's menu has "Edit history", which lists the kept versions
(`edits.versions`) under the current one.

## API

- `MessageStore.deleted`: `forChat`, `watchChat` (a stream per chat, for
  a "deleted" mark in the chat), `find`.
- `MessageStore.edits`: `versions(chatId, messageId)`, `watchVersions`.
- `MessageStore.count`, `clear` (the "Stored data" row, Clear enabled
  while something is kept); `MessageStore.sizeOnDisk` and `deleteAt` work
  on the files without opening them.
- `TelegramSession.capture.store` opens the account's store on first use;
  `capture.changes` fires after each write, `capture.failure` holds the
  last write error.
