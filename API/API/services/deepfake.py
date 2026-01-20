from typing import Dict, Any
from DeepFake.detect import analyze, analyze_base64, analyze_streaming

def detect_from_bytes(audio_bytes: bytes) -> Dict[str, Any]:
    """Single audio analysis."""
    return analyze(audio_bytes)

def detect_from_base64(audio_base64: str) -> Dict[str, Any]:
    """Single audio analysis from base64."""
    return analyze_base64(audio_base64)

def detect_streaming_chunk(audio_bytes: bytes, session_id: str) -> Dict[str, Any]:
    """Streaming chunk analysis."""
    print("Analyzing streaming chunk2")
    return analyze_streaming(audio_bytes, session_id)
