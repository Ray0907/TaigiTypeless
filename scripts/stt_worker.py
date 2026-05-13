#!/usr/bin/env python3
"""Persistent MLX STT worker for Taigi Typeless.

Protocol: newline-delimited JSON on stdin/stdout.

Startup stdout:
  {"event":"ready"}

Request stdin:
  {"id":"uuid", "audio":"/path/to.wav", "output_dir":"/tmp/...", "language":"zh", "max_tokens":512}

Response stdout:
  {"id":"uuid", "ok":true, "text":"..."}
  {"id":"uuid", "ok":false, "error":"..."}
"""

from __future__ import annotations

import argparse
import contextlib
import json
import os
import shutil
import sys
import tempfile
import traceback
from pathlib import Path
from typing import Any

from mlx_audio.stt.generate import generate_transcription
from mlx_audio.stt.utils import load_model


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Persistent MLX STT worker")
    parser.add_argument("--model", required=True, help="Path to MLX STT model")
    parser.add_argument("--language", default="zh", help="Default language code")
    parser.add_argument("--max-tokens", type=int, default=512, help="Default max generated tokens")
    parser.add_argument("--chunk-duration", type=float, default=30.0, help="Default chunk duration")
    return parser.parse_args()


def transcribe(model: Any, request: dict[str, Any], defaults: argparse.Namespace) -> str:
    audio = request.get("audio")
    if not audio or not isinstance(audio, str):
        raise ValueError("request must include an audio path string")
    if not Path(audio).exists():
        raise FileNotFoundError(audio)

    output_root = request.get("output_dir")
    cleanup_output = False
    if output_root and isinstance(output_root, str):
        os.makedirs(output_root, exist_ok=True)
    else:
        output_root = tempfile.mkdtemp(prefix="TaigiTypeless-worker-")
        cleanup_output = True

    output_path = os.path.join(output_root, f"transcript-{request.get('id', 'request')}")
    try:
        # Keep stdout reserved for the JSON protocol. mlx-audio may print warnings
        # even when verbose=False, so route library output to stderr.
        with contextlib.redirect_stdout(sys.stderr):
            segments = generate_transcription(
                model=model,
                audio=audio,
                output_path=output_path,
                format="json",
                verbose=False,
                language=request.get("language") or defaults.language,
                max_tokens=int(request.get("max_tokens") or defaults.max_tokens),
                chunk_duration=float(request.get("chunk_duration") or defaults.chunk_duration),
            )
        text = getattr(segments, "text", "") or ""
        return text.strip()
    finally:
        if cleanup_output:
            shutil.rmtree(output_root, ignore_errors=True)


def main() -> int:
    args = parse_args()
    log(f"Loading MLX STT model: {args.model}")
    # Keep stdout reserved for protocol messages while the model loader imports,
    # downloads, or prints diagnostics.
    with contextlib.redirect_stdout(sys.stderr):
        model = load_model(args.model)
    emit({"event": "ready"})

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            request_id = request.get("id")
            text = transcribe(model, request, args)
            emit({"id": request_id, "ok": True, "text": text})
        except Exception as error:  # keep the worker alive after bad requests
            emit({
                "id": locals().get("request", {}).get("id"),
                "ok": False,
                "error": str(error),
                "traceback": traceback.format_exc(limit=3),
            })
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
