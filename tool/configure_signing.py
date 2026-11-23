"""Configure permanent Android release signing from GitHub Actions secrets."""
import base64
import binascii
import os
from pathlib import Path
import subprocess
import sys

def fail(message):
    print("::error::" + message)
    sys.exit(2)

root = Path(__file__).resolve().parents[1]
password = os.environ.get("CALLCIRCLE_STORE_PASSWORD", "").strip()
encoded = os.environ.get("CALLCIRCLE_KEYSTORE_BASE64", "").strip()
if not password or not encoded:
    fail("Missing repository secrets. Add CALLCIRCLE_KEYSTORE_BASE64 and CALLCIRCLE_STORE_PASSWORD in GitHub Settings > Secrets and variables > Actions.")
try:
    keybytes = base64.b64decode("".join(encoded.split()), validate=True)
except (ValueError, binascii.Error):
    fail("The keystore Base64 secret is invalid.")
if not 128 <= len(keybytes) <= 100000:
    fail("The keystore has an unexpected size.")
keyfile = root / "android/app/callcircle-release.jks"
keyfile.parent.mkdir(parents=True, exist_ok=True)
keyfile.write_bytes(keybytes)
keyfile.chmod(0o600)
check = subprocess.run(
    ["keytool", "-list", "-keystore", str(keyfile),
     "-storepass", password, "-alias", "callcircle"],
    capture_output=True, text=True,
)
if check.returncode != 0:
    keyfile.unlink(missing_ok=True)
    fail("Signing key verification failed. Check both GitHub secrets.")
gradle = root / "android/app/build.gradle.kts"
if not gradle.exists():
    fail("Android Gradle configuration not found.")
text = gradle.read_text()
anchor = "    buildTypes {"
old = 'signingConfig = signingConfigs.getByName("debug")'
if anchor not in text or old not in text:
    fail("Unexpected Flutter Gradle template; refusing to use a debug key.")
config = """    signingConfigs {
        create("release") {
            storeFile = file("callcircle-release.jks")
            storePassword = System.getenv("CALLCIRCLE_STORE_PASSWORD")
            keyAlias = "callcircle"
            keyPassword = System.getenv("CALLCIRCLE_STORE_PASSWORD")
        }
    }
"""
text = text.replace(anchor, config + anchor, 1)
text = text.replace(old, 'signingConfig = signingConfigs.getByName("release")', 1)
gradle.write_text(text)
print("Permanent signing key verified and release signing configured.")
