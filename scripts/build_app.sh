#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT/.." && pwd)"
APP="$ROOT/.build/TaigiTypeless.app"
EXECUTABLE="$ROOT/.build/release/TaigiTypeless"
PYTHON_PATH="$WORKSPACE_ROOT/.venv/bin/python"
MODEL_PATH="$WORKSPACE_ROOT/Breeze-ASR-26-mlx-4bit"
WORKDIR="/tmp/TaigiTypeless"
SIGNING_IDENTITY="${TAIGI_TYPELESS_SIGNING_IDENTITY:-Apple Development: asghdf123@hotmail.com (SZ6R94C744)}"

if [[ ! -x "$PYTHON_PATH" ]]; then
  echo "Missing Python runtime at $PYTHON_PATH" >&2
  exit 1
fi

if [[ ! -d "$MODEL_PATH" ]]; then
  echo "Missing MLX model at $MODEL_PATH" >&2
  exit 1
fi

cd "$ROOT"
SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/module-cache" \
CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-module-cache" \
swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXECUTABLE" "$APP/Contents/MacOS/TaigiTypeless"
cp "$ROOT/scripts/stt_worker.py" "$APP/Contents/Resources/stt_worker.py"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>TaigiTypeless</string>
  <key>CFBundleIdentifier</key>
  <string>com.rayytien.taigitypeless</string>
  <key>CFBundleName</key>
  <string>Taigi Typeless</string>
  <key>CFBundleDisplayName</key>
  <string>Taigi Typeless</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Taigi Typeless records your voice locally to transcribe Taiwanese Hokkien with the bundled MLX model.</string>
</dict>
</plist>
PLIST

cat > "$APP/Contents/Resources/config.json" <<JSON
{
  "pythonPath": "$PYTHON_PATH",
  "modelPath": "$MODEL_PATH",
  "workingDirectory": "$WORKDIR",
  "language": "zh",
  "maxTokens": 512
}
JSON

if security find-identity -v -p codesigning | grep -Fq "$SIGNING_IDENTITY"; then
  codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP"
else
  echo "Warning: code signing identity not found, leaving app ad-hoc signed: $SIGNING_IDENTITY" >&2
fi

echo "Built $APP"
