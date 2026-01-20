from fastapi import APIRouter, UploadFile, File, HTTPException, Query
from API.schema.deepfake import Base64AudioRequest 
from API.services.deepfake import  detect_from_base64, detect_streaming_chunk

router = APIRouter(prefix="/deepfake", tags=["Deepfake Detection"])

@router.post("/detect")
async def detect_audio(payload: Base64AudioRequest):
    """Detect deepfake from base64-encoded audio."""
    try:
        result = detect_from_base64(payload.audio_base64)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

@router.post("/detect/stream")
async def detect_chunk(
    session_id: str = Query(..., description="Session ID for streaming"),
    file: UploadFile = File(...)
):
    """Analyze audio chunk in streaming context."""
    if not file.filename.lower().endswith(".wav"):
        raise HTTPException(status_code=415, detail="Only WAV files supported")
    
    audio_bytes = await file.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Empty audio file")
    
    try:
        print("Analyzing streaming chunk2")
        result = detect_streaming_chunk(audio_bytes, session_id)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")
