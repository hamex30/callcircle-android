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
text = re.sub(r'android:label="[^"]+"', 'android:label="CallCircle"', text, count=1)
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

# Allow discovery of user-installed launcher apps without QUERY_ALL_PACKAGES.
query_xml = '''    <queries>
        <intent>
            <action android:name="android.intent.action.MAIN"/>
            <category android:name="android.intent.category.LAUNCHER"/>
        </intent>
    </queries>
'''
if '<queries>' not in text:
    text = text.replace('    <application', query_xml + '    <application', 1)
manifest.write_text(text)
gradle = root / 'android/app/build.gradle.kts'
text = gradle.read_text()
text = text.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 36')
text = text.replace('minSdk = flutter.minSdkVersion', 'minSdk = 24')
# Restore the original application ID so this build targets the original CallCircle app.
# A matching signing certificate is also required for an in-place Android upgrade.
if 'isCoreLibraryDesugaringEnabled' not in text:
    text = text.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)
if 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs' not in text:
    text += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
gradle.write_text(text)

# Android native bridge for listing and launching installed apps. No special
# package-listing permission or automatic call initiation is required.
activity_file = root / 'android/app/src/main/kotlin/com/hamex/callcircle/MainActivity.kt'
activity_file.parent.mkdir(parents=True, exist_ok=True)
activity_file.write_text("""package com.hamex.callcircle

import android.content.Intent
import android.content.pm.ResolveInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    @Suppress("DEPRECATION")
    private fun launchableActivities(): List<ResolveInfo> {
        val lookup = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(lookup, 0)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "callcircle/app_launcher")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listApps" -> {
                        try {
                            val list = launchableActivities()
                                .filter { it.activityInfo.packageName != packageName }
                                .map { info ->
                                    mapOf(
                                        "name" to info.loadLabel(packageManager).toString(),
                                        "package" to info.activityInfo.packageName
                                    )
                                }
                                .distinctBy { it["package"] }
                                .sortedBy { it["name"]?.lowercase() }
                            result.success(list)
                        } catch (e: Exception) {
                            result.error("APPS_UNAVAILABLE", "Unable to list apps", null)
                        }
                    }
                    "launchApp" -> {
                        val target = call.argument<String>("package").orEmpty()
                        if (!target.contains(".") ||
                            target.any { !(it.isLetterOrDigit() || it == '.' || it == '_') }) {
                            result.success(false)
                        } else {
                            try {
                                val launcher = packageManager.getLaunchIntentForPackage(target)
                                    ?: launchableActivities()
                                        .firstOrNull { it.activityInfo.packageName == target }
                                        ?.let {
                                            Intent(Intent.ACTION_MAIN)
                                                .addCategory(Intent.CATEGORY_LAUNCHER)
                                                .setClassName(target, it.activityInfo.name)
                                        }
                                if (launcher == null) {
                                    result.success(false)
                                } else {
                                    launcher.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(launcher)
                                    result.success(true)
                                }
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
""")

print('AndroidManifest, Gradle and native app launcher configured.')