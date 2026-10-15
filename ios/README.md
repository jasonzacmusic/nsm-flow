# NSM Flow for iPhone

A keyboard with swipe typing and a mic key, plus the NSM Flow app that does the listening.

- **NSMFlow** (app): owns the microphone. A *Flow session* keeps on-device speech recognition ready for five minutes so the keyboard can start and stop dictation instantly. Text is cleaned (corrections, fillers, spoken punctuation, music accidentals), polished by Apple Intelligence where available (iOS 26, iPhone 15 Pro and later), and the email sign-off is added in Email mode. Every dictation is kept in the app's history.
- **NSMKeyboard** (extension): QWERTY with QuickPath-style swipe typing (`SwipeDecoder.swift`, ~25k words plus the NSM vocabulary), double-space full stop, auto-capitals, Message/Email switch and the mic key. iOS does not let keyboards record, so the mic key talks to the app through the App Group `group.com.nathanielschool.nsmflow` and Darwin notifications.

Generate the project with `xcodegen generate` (in this folder) after editing `project.yml`.

The word frequencies in `NSMKeyboard/words.txt` come from [FrequencyWords](https://github.com/hermitdave/FrequencyWords) by Hermit Dave (CC BY-SA 4.0), filtered against the macOS word list.
