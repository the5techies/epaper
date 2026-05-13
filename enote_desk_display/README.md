# E-Note Desk Display

A Flutter mobile app that acts as a remote control for a custom ESP32-powered e-paper desk gadget. Manage your to-do list, send custom messages, and monitor device status — all synced in real time via Firebase. Whatever you update on your phone shows up on the e-paper display sitting on your desk.

## Features

- **To-Do List** — add, complete, and delete tasks that appear on the e-paper screen
- **Custom Messages** — send a message to the display with a 24-hour expiry
- **Device Status** — monitor the ESP32's connection and display health in real time

## Stack

- **Flutter** — mobile app (iOS & Android)
- **Firebase Realtime Database** — real-time sync bridge between phone and device
- **ESP32** — microcontroller driving the e-paper display
- **E-Paper Display** — low-power desk screen that renders the content

## Architecture

```
Phone (Flutter app)
       │
       ▼
Firebase Realtime DB  ──▶  ESP32  ──▶  E-Paper Display
```

The Flutter app writes to Firebase; the ESP32 polls Firebase and updates the display.

## Firebase Structure

```
esp32_desk_display/
├── todos/
│   ├── todo_1/  { text, completed, priority, createdAt }
│   └── todo_2/  ...
├── customMessage/  { message, sentAt, seen, active, expiresAt }
├── device_status/  { ... }
└── settings/       { ... }
```

## Setup

1. Clone the repo
2. Add your `lib/firebase_options.dart` (generated via FlutterFire CLI — not committed for security)
3. Run `flutter pub get`
4. Run the app: `flutter run`
