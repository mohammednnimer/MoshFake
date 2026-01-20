from typing import Dict, Any, List, Tuple, Union
import numpy as np

def map_scores(outputs: Union[List[Dict[str, Any]], Dict[str, Any]]) -> Tuple[float, float]:
    """
    Map HF pipeline labels to bonafide/spoof scores.
    
    Args:
        outputs: [{"label": "...", "score": 0.9}, ...] or {"all_scores": {"bonafide": 0.7, "spoof": 0.3}, ...}
    
    Returns:
        (bonafide_score, spoof_score)
    """
    bonafide = 0.0
    spoof = 0.0

    if isinstance(outputs, list):
        for item in outputs:
            label = str(item.get("label", "")).lower()
            score = float(item.get("score", 0.0))

            # human-ish
            if any(k in label for k in ["bonafide", "bona-fide", "genuine", "human", "real"]):
                bonafide = max(bonafide, score)

            # ai/spoof-ish
            if any(k in label for k in ["spoof", "fake", "deepfake", "ai", "synthetic"]):
                spoof = max(spoof, score)
    elif isinstance(outputs, dict) and 'all_scores' in outputs:
        all_scores = outputs['all_scores']
        bonafide = float(all_scores.get('bonafide', 0.0))
        spoof = float(all_scores.get('spoof', 0.0))
    else:
        # fallback if unknown format
        if isinstance(outputs, dict) and 'score' in outputs:
            # assume top score is spoof if label not matching
            label = str(outputs.get("label", "")).lower()
            score = float(outputs.get("score", 0.0))
            if any(k in label for k in ["bonafide", "bona-fide", "genuine", "human", "real"]):
                bonafide = score
            else:
                spoof = score

    # fallback if labels are unknown
    if bonafide == 0.0 and spoof == 0.0 and isinstance(outputs, list) and outputs:
        top = max(outputs, key=lambda x: float(x.get("score", 0.0)))
        spoof = float(top.get("score", 0.0))

    return bonafide, spoof

    # fallback if labels are unknown
    if bonafide == 0.0 and spoof == 0.0 and outputs:
        top = max(outputs, key=lambda x: float(x.get("score", 0.0)))
        spoof = float(top.get("score", 0.0))

    return bonafide, spoof

def make_decision(bonafide_score: float, spoof_score: float, threshold: float = 0.70) -> Dict[str, Any]:
    """
    Make a decision based on scores.
    
    Returns:
        {"decision": str, "confidence": float}
    """
    if spoof_score >= threshold and spoof_score > bonafide_score:
        return {
            "decision": "AI-GENERATED",
            "confidence": round(float(spoof_score), 4)
        }
    elif bonafide_score >= threshold and bonafide_score > spoof_score:
        return {
            "decision": "HUMAN",
            "confidence": round(float(bonafide_score), 4)
        }
    else:
        return {
            "decision": "UNCERTAIN",
            "confidence": round(float(max(spoof_score, bonafide_score)), 4)
        }

def aggregate_scores(score_history: List[Tuple[float, float]]) -> Dict[str, Any]:
    """
    Aggregate multiple (bonafide, spoof) score pairs.
    
    Args:
        score_history: [(bonafide, spoof), ...]
    
    Returns:
        Aggregated decision with averages
    """
    if not score_history:
        return {
            "decision": "UNCERTAIN",
            "confidence": 0.0,
            "bonafide_avg": 0.0,
            "spoof_avg": 0.0,
            "chunks_used": 0
        }

    bonas = np.array([b for b, _ in score_history], dtype=np.float32)
    spoofs = np.array([s for _, s in score_history], dtype=np.float32)

    bon_avg = float(np.mean(bonas))
    sp_avg = float(np.mean(spoofs))

    decision_result = make_decision(bon_avg, sp_avg)

    return {
        **decision_result,
        "bonafide_avg": round(bon_avg, 4),
        "spoof_avg": round(sp_avg, 4),
        "chunks_used": len(score_history)
    }
