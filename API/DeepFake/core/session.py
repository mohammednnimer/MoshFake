import time
from collections import deque
from typing import Dict, Any
from .scoring import aggregate_scores

MAX_KEEP = 10
SESSION_TTL_SEC = 120

# Global session storage
_SESSIONS: Dict[str, Dict[str, Any]] = {}

def cleanup_sessions():
    """Remove expired sessions."""
    now = time.time()
    dead = [sid for sid, s in _SESSIONS.items() 
            if now - s.get("last_seen", now) > SESSION_TTL_SEC]
    for sid in dead:
        del _SESSIONS[sid]

def get_session(session_id: str) -> Dict[str, Any]:
    """Get or create session."""
    cleanup_sessions()
    if session_id not in _SESSIONS:
        _SESSIONS[session_id] = {
            "scores": deque(maxlen=MAX_KEEP),
            "last_seen": time.time()
        }
    return _SESSIONS[session_id]

def update_session(session_id: str, bonafide: float, spoof: float) -> Dict[str, Any]:
    """Add score to session and return aggregated result."""
    sess = get_session(session_id)
    sess["last_seen"] = time.time()
    sess["scores"].append((bonafide, spoof))
    
    return aggregate_scores(list(sess["scores"]))

def get_aggregated(session_id: str) -> Dict[str, Any]:
    """Get current aggregated scores without updating."""
    if session_id not in _SESSIONS:
        return aggregate_scores([])
    return aggregate_scores(list(_SESSIONS[session_id]["scores"]))

def clear_session(session_id: str):
    """Clear a specific session."""
    if session_id in _SESSIONS:
        del _SESSIONS[session_id]
