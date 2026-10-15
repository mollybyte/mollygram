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
- drift runs the queries; the schema is plain SQL, without generated table
  classes.

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

## Capture

TDLib cannot return a message after it is deleted, so `MessageCapture`
remembers recently seen messages in memory (300 per chat, 100 chats): from
`updateNewMessage` and from every response that carries messages, through
`TdClient.responses`. Then:

- `updateDeleteMessages` with `is_permanent` and not `from_cache` keeps the
  remembered message. Messages deleted from this app (`deleteMessages`,
  `deleteChatHistory` and the like, seen through `TdClient.requests`) and
  self-destructing or auto-deleting messages are not kept.
- `updateMessageContent` followed by `updateMessageEdited` keeps the
  content that was replaced. A content change without an edit, such as poll
  votes, is not kept.

Only messages the app saw while it was open can be kept.

## API

- `MessageStore.deleted`: `forChat`, `watchChat` (a stream per chat, for
  a "deleted" mark in the chat), `find`.
- `MessageStore.edits`: `versions(chatId, messageId)`, `watchVersions`.
- `MessageStore.sizeInBytes`, `clear` (the "Clear stored data" row).
- `TelegramSession.capture.store` opens the account's store on first use.
