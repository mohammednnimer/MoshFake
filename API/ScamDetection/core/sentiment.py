from transformers import pipeline
from typing import Dict, Any, List
import re

_sentiment_analyzer = None
_emotion_analyzer = None

def get_sentiment_analyzer():
    """Lazy load sentiment analysis model."""
    global _sentiment_analyzer
    if _sentiment_analyzer is None:
        print("Loading sentiment analyzer...")
        _sentiment_analyzer = pipeline(
            "sentiment-analysis",
            model="distilbert-base-uncased-finetuned-sst-2-english",
            device=-1  # CPU
        )
        print("Sentiment analyzer loaded!")
    return _sentiment_analyzer

def get_emotion_analyzer():
    """Lazy load emotion detection model."""
    global _emotion_analyzer
    if _emotion_analyzer is None:
        print("Loading emotion analyzer...")
        try:
            _emotion_analyzer = pipeline(
                "text-classification",
                model="j-hartmann/emotion-english-distilroberta-base",
                device=-1,
                top_k=None
            )
            print("Emotion analyzer loaded!")
        except Exception as e:
            print(f"Could not load emotion analyzer: {e}")
            _emotion_analyzer = None
    return _emotion_analyzer

def analyze_sentiment(text: str) -> Dict[str, Any]:
    """Analyze sentiment of text."""
    if not text or len(text.strip()) < 3:
        return {
            "label": "NEUTRAL",
            "score": 0.0
        }
    
    analyzer = get_sentiment_analyzer()
    result = analyzer(text[:512])[0]  # Limit to 512 chars
    
    return {
        "label": result["label"],
        "score": float(result["score"])
    }

def analyze_emotion(text: str) -> List[Dict[str, Any]]:
    """Analyze emotions in text."""
    if not text or len(text.strip()) < 3:
        return []
    
    analyzer = get_emotion_analyzer()
    if analyzer is None:
        return []
    
    try:
        results = analyzer(text[:512])[0]
        return sorted(results, key=lambda x: x["score"], reverse=True)[:3]
    except Exception:
        return []

def detect_urgency(text: str) -> Dict[str, Any]:
    """Detect urgency indicators in text."""
    text_lower = text.lower()
    
    urgency_patterns = [
        r'\b(urgent|emergency|immediately|right now|asap|hurry)\b',
        r'\b(act now|limited time|expires|deadline)\b',
        r'\b(quick|fast|don\'t wait|time sensitive)\b'
    ]
    
    urgency_count = 0
    found_phrases = []
    
    for pattern in urgency_patterns:
        matches = re.findall(pattern, text_lower)
        urgency_count += len(matches)
        found_phrases.extend(matches)
    
    return {
        "urgency_score": min(urgency_count / 5.0, 1.0),  # Normalize to 0-1
        "urgency_count": urgency_count,
        "found_phrases": list(set(found_phrases))
    }

def preload_models():
    """Preload all NLP models."""
    get_sentiment_analyzer()
    get_emotion_analyzer()