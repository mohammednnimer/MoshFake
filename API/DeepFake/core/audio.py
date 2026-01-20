import io
import base64
import binascii
import numpy as np
import librosa
import soundfile as sf
from typing import Tuple

def load_audio_bytes(audio_bytes: bytes, target_sr: int = 16000) -> Tuple[np.ndarray, int]:
    """Read WAV bytes, convert to mono float32, resample to target_sr."""
    with io.BytesIO(audio_bytes) as bio:
        y, sr = sf.read(bio, dtype="float32", always_2d=False)

    if isinstance(y, np.ndarray) and y.ndim == 2:
        y = np.mean(y, axis=1)

    y = np.asarray(y, dtype=np.float32).flatten()

    if sr != target_sr:
        y = librosa.resample(y, orig_sr=sr, target_sr=target_sr)
        sr = target_sr

    return y, sr

def decode_base64(b64_str: str) -> bytes:
    """Accept raw base64 or data URL."""
    if "," in b64_str and b64_str.strip().lower().startswith("data:"):
        b64_str = b64_str.split(",", 1)[1]
    b64_str = "".join(b64_str.split())
    try:
        return base64.b64decode(b64_str, validate=True)
    except (binascii.Error, ValueError) as e:
        raise ValueError(f"Invalid base64 payload: {e}")

def rms_energy(y: np.ndarray) -> float:
    """Calculate RMS energy to detect silence."""
    if y.size == 0:
        return 0.0
    return float(np.sqrt(np.mean(np.square(y), dtype=np.float64)))
