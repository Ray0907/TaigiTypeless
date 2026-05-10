# Taigi Typeless

Offline Taiwanese Hokkien voice input for macOS. Taigi Typeless is a menu bar app that records speech with a global hotkey, transcribes locally with an MLX Whisper model, cleans the text, and pastes it into the currently focused input.

The app is designed around the first important UX loop:

```text
Option-Space -> speak Taigi -> Option-Space -> local ASR -> paste into any input
```

The ASR model is hosted separately on Hugging Face:

[RayyTien/Breeze-ASR-26-mlx-4bit](https://huggingface.co/RayyTien/Breeze-ASR-26-mlx-4bit)

## Features

- Menu bar app with a visible `Taigi` status item.
- Floating status window with transcription state, Accessibility status, and the latest result.
- Global hotkey: `Option-Space`.
- Works across normal macOS text inputs by pasting through the clipboard.
- Copies the transcription to the clipboard when automatic paste is not available.
- Fully offline transcription once the model is downloaded.
- Uses Apple Silicon MLX through `mlx-audio`.
- Prompts for Microphone and Accessibility permissions.

## Requirements

- Apple Silicon Mac.
- macOS 14 or newer.
- Swift 6 toolchain.
- Python 3.11.
- `mlx-audio`.
- The 4-bit MLX model from Hugging Face.

This first build targets 16GB Mac M4-class machines.

## Getting Started

Create a parent workspace, then clone this repository and place the Python runtime and model beside it:

```bash
mkdir -p workspace
cd workspace
git clone https://github.com/Ray0907/TaigiTypeless.git
```

```text
workspace/
  TaigiTypeless/
  .venv/
  Breeze-ASR-26-mlx-4bit/
```

Example setup:

```bash
cd workspace
python3.11 -m venv .venv
./.venv/bin/python -m pip install -U pip mlx-audio huggingface_hub hf_transfer
./.venv/bin/hf download RayyTien/Breeze-ASR-26-mlx-4bit \
  --local-dir Breeze-ASR-26-mlx-4bit
```

Build and launch the app:

```bash
cd TaigiTypeless
./scripts/build_app.sh
open .build/TaigiTypeless.app
```

On first launch, grant:

- Microphone permission, so the app can record speech.
- Accessibility permission, so it can paste into the currently focused app.

If Accessibility does not appear automatically, open:

```text
System Settings -> Privacy & Security -> Accessibility
```

Then enable `Taigi Typeless` and restart the app.

If your paths differ, set these environment variables before launching from Terminal:

```bash
export TAIGI_TYPELESS_PYTHON=/absolute/path/to/.venv/bin/python
export TAIGI_TYPELESS_MODEL=/absolute/path/to/Breeze-ASR-26-mlx-4bit
```

## Build

From this folder:

```bash
./scripts/build_app.sh
```

The app bundle is created at:

```text
.build/TaigiTypeless.app
```

The build script writes absolute paths for Python and the model into:

```text
.build/TaigiTypeless.app/Contents/Resources/config.json
```

That lets the app launch from Finder without relying on shell environment variables.

## Run

Open the app bundle:

```bash
open .build/TaigiTypeless.app
```

## Usage

1. Put your cursor in any text input.
2. Press `Option-Space`.
3. Speak Taigi.
4. Press `Option-Space` again.
5. Watch the `Taigi` menu bar item or the status window while local recognition runs.

The transcription is pasted into the focused input when Accessibility is available. If automatic paste fails, the transcription is copied to the clipboard and shown in the status window's `Last result` field, so you can press `Command-V` manually.

## Current Limitations

- This is a local developer build, not a notarized release.
- The app uses clipboard paste for maximum input compatibility.
- Cloud polishing, custom dictionaries, and a full settings UI are intentionally deferred.
- The app currently outputs the model's Mandarin-character transcription behavior.

## Development

Use English for commit messages, code comments, and developer-facing documentation.

Run tests:

```bash
SWIFTPM_MODULECACHE_OVERRIDE=$(pwd)/.build/module-cache \
CLANG_MODULE_CACHE_PATH=$(pwd)/.build/clang-module-cache \
swift test
```
