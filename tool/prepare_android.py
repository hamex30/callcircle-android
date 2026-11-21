"""Patch Flutter-generated Android project for CallCircle on CI."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
manifest = root / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text()
for permission in ['android.permission.INTERNET', 'android.permission.READ_CONTACTS', 'android.permission.POST_NOTIFICATIONS', 'android.permission.RECEIVE_BOOT_COMPLETED', 'android.permission.SCHEDULE_EXACT_ALARM']:
    if permission not in text:
        text = text.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
                            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="'+permission+'"/>')
text = re.sub(r'android:label="[^"]+"', 'android:label="CallCircle v2"', text, count=1)
receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''
if 'ScheduledNotificationReceiver' not in text:
    text = text.replace('</application>', receivers+'    </application>')
manifest.write_text(text)
gradle = root / 'android/app/build.gradle.kts'
text = gradle.read_text()
text = text.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 36')
text = text.replace('minSdk = flutter.minSdkVersion', 'minSdk = 24')
# Version 2 installs separately from the old prototype, so existing local data is safe.
text = text.replace('applicationId = "com.hamex.callcircle"', 'applicationId = "com.hamex.callcircle2"')
if 'isCoreLibraryDesugaringEnabled' not in text:
    text = text.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)
if 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs' not in text:
    text += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
gradle.write_text(text)
print('AndroidManifest + Gradle configured.')