# Community Todo (Quran Todo)

I built Community Todo as a lightweight Flutter app to manage personal and community todo items with Firebase-backed storage. It focuses on simple task creation, categorization, and optional sharing within a small group.

## Key Features
- Create, edit, and delete todo items
- Basic categorization and tags
- Offline-first behavior with Firestore syncing when online
- Email sign-in using Firebase Auth
- Local development using the Firebase Emulator Suite

## Quick Start (Development)

Prerequisites I use:
- Flutter SDK
- Firebase CLI (for emulator usage)
- A Firebase project for production builds

Local setup:
1. Install dependencies:
   - flutter pub get
2. Configure Firebase for local development:
   - I use the Firebase Emulator Suite for Firestore and Functions during development.
   - Generated platform config files (android/app/google-services.json, ios/GoogleService-Info.plist, lib/firebase_options.dart) are not committed; they are excluded via .gitignore.
3. Run the app:
   - flutter run

Notes:
- For production builds, follow the official Firebase setup to obtain platform configuration files and place them locally (do not add them to source control).
- This repository avoids embedding API keys, service account files, or app credentials. I manage secrets outside the repo and use environment/config management for CI and deployments.

## Contributing
- Fork the repository, create a feature branch, and open a pull request.
- Keep changes small and focused. I run tests and linting locally before submitting a PR.

## Troubleshooting
- If I encounter Firebase permission issues locally, I confirm the emulator is running with:
  - firebase emulators:start
- If the app is not pointing at emulators, I adjust the local configuration to connect to the emulator endpoints.

## License
Specify the project license here (for example, MIT) or remove this section.
