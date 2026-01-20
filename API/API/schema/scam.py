from pydantic import BaseModel
from typing import  List, Dict, Any

class ScamDetectionResponse(BaseModel):
    is_scam: bool
    confidence: float
    risk_level: str
    score: float
    flags: List[str]
    transcription: Dict[str, Any]
    sentiment_analysis: Dict[str, Any]
    scam_indicators: Dict[str, Any]
    audio_analysis: Dict[str, Any]

class StreamingResponse(BaseModel):
    chunk: ScamDetectionResponse
    session: Dict[str, Any]
