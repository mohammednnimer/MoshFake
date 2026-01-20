import time
from collections import deque
from typing import Dict, Any

# Configuration (Could also be moved to your JSON)
MAX_CHUNKS = 20  # Increased for longer call context
SESSION_TTL = 300 
TREND_WINDOW = 5 # Number of recent chunks to calculate momentum

_SESSIONS: Dict[str, Dict[str, Any]] = {}

def cleanup_sessions():
    """Remove expired sessions to prevent memory leaks."""
    now = time.time()
    dead = [sid for sid, s in _SESSIONS.items() 
            if now - s["last_seen"] > SESSION_TTL]
    for sid in dead:
        del _SESSIONS[sid]

def get_session(session_id: str) -> Dict[str, Any]:
    """Get or create session with enhanced metadata."""
    cleanup_sessions()
    if session_id not in _SESSIONS:
        _SESSIONS[session_id] = {
            "chunks": deque(maxlen=MAX_CHUNKS),
            "transcripts": deque(maxlen=MAX_CHUNKS),
            "scores": deque(maxlen=MAX_CHUNKS),
            "flags": set(), # Track unique flags across the whole call
            "last_seen": time.time(),
            "start_time": time.time(),
            "peak_score": 0.0,
            "is_increasing_risk": False
        }
    return _SESSIONS[session_id]

def update_session(
    session_id: str,
    transcript: str,
    scam_score: float,
    chunk_result: Dict[str, Any]
) -> Dict[str, Any]:
    """Update session with new data and calculate trajectory."""
    sess = get_session(session_id)
    sess["last_seen"] = time.time()
    
    # Clean transcript (remove leading/trailing spaces from STT)
    clean_text = transcript.strip()
    if not clean_text:
        return aggregate_session(sess)

    # Store data
    sess["chunks"].append(chunk_result)
    sess["transcripts"].append(clean_text)
    sess["scores"].append(scam_score)
    
    # Update global session flags
    if "flags" in chunk_result:
        sess["flags"].update(chunk_result["flags"])
    
    # Track peak score
    if scam_score > sess["peak_score"]:
        sess["peak_score"] = scam_score

    return aggregate_session(sess)

def aggregate_session(sess: Dict[str, Any]) -> Dict[str, Any]:
    """Aggregate chunks with Weighted Decay (recent chunks matter more)."""
    if not sess["scores"]:
        return {"overall_risk": "UNKNOWN", "is_scam": False}
    
    scores = list(sess["scores"])
    count = len(scores)
    
    # 1. Calculate Weighted Average
    # We give the most recent 3 chunks a higher weight because scam intensity 
    # usually increases as the call progresses.
    weights = [0.5] * (count - 3) + [1.2, 1.5, 2.0]
    weights = weights[-count:] # Ensure weights match score length
    
    weighted_sum = sum(s * w for s, w in zip(scores, weights))
    weighted_avg = weighted_sum / sum(weights)
    
    # 2. Determine Risk Level
    # Use peak score if the call is short, weighted average if it's long
    final_score = max(weighted_avg, sess["peak_score"] * 0.8)
    
    if final_score >= 70: risk = "HIGH"
    elif final_score >= 35: risk = "MEDIUM"
    else: risk = "LOW"

    # 3. Calculate Momentum (Is the scam getting worse?)
    is_increasing = False
    if count >= 2:
        is_increasing = scores[-1] > scores[-2]

    duration = time.time() - sess["start_time"]
    
    return {
        "overall_risk": risk,
        "score": round(final_score, 2),
        "peak_score": round(sess["peak_score"], 2),
        "is_scam": final_score >= 35,
        "risk_trajectory": "INCREASING" if is_increasing else "STABLE",
        "all_flags": list(sess["flags"]),
        "chunks_analyzed": count,
        "full_transcript": " ".join(sess["transcripts"]),
        "duration_seconds": round(duration, 2),
        "confidence": min(final_score / 100.0, 0.98)
    }
