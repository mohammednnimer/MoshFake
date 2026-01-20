import io
import numpy as np
import librosa
import soundfile as sf
from typing import Dict, Any, Tuple

def load_audio_from_bytes(audio_bytes: bytes, target_sr: int = 16000) -> Tuple[np.ndarray, int]:
    """
    Load audio from bytes (WAV, MP3, etc.) and convert to numpy array.
    
    Args:
        audio_bytes: Raw audio bytes
        target_sr: Target sample rate
    
    Returns:
        (audio_array, sample_rate)
    """
    with io.BytesIO(audio_bytes) as bio:
        try:
            # Try soundfile first (works for WAV)
            y, sr = sf.read(bio, dtype="float32", always_2d=False)
        except Exception:
            # Fallback to librosa for other formats
            bio.seek(0)
            y, sr = librosa.load(bio, sr=None, mono=True)
    
    # Ensure mono
    if isinstance(y, np.ndarray) and y.ndim == 2:
        y = np.mean(y, axis=1)
    
    y = np.asarray(y, dtype=np.float32).flatten()
    
    # Ensure sr is int
    sr = int(sr)
    
    # Resample if needed
    if sr != target_sr:
        y = librosa.resample(y, orig_sr=sr, target_sr=target_sr)
        sr = target_sr
    
    return y, sr

def extract_audio_features(y: np.ndarray, sr: int) -> Dict[str, Any]:
    """
    Extract comprehensive audio features for scam detection.
    
    Features extracted:
    - Energy/RMS (loudness)
    - Pitch statistics (mean, std, range)
    - Speech rate estimation
    - Zero crossing rate (voice quality)
    - Spectral features (clarity, distortion)
    - Pause detection
    """
    features = {}
    
    # 1. Energy features
    rms = librosa.feature.rms(y=y)[0]
    features["energy_mean"] = float(np.mean(rms))
    features["energy_std"] = float(np.std(rms))
    features["energy_max"] = float(np.max(rms))
    
    # 2. Pitch features (fundamental frequency)
    pitches, magnitudes = librosa.piptrack(y=y, sr=sr, fmin=75, fmax=400)
    pitch_values = []
    for t in range(pitches.shape[1]):
        index = magnitudes[:, t].argmax()
        pitch = pitches[index, t]
        if pitch > 0:
            pitch_values.append(pitch)
    
    if pitch_values:
        features["pitch_mean"] = float(np.mean(pitch_values))
        features["pitch_std"] = float(np.std(pitch_values))
        features["pitch_range"] = float(np.max(pitch_values) - np.min(pitch_values))
    else:
        features["pitch_mean"] = 0.0
        features["pitch_std"] = 0.0
        features["pitch_range"] = 0.0
    
    # 3. Zero crossing rate (voice naturalness)
    zcr = librosa.feature.zero_crossing_rate(y)[0]
    features["zcr_mean"] = float(np.mean(zcr))
    features["zcr_std"] = float(np.std(zcr))
    
    # 4. Spectral features
    spectral_centroids = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
    spectral_rolloff = librosa.feature.spectral_rolloff(y=y, sr=sr)[0]
    
    features["spectral_centroid_mean"] = float(np.mean(spectral_centroids))
    features["spectral_rolloff_mean"] = float(np.mean(spectral_rolloff))
    
    # 5. MFCCs (voice characteristics)
    mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    features["mfcc_mean"] = float(np.mean(mfccs))
    features["mfcc_std"] = float(np.std(mfccs))
    
    # 6. Duration and speech rate
    duration = len(y) / sr
    features["duration"] = float(duration)
    
    # Estimate speech rate using onset detection
    onset_frames = librosa.onset.onset_detect(y=y, sr=sr)
    features["speech_rate"] = len(onset_frames) / duration if duration > 0 else 0
    
    # 7. Pause detection (silence ratio)
    silence_threshold = 0.01
    silent_frames = np.sum(rms < silence_threshold)
    total_frames = len(rms)
    features["silence_ratio"] = float(silent_frames / total_frames) if total_frames > 0 else 0
    
    return features

def detect_ai_voice_indicators(features: Dict[str, Any]) -> Dict[str, Any]:
    """
    Analyze audio features for AI-generated voice indicators.
    
    AI voices often have:
    - Unnaturally consistent pitch
    - Lower pitch variation
    - Unusual spectral characteristics
    - Lack of natural breathing/pauses
    """
    indicators = {
        "is_likely_ai": False,
        "confidence": 0.0,
        "flags": []
    }
    
    score = 0
    
    # 1. Unnaturally low pitch variation
    if features["pitch_std"] < 20:
        score += 25
        indicators["flags"].append("low_pitch_variation")
    
    # 2. Very consistent energy (no natural breathing)
    if features["energy_std"] < 0.02:
        score += 20
        indicators["flags"].append("consistent_energy")
    
    # 3. Unusual silence ratio (AI often has perfect timing)
    if features["silence_ratio"] < 0.05 or features["silence_ratio"] > 0.4:
        score += 15
        indicators["flags"].append("unusual_pauses")
    
    # 4. Spectral anomalies
    if features["spectral_centroid_mean"] > 3000 or features["spectral_centroid_mean"] < 500:
        score += 20
        indicators["flags"].append("spectral_anomaly")
    
    # 5. Unnatural speech rate
    if features["speech_rate"] < 1 or features["speech_rate"] > 10:
        score += 20
        indicators["flags"].append("unusual_speech_rate")
    
    indicators["confidence"] = min(score, 100) / 100.0
    indicators["is_likely_ai"] = score >= 40
    
    return indicators

def is_silent(y: np.ndarray, threshold: float = 0.005) -> bool:
    """Check if audio is effectively silent."""
    if y.size == 0:
        return True
    rms = np.sqrt(np.mean(np.square(y)))
    return rms < threshold
