#!/bin/bash
# Build Android only with the upstream Swift/Skip/Qt toolchain on macOS.
set -euo pipefail
aria_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$aria_root"
mkdir -p .local release
: "${ARIA_BUILD_PYTHON:?Set ARIA_BUILD_PYTHON to Python 3.10}"
: "${QT_ANDROID:?Set QT_ANDROID to Qt 6.11.1 android_arm64_v8a}"
: "${QT_HOST:?Set QT_HOST to the matching Qt 6.11.1 macOS host}"
: "${ANDROID_SDK_ROOT:?Set ANDROID_SDK_ROOT}"
for tool in swift skip cmake ninja gradle; do
    command -v "$tool" >/dev/null || { echo "Missing build tool: $tool" >&2; exit 1; }
done
"$ARIA_BUILD_PYTHON" -c 'import sys; assert sys.version_info[:2] == (3,10), "Python 3.10 is required for Android OpenCV"'
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$aria_root/.local/gradle-home}"
export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$ANDROID_SDK_ROOT/ndk/27.2.12479018}"
export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-2}"
python3 extensions/omr/prepare_models.py .local/staged-assets
git lfs pull --include=MuseReaderiOS/MuseReaderiOS/Resources/MuseScore_General.sf2
bash MuseReaderAndroid/scripts/link-ios-sources.sh
if [ ! -f build-aria-android-arm64/libMuseScoreRenderCore.a ]; then
    bash MuseReaderAndroid/scripts/build-render-core.sh
fi
if [ ! -f build-aria-android-arm64/jniLibs/arm64-v8a/libaria_engine.so ]; then
    bash MuseReaderAndroid/scripts/build-engine.sh
fi
cd MuseReaderAndroid/Aria/Android
export SKIP_COMMAND_OVERRIDE="$aria_root/MuseReaderAndroid/scripts/skip-arm64-only.sh"
trap 'gradle --stop >/dev/null 2>&1 || true' EXIT
gradle :app:assembleDebug --no-daemon --max-workers=2
aria_apk="$aria_root/MuseReaderAndroid/Aria/.build/Android/app/outputs/apk/debug/app-debug.apk"
test -s "$aria_apk"
cp "$aria_apk" "$aria_root/release/Aria-MuseTab-android-debug.apk"
shasum -a 256 "$aria_root/release/Aria-MuseTab-android-debug.apk" > "$aria_root/release/SHA256SUMS.txt"
