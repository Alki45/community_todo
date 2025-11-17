# Community Quran Todo

Flutter + Firebase application for organising Qur’an recitation groups with shared assignments, announcements, and real-time progress tracking.

## Prerequisites

- Flutter `>=3.19`
- Firebase project with Firestore, Authentication, Cloud Messaging
- Google services configuration files in `android/` and `ios/` folders
- Node 18+ for Firebase Functions

## Running the App

```bash
flutter pub get
flutter run
```

## Firebase Functions

Deploy once Firestore rules and environment variables are ready:

```bash
cd functions
npm install
firebase deploy --only functions
```

## Seed Sample Data

The Functions bundle exposes a guarded HTTPS endpoint to populate Firestore with sample users, groups, announcements, and assignments.

1. Set a seed token (run once):

   ```bash
   firebase functions:config:set seed.token="replace-with-strong-token"
   firebase deploy --only functions
   ```

   > Alternatively, set the `SEED_TOKEN` environment variable before running the emulator.

2. Invoke the seeding endpoint (POST request):

   ```bash
   curl -X POST \
     -H "x-seed-token: replace-with-strong-token" \
     https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/seedSampleData
   ```

   When using the local emulator:

   ```bash
   curl -X POST \
     -H "x-seed-token: replace-with-strong-token" \
     http://127.0.0.1:5001/YOUR_PROJECT_ID/us-central1/seedSampleData
   ```

The script inserts:

- One group named **Astu Muslim Community** (`ASTU24` invite code)
- Six sample users (admin + 5 members) with `activeGroupId` preset
- Announcements and recitation assignments that cover multiple Juz numbers

Feel free to adjust the data in `functions/index.js` before calling the endpoint. Use only in non-production environments.

### Sample Credentials

The seed script also provisions Firebase Auth accounts (password: `AstU2024!`).

| Email               | Display Name        | Role        |
| ------------------- | ------------------- | ----------- |
| aminah@example.com  | Aminah Saleh        | Admin       |
| yusuf@example.com   | Yusuf Hamdan        | Member      |
| khadija@example.com | Khadija Rahman      | Member      |
| mohamed@example.com | Mohamed Idris       | Member      |
| samira@example.com  | Samira Bekele       | Member      |
| najma@example.com   | Najma Ali           | Member      |

Sign in with any of these accounts (password `AstU2024!`) to exercise the full workflow in web or mobile builds.
