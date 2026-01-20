from pydantic import BaseModel, Field
from typing import Optional

class Base64AudioRequest(BaseModel):
    audio_base64: str = Field(..., description="Base64-encoded WAV audio")
    session_id: Optional[str] = Field(None, description="Optional session ID for aggregation")

class DetectionResponse(BaseModel):
    bonafide_score: float
    spoof_score: float
    decision: str
    confidence: float
    energy: float
    is_silent: bool = False
    
class StreamingResponse(BaseModel):
    chunk: DetectionResponse
    aggregated: dict
