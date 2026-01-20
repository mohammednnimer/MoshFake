from typing import Dict, Any

from .core.audio_processor import (
    load_audio_from_bytes,
    extract_audio_features,
    detect_ai_voice_indicators,
    is_silent
)
from .core.transcription import transcribe_audio, preload_whisper
from .core.sentiment import (
    analyze_sentiment,
    analyze_emotion,
    detect_urgency,
    preload_models as preload_nlp
)
from .core.scam_detector import (
    analyze_keywords,
    detect_scam_patterns,
    calculate_scam_score,
    detect_vishing_intent
)
from .core.sessions import update_session, get_session, aggregate_session

def analyze(audio_bytes: bytes) -> Dict[str, Any]:
    """
    Comprehensive scam detection from audio bytes.
    
    Args:
        audio_bytes: Raw audio bytes (any format supported by librosa)
    
    Returns:
        Complete analysis including transcription, sentiment, and scam detection
    """
    # 1. Load and process audio
    y, sr = load_audio_from_bytes(audio_bytes)
    
    # Check if silent
    if is_silent(y):
        return {
            "is_silent": True,
            "is_scam": False,
            "confidence": 0.0,
            "transcription": "",
            "reason": "Audio is silent or too quiet"
        }
    
    # 2. Extract audio features
    audio_features = extract_audio_features(y, sr)
    ai_indicators = detect_ai_voice_indicators(audio_features)
    
    # 3. Transcribe audio
    transcription_result = transcribe_audio(y, sr)
    text = transcription_result["text"]
    
    if not text or len(text.strip()) < 3:
        return {
            "is_silent": False,
            "is_scam": False,
            "confidence": 0.0,
            "transcription": "",
            "audio_features": audio_features,
            "ai_voice": ai_indicators,
            "reason": "No speech detected in audio"
        }
    
    # 4. NLP Analysis
    sentiment = analyze_sentiment(text)
    emotions = analyze_emotion(text)
    urgency = detect_urgency(text)
    intent_analysis = detect_vishing_intent(text)
    
    # 5. Scam Detection
    keyword_analysis = analyze_keywords(text)
    pattern_analysis = detect_scam_patterns(text)

    scam_result = calculate_scam_score(
    keyword_analysis,
    pattern_analysis,
    intent_analysis,
    sentiment,
    urgency,
    audio_features,
    ai_indicators
)
    
    return {
        "is_silent": False,
        "is_scam": scam_result["is_scam"],
        "confidence": scam_result["confidence"],
        "risk_level": scam_result["risk_level"],
        "score": scam_result["score"],
        "flags": scam_result["flags"],
        "score_breakdown": scam_result["score_breakdown"],
        
        "transcription": {
            "text": text,
            "language": transcription_result["language"],
            "word_count": len(text.split())
        },
        
        "sentiment_analysis": {
            "sentiment": sentiment["label"],
            "sentiment_score": sentiment["score"],
            "emotions": emotions,
            "urgency": urgency
        },
        
        "scam_indicators": {
            "keywords": keyword_analysis,
            "patterns": pattern_analysis
        },
        
        "audio_analysis": {
            "features": audio_features,
            "ai_voice_detection": ai_indicators
        }
    }

def analyze_streaming(audio_bytes: bytes, session_id: str) -> Dict[str, Any]:
    """
    Analyze audio chunk in streaming context.
    
    Returns both chunk analysis and aggregated session results.
    """
    chunk_result = analyze(audio_bytes)
    
    if chunk_result.get("is_silent") or not chunk_result.get("transcription", {}).get("text"):
        sess = get_session(session_id)
        return {
            "chunk": chunk_result,
            "session": aggregate_session(sess)
        }
    
    # Update session
    session_result = update_session(
        session_id,
        chunk_result["transcription"]["text"],
        chunk_result["score"],
        chunk_result
    )
    
    return {
        "chunk": chunk_result,
        "session": session_result
    }

def preload_models():
    """Preload all models at startup."""
    preload_whisper()
    preload_nlp()

__all__ = ["analyze", "analyze_streaming", "preload_models"]
