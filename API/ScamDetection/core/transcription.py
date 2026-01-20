import whisper
from typing import Dict, Any
import numpy as np

_whisper_model = None

def get_whisper_model(model_size: str = "base"):
    """Lazy load Whisper model."""
    global _whisper_model
    if _whisper_model is None:
        print(f"Loading Whisper {model_size} model...")
        _whisper_model = whisper.load_model(model_size)
        print("Whisper model loaded!")
    return _whisper_model

def transcribe_audio(y: np.ndarray, sr: int = 16000) -> Dict[str, Any]:
    """
    Transcribe audio to text using Whisper.
    
    Args:
        y: Audio array
        sr: Sample rate
    
    Returns:
        {
            "text": str,
            "language": str,
            "segments": list
        }
    """
    model = get_whisper_model()
    
    # Whisper expects float32 audio
    if y.dtype != np.float32:
        y = y.astype(np.float32)
    
    # Transcribe
    result = model.transcribe(
        y,
        language="en",  # Set to None for auto-detection
        task="transcribe",
        verbose=False
    )
    
    return {
        "text": result.get("text", "").strip(),
        "language": result.get("language", "unknown"),
        "segments": result.get("segments", [])
    }

def preload_whisper():
    """Preload Whisper model at startup."""
    get_whisper_model()
