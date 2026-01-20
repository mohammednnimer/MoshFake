from typing import Dict, Any

from DeepFake.core.audio import load_audio_bytes, decode_base64, rms_energy
from DeepFake.core.model import preload_model, get_classifier
from DeepFake.core.scoring import map_scores, make_decision, aggregate_scores
from DeepFake.core.session import update_session, get_aggregated

SILENCE_THRESHOLD = 0.005

def analyze(audio_bytes: bytes, target_sr: int = 16000) -> Dict[str, Any]:
    """
    Analyze audio bytes for deepfake detection.
    
    Args:
        audio_bytes: Raw audio bytes (WAV format)
        target_sr: Target sample rate
    
    Returns:
        {
            "bonafide_score": float,
            "spoof_score": float,
            "decision": str,
            "confidence": float,
            "energy": float,
            "is_silent": bool,
            "raw_labels": list
        }
    """
    print("Analyzing streaming chunk5")
    # Load and process audio
    y, sr = load_audio_bytes(audio_bytes, target_sr)
    
    print("Analyzing streaming chunk6")

    # Check energy
    energy = rms_energy(y)
    if energy < SILENCE_THRESHOLD:
        return {
            "bonafide_score": 0.0,
            "spoof_score": 0.0,
            "decision": "UNCERTAIN",
            "confidence": 0.0,
            "energy": round(energy, 6),
            "is_silent": True,
            "reason": "Audio energy too low (silence/noise)"
        }
    
    print("Analyzing streaming chunk7")

    
    # Run model
    clf = get_classifier()
    outputs = clf(y, sampling_rate=sr)
    print("Analyzing streaming chunk8")

    # Interpret scores

    try:
     print(f"Outputs: {outputs}")
     if isinstance(outputs, dict):
        bonafide_score = outputs.get('all_scores', {}).get('bonafide', 0)
        spoof_score = outputs.get('all_scores', {}).get('spoof', 0)
        decision_info = make_decision(bonafide_score, spoof_score)
     else:
        raise ValueError("Expected outputs to be a dictionary, but got a string instead.")
    except Exception as e:
      print(f"An error occurred: {e}")

    # try:
    #  print(f"Outputs: {outputs}")
    #  if isinstance(outputs, dict):
    #     bonafide_score, spoof_score = map_scores(outputs)
    #     decision_info = make_decision(bonafide_score, spoof_score)
    #  else:
    #     raise ValueError("Expected outputs to be a dictionary, but got a string instead.")
    # except Exception as e:
    #  print(f"An error occurred: {e}")






    bonafide_score, spoof_score = map_scores(outputs)
    decision_info = make_decision(bonafide_score, spoof_score)
    print("Analyzing streaming chunk9")

    return {
        "bonafide_score": round(bonafide_score, 4),
        "spoof_score": round(spoof_score, 4),
        "decision": decision_info["decision"],
        "confidence": decision_info["confidence"],
        "energy": round(energy, 6),
        "is_silent": False
    }

def analyze_base64(audio_base64: str, target_sr: int = 16000) -> Dict[str, Any]:
    """Analyze base64-encoded audio."""
    audio_bytes = decode_base64(audio_base64)
    return analyze(audio_bytes, target_sr)

def analyze_streaming(
    audio_bytes: bytes,
    session_id: str,
    target_sr: int = 16000
) -> Dict[str, Any]:
    """
    Analyze audio chunk in streaming context.
    
    Returns:
        {
            "chunk": {...},      # This chunk's analysis
            "aggregated": {...}  # Rolling average decision
        }
    """
    print("Analyzing streaming chunk3")
    chunk_result = analyze(audio_bytes, target_sr)
    print("Analyzing streaming chunk5")
    # Don't add silent chunks to aggregation
    if chunk_result.get("is_silent"):
        return {
            "chunk": chunk_result,
            "aggregated": get_aggregated(session_id)
        }
    
    # Update session with this chunk's scores
    aggregated = update_session(
        session_id,
        chunk_result["bonafide_score"],
        chunk_result["spoof_score"]
    )
    
    return {
        "chunk": chunk_result,
        "aggregated": aggregated
    }


__all__ = ["analyze", "analyze_base64", "analyze_streaming", "preload_model"]
