# detect_test.py
import argparse
import json
from DeepFake.detect import analyze
from DeepFake.core.audio import load_audio_bytes

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test DeepFake analysis on a WAV file")
    parser.add_argument("--path", required=True, help="Path to audio file (WAV)")
    args = parser.parse_args()

    # Read audio bytes
    with open(args.path, "rb") as f:
        audio_bytes = f.read()

    result = analyze(audio_bytes)
    print(json.dumps(result, indent=2, ensure_ascii=False))

