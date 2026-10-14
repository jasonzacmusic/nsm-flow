# Privacy and network behavior

NSM Flow performs speech recognition on the local computer. It does not operate
a Nathaniel transcription upload service. This describes the audited alpha code;
it is not a promise about a third-party server you configure.

| Action                                   | Data and destination                                                                                           |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Dictation with a downloaded speech model | Audio processed locally; text pasted via OS input/clipboard                                                    |
| Local formatting rules                   | Text processed locally                                                                                         |
| Optional local LLM                       | Transcript/prompt sent to your configured local server                                                         |
| Optional cloud or remote custom LLM      | Transcript/prompt, model identifier and configured credentials sent to that provider                           |
| Model download/discovery                 | HTTPS requests to Hugging Face/upstream model hosts; host receives normal request metadata                     |
| Update check/download                    | HTTPS to GitHub Pages/GitHub release assets; no transcript or recording payload                                |
| Optional Google sign-in                  | Browser OAuth with Google using PKCE and state, then profile retrieval; only verified name/email saved locally |
| Opening support/product links            | Opens a browser; the destination's policies apply                                                              |

Local speech recognition needs no account. Optional Google sign-in is identity
for the team profile, not a secure entitlement system. Tokens are used for
profile lookup and are not persisted by this code. Optional provider keys use
Keychain on macOS, Windows Credential Manager, or Linux Secret Service. A legacy
plaintext key is erased only after successful verified vault migration; failed
migrations retain it for retry. Portable Windows mode still uses the OS vault.

Text history persists locally unless you choose expiry or retention off. Source
audio retention defaults to deletion after processing, but recording files can
exist during processing. Saved text entries survive automatic expiry. Confirmed
**Clear history** removes stored entries, including saved ones. Removing history
does not erase clipboard contents, other apps' pasted documents, system backups,
or previously collected logs. The app does not encrypt its local database or
model files. Use OS account controls and disk encryption appropriate to your needs.

Routine logging defaults to Warn. Debug logging can include sensitive content;
review it before sharing. Do not upload student names, lesson transcripts, or
recordings without consent. Review the contents of a portable `Data` folder
before copying it to another computer.

For offline operation: download a suitable model, keep cloud/remote formatting
unconfigured, skip Google sign-in and disable update checks. A remote URL in a
custom provider is not local simply because the provider is called “custom”.
