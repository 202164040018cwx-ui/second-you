# Open Date: Second You

A consumer iPhone app for dating where your AI agent goes first. Your **Second You** learns how you talk and what you
value, on your iPhone. It chats with other people's agents before you do, and you only hear about someone when the
chemistry is real. If you both say yes, you see each other, and your agent plans the first date. Nothing is booked
until you tap Confirm.

No extra hardware: everything runs on the phone.

## Features
- **Discover:** a nearby room over Bluetooth, plus a map of people on the same floor.
- **Second You:** learns your style, interests and hard nos with Apple's on-device Foundation Models. Training data stays on the phone.
- **Agents date first:** agent-to-agent conversations with photos and names hidden, a chemistry score with a confidence interval, and dealbreaker checks.
- **Date planning:** your agent suggests the place and time, and you confirm.
- **Record the date (new):** after you both agree, the phone's microphone records the date and Apple speech recognition transcribes it on the device. Only the transcript is kept, never the audio. Your Second You uses it to summarize the date and decide whether to plan a second one.

## Backend: Convex
When you summarize a date, the summary, your rating and your agent's score are saved to a Convex backend (`convex-backend/`, table `dateReviews`, functions `dates:save` and `dates:history`). Transcripts and audio never leave the phone.

## Provenance (please read)
This project started at **VexoHacks on Nov 14 2026**. The original is at https://github.com/qianjiang-git/open-date, by
Qian Jiang, Wenxin Chang and Khagendra Khatri, and its git history is kept here.

Work done on **Nov 15 2026** for the Consumer Mobile Hackathon:
- Removed the Vexo band and the Vexo Signal server, so the app is phone-only.
- Added on-device date recording and transcription (`DateRecorder.swift`) and fed the transcript into the date summary.
- Added a Convex backend for date history (`convex-backend/`, `ConvexSync.swift`).

## Run it
Open `OpenDate.xcodeproj` in Xcode 26, choose your team, and run it on an iPhone with iOS 26 for Foundation Models
(it builds for iOS 17+). More detail: [second-you/README.md](second-you/README.md).
