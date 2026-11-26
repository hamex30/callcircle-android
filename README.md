# CallCircle v0.4.0 — imo + Other calling app

- **imo** is now a per-person calling option. CallCircle opens the installed official imo app, but does not start a voice call automatically.
- **Other installed app** lets you select an installed calling app for each person. The selected app name and Android package identifier are stored with that contact, and choosing Call opens the app. Use its own interface to place the call. You can edit or change the app later.
- Both manual contact entry and bulk phone-contact import support these options.
- Existing CallCircle contacts, notes, last-called dates, reminders, and other saved calling preferences remain unchanged.
- The Android app uses the same application ID and GitHub Actions permanent release signing key as v0.3.x for an in-place upgrade.
- Launcher-app discovery is limited to apps with launchable Android activities. It does not require QUERY_ALL_PACKAGES or uploading a list of installed apps.
- If imo is not installed, install the official imo app from Google Play (package `com.imo.android.imoim`). The app does not rely on an unverified imo direct-call URL.
- When a custom app opens, CallCircle copies the saved number to clipboard for convenient pasting into the calling app.

# CallCircle v2.1 — Phone contact picker

- Choose from your Samsung phone contacts on the home screen **or directly from the Add someone form**.
- Select one or multiple contacts and assign a frequency.
- Uses original Android application ID `com.hamex.callcircle` and version `0.3.0+3`.
- **Important:** An in-place update also requires the same signing key. The original builds were created with default temporary debug signing in CI. If Android rejects an in-place update due to a signing mismatch, export a backup from the original app BEFORE removing it; then reinstall and restore the backup. Do not assume changing an app ID alone preserves data.
- Phone contacts are requested on demand and not transmitted to a server. Only selected entries are saved to CallCircle's app storage.

# CallCircle v2 — Android prototype

A private call reminder app, created for an Android phone. Source for a Flutter Android wrapper around the included mobile UI.

## Features
- Weekly (next Monday), biweekly (Monday two weeks later), and monthly (first day of next month) contacts
- Ramadan, Eid al-Fitr and Eid al-Adha lists, without automatic reminders
- Due now, all contacts, and occasions tabs; add, edit and delete contacts
- Mark called, move reminder to tomorrow, last-called dates
- Open WhatsApp chat (then tap voice call), launch phone dialer
- White Calling: copy phone number and open its Google Play listing; direct dialling inside White Calling is **not** integrated
- Contacts persisted locally, plus JSON export and import
- Android native **one combined notification at 10 AM** on days contacts are due, scheduled for the upcoming 90 days; rescheduled when contacts change and when the app opens

## Limitations
This is an **untested source project**, not a verified installable APK. A cloud build is included, but it has not been run yet. A 90-day scheduling horizon means opening the app at least once every 90 days to keep notifications current. Android notification permission, exact alarms and battery optimisations can affect delivery time. Any time-zone changes should be followed by opening the app. It does not automatically detect completed WhatsApp or White Calling calls.

## Build without a computer
1. Upload this repository's files and folders to a new GitHub repository (GitHub Codespaces in a mobile browser can unpack the supplied ZIP and push it).
2. Run **Actions → Build CallCircle Android APK → Run workflow**, or push to the main branch.
3. After a successful workflow, open the run and download the **CallCircle-Android-APK** artifact onto your Android phone.
4. Unzip the downloaded artifact and install `app-release.apk`, allowing installation from your browser/file manager if prompted.

The workflow uses `flutter create` to generate platform files and then runs `tool/prepare_android.py` to configure notifications and Gradle. Flutter release builds made this way are typically signed with a debug/test key from the generated project and are not a production-ready Play Store release. Use a proper release signing key for permanent distribution.

## Development
Flutter 3.50 or newer recommended, Java 17 and Android SDK 36. Run:

```
flutter create --platforms=android --project-name=callcircle --org=com.hamex .
python3 tool/prepare_android.py
flutter pub get
flutter run
```

## Privacy
Contact records remain on the phone in app preferences/WebView storage and are exported only on user request. No online account, analytics or server is used. WhatsApp and White Calling links launch external services.


## Version 2: Import people from Samsung/Android contacts

Tap **Choose from phone contacts**, approve the one-time **read contacts** permission,
search and tick multiple people, choose the appropriate number if someone has
several, then tap **Continue**. Select a starting frequency, relationship and
calling method for the imported group. Edit individual people afterward.

Only selected names, phone numbers and contact IDs are saved inside CallCircle;
the app does not upload your address book. It asks only for READ_CONTACTS and
never alters your phone's address book. Re-importing the same phone contact or
number skips duplicates. Denying permission leaves manual entry available.

Version 2 has a separate Android package ID (`com.hamex.callcircle2`) and label
(`CallCircle v2`) to avoid overwriting or deleting Version 1's locally stored
contacts. You can keep both prototypes installed. Existing Version 1 data is
not automatically migrated; if needed, restore a CallCircle backup in v2.

These are test builds; they are not configured with a stable production signing
key. For reliable future in-place updates, configure a private release keystore
using GitHub Actions secrets before distributing the app.

## Permanent Android release signing

For every future build, add two GitHub repository Actions secrets:
- `CALLCIRCLE_KEYSTORE_BASE64`: Base64 encoding of your private `callcircle-release.jks`
- `CALLCIRCLE_STORE_PASSWORD`: The signing keystore password (also used as the key password)

The key alias is `callcircle`. The keystore file, its Base64 encoding, and its password must NEVER be committed to this public repository. Keep an encrypted private backup of the keystore and password. When these secrets are missing, the CI build intentionally fails rather than shipping an APK with a temporary signing certificate.

**First-time migration:** The earlier CallCircle APKs were signed using an ephemeral debug signing key. Android cannot update those APKs with a new permanent signing key. Export and verify contacts backup, then uninstall the old app and install the first permanently signed version once. Thereafter, future releases built with this same key and same application ID will update without reinstalling (provided versionCode is increased).
