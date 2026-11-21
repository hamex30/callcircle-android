# CallCircle — Android prototype

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