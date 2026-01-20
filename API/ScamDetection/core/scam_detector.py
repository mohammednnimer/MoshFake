import json
import re
from typing import Dict, Any
from rapidfuzz import process, fuzz

# --- DATA LOADING ---
def load_config(path='scam_config.json'):
    with open(path, 'r') as f:
        return json.load(f)

CONFIG = load_config()
SCAM_KEYWORDS = CONFIG['keywords']
INTENT_PATTERNS = CONFIG['intent_patterns']
REGEX_PATTERNS = CONFIG['regex_patterns']

def detect_vishing_intent(text: str) -> Dict[str, Any]:
    text_lower = text.lower()
    found = {}
    score = 0

    for category, phrases in INTENT_PATTERNS.items():
        matches = [p for p in phrases if p in text_lower]
        if matches:
            found[category] = matches
            score += 15  # Weighted heavier for behavioral intent

    # This is much more precise than just keyword spotting
    critical_behaviors = [
        (r"(verify|confirm|tell|give|provide).{0,50}(password|pin|ssn|account|card|otp)", 30, "direct_solicitation"),
        (r"(install|download|open).{0,50}(anydesk|teamviewer|remote|software|help)", 25, "remote_access_trap")
    ]
    
    behavior_flags = []
    for pattern, pts, flag in critical_behaviors:
        if re.search(pattern, text_lower):
            score += pts
            behavior_flags.append(flag)

    return {
        "intent_score": min(score, 60), # Higher cap for better precision
        "intent_flags": list(found.keys()) + behavior_flags,
        "intent_matches": found
    }

def analyze_keywords(text: str, fuzzy_threshold: int = 85) -> Dict[str, Any]:
    text_lower = text.lower()
    words = text_lower.split()
    total_score = 0.0
    found_keywords = {}

    # 1. Direct Multi-word Phrase Matching (High Precision)
    sorted_phrases = sorted([k for k in SCAM_KEYWORDS.keys() if " " in k], key=len, reverse=True)
    for phrase in sorted_phrases:
        if phrase in text_lower:
            weight = SCAM_KEYWORDS[phrase]
            count = text_lower.count(phrase)
            total_score += weight * count
            found_keywords[phrase] = {"weight": weight, "count": count, "contribution": weight * count}
            text_lower = text_lower.replace(phrase, " ") # Avoid double counting

    # 2. Fuzzy Single Word Matching (Handles STT Errors)
    # If STT hears "Bank" as "Bonk", this will catch it
    for word in words:
        if len(word) < 4: continue
        match = process.extractOne(word, SCAM_KEYWORDS.keys(), scorer=fuzz.WRatio)
        if match and match[1] >= fuzzy_threshold:
            keyword, weight = match[0], SCAM_KEYWORDS[match[0]]
            if keyword not in found_keywords:
                total_score += weight
                found_keywords[keyword] = {"weight": weight, "count": 1, "contribution": weight}

    return {
        "keyword_score": total_score,
        "found_keywords": found_keywords,
        "keyword_count": len(found_keywords),
        "is_suspicious": total_score >= 5.0
    }

def detect_scam_patterns(text: str) -> Dict[str, Any]:
    found = {}
    for name, pattern in REGEX_PATTERNS.items():
        matches = re.findall(pattern, text, re.IGNORECASE)
        if matches:
            found[name] = matches

    risk = 0
    if "ssn" in found: risk += 50
    if "account_number" in found: risk += 40
    if "routing_number" in found: risk += 45
    if "credit_card" in found: risk += 45
    if "money_amount" in found: risk += 15
    if "url" in found or "phone_number" in found: risk += 10

    return {
        "patterns": found,
        "pattern_risk_score": min(risk, 100),
        "has_sensitive_data": any(k in found for k in ["ssn", "account_number", "routing_number", "credit_card"])
    }

def calculate_scam_score(
    keyword_analysis: Dict[str, Any],
    pattern_analysis: Dict[str, Any],
    intent_analysis: Dict[str, Any],
    sentiment: Dict[str, Any],
    urgency: Dict[str, Any],
    audio_features: Dict[str, Any],
    ai_indicators: Dict[str, Any]
) -> Dict[str, Any]:

    score = 0.0
    flags = []

    # 1. Keywords (0–40) - Multiplier applied to fuzzy score
    keyword_score = min(keyword_analysis["keyword_score"] * 4, 40)
    score += keyword_score
    if keyword_analysis["is_suspicious"]:
        flags.append("suspicious_keywords")

    # 2. Regex patterns (0–30)
    pattern_score = min(pattern_analysis["pattern_risk_score"] * 0.3, 30)
    score += pattern_score
    if pattern_analysis["has_sensitive_data"]:
        flags.append("requests_sensitive_data")

    # 3. Intent & Behavioral Logic (0–40)
    intent_score = intent_analysis.get("intent_score", 0)
    score += intent_score
    if intent_score >= 20:
        flags.append("vishing_behavior_detected")

    # --- CROSS-CHECK MULTIPLIER (The Precision Fix) ---
    # If identity (Bank/IRS) + Payment Method (Gift Card/Crypto) both exist, spike the score.
    high_risk_id = any(k in keyword_analysis["found_keywords"] for k in ["irs", "fbi", "bank", "support", "amazon"])
    high_risk_pay = any(k in keyword_analysis["found_keywords"] for k in ["gift card", "bitcoin", "crypto", "wire transfer"])
    if high_risk_id and high_risk_pay:
        score *= 1.4
        flags.append("CRITICAL_COMBINATION_DETECTED")

    # 4. Sentiment (0–10)
    sentiment_score = 5.0 if sentiment.get("label") == "NEGATIVE" else 0.0
    score += sentiment_score
    if sentiment_score: flags.append("negative_sentiment")

    # 5. Urgency (0–10)
    urgency_score = urgency.get("urgency_score", 0.0) * 10
    score += urgency_score
    if urgency.get("urgency_count", 0) >= 2: flags.append("high_urgency")

    # 6. Audio Indicators (0–10)
    audio_score = 0.0
    if ai_indicators.get("is_likely_ai"):
        audio_score = 10.0
        flags.append("likely_ai_voice")
    elif audio_features.get("pitch_std", 0) > 80 or audio_features.get("pitch_erratic"):
        audio_score = 5.0
        flags.append("erratic_speech_pattern")
    score += audio_score

    score = min(score, 100)

    # Risk Levels
    risk = "LOW"
    if score >= 70: risk = "HIGH"
    elif score >= 35: risk = "MEDIUM"

    return {
        "is_scam": score >= 65,
        "confidence": round(min(score / 100, 0.98), 4),
        "score": round(score, 2),
        "risk_level": risk,
        "flags": flags,
        "score_breakdown": {
            "keywords": round(keyword_score, 2),
            "patterns": round(pattern_score, 2),
            "intent": round(intent_score, 2),
            "sentiment": round(sentiment_score, 2),
            "urgency": round(urgency_score, 2),
            "audio": round(audio_score, 2)
        }
    }
