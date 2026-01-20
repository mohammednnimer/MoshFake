from typing import Dict, Any
from ScamDetection.detect import analyze, analyze_streaming

def detect_scam(audio_bytes: bytes) -> Dict[str, Any]:
    """Single audio scam analysis."""
    return analyze(audio_bytes)

def detect_scam_streaming(audio_bytes: bytes, session_id: str) -> Dict[str, Any]:
    """Streaming scam detection."""
    return analyze_streaming(audio_bytes, session_id)
