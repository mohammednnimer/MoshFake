from fastapi import APIRouter, UploadFile, File, HTTPException, Query
from API.services.scam import detect_scam, detect_scam_streaming

router = APIRouter(prefix="/scam", tags=["Scam Detection"])

@router.post("/analyze")
async def analyze_scam(file: UploadFile = File(...)):
    """
    Analyze audio for scam detection.
    Accepts any audio format (WAV, MP3, M4A, etc.)
    """
    try:
        audio_bytes = await file.read()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Empty audio file")
        
        result = detect_scam(audio_bytes)
        return result
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

@router.post("/analyze/stream")
async def analyze_scam_stream(
    session_id: str = Query(..., description="Session ID for call tracking"),
    file: UploadFile = File(...)
):
    """
    Analyze audio chunk in streaming mode.
    Returns both chunk analysis and aggregated session results.
    """
    try:
        audio_bytes = await file.read()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Empty audio chunk")
        
        result = detect_scam_streaming(audio_bytes, session_id)
        return result
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

@router.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "scam_detection",
        "models": ["whisper-base", "distilbert", "emotion-distilroberta"]
    }
