from typing import Dict, Any

def generate_security_advice(analysis_data: Dict[str, Any]) -> Dict[str, Any]:
    chunk = analysis_data.get("chunk_result", {})
    scam_chunk = chunk.get("scam_detection", {}).get("chunk", {})
    session = chunk.get("scam_detection", {}).get("session", {})
    ai = chunk.get("ai_detection", {})
    
    # Text-based detection for "Disclosure"
    transcript = scam_chunk.get("transcription", {}).get("text", "").lower()
    ai_disclosed = any(word in transcript for word in ["ai voice", "automated assistant", "generated", "synthetic"])
    
    score = session.get("score", 0)
    is_ai = ai.get("decision") == "AI-GENERATED"
    
    advice = {
        "status": "SAFE",
        "primary_action": "No action needed.",
        "warning_level": "GREEN",
        "instructions": [],
        "risk_reasons": []
    }

    # --- ENHANCED LOGIC ---
    
    if is_ai:
        if score >= 35:
            # Case 1: AI + Suspicious content = DANGER
            advice["status"] = "DANGER"
            advice["warning_level"] = "RED"
            advice["primary_action"] = "CRITICAL: AI SCAM DETECTED"
            advice["risk_reasons"].append("Synthetic voice combined with scam tactics.")
            advice["instructions"].append("This is likely a high-tech vishing attack.")
        elif ai_disclosed:
            # Case 2: AI + Self-Disclosure + Low Score = INFO
            advice["status"] = "INFO"
            advice["warning_level"] = "BLUE"
            advice["primary_action"] = "Automated Assistant Detected"
            advice["instructions"].append("The caller disclosed they are using an AI assistant.")
        else:
            # Case 3: AI + No Disclosure + Low Score = CAUTION
            advice["status"] = "CAUTION"
            advice["warning_level"] = "YELLOW"
            advice["primary_action"] = "Unknown AI Voice"
            advice["instructions"].append("The voice is synthetic but the content is currently harmless.")
            advice["risk_reasons"].append("Undisclosed use of AI voice.")

    elif score >= 70:
        # Human Scammer
        advice["status"] = "DANGER"
        advice["warning_level"] = "RED"
        advice["primary_action"] = "PROBABLE SCAM: HANG UP"
        advice["risk_reasons"].append("Human caller using high-pressure scam tactics.")

    elif score >= 35:
        advice["status"] = "CAUTION"
        advice["warning_level"] = "YELLOW"
        advice["primary_action"] = "Potential Vishing"

    # Standard Verification Instruction
    advice["instructions"].append("Never share codes or personal data unless you initiated the call.")
    
    return advice
