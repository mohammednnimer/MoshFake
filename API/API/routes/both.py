from fastapi import APIRouter, UploadFile, File, HTTPException, Query, Request
import base64
from API.services.deepfake import detect_from_base64
from API.services.scam import detect_scam 
from pydantic import BaseModel

router = APIRouter(prefix="/call/analyze", tags=["Call Analysis"])


@router.post("/stream/")
async def analyze_audio(request: Request):
    """
    Analyze audio data received as bytes directly from the client.
    """
    try:
        # Receive raw audio bytes directly from the request body
        audio_bytes = await request.body()

        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Empty audio data received")

        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        ai_result = detect_from_base64(audio_base64)
        scam_result = detect_scam(audio_bytes)

        return {
            "ai_detection": ai_result,
            "scam_detection": scam_result
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

class AudioData(BaseModel):
    audio_base64: str  # Base64 encoded audio string

@router.post("/analyze_base64/")
async def analyze_audio_base64(data: AudioData):
    """
    Analyze base64-encoded audio data for both AI/deepfake indicators and scam detection.
    """
    try:
        # Decode the base64 string to bytes
        audio_bytes = base64.b64decode(data.audio_base64)

        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Empty audio data")

        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        ai_result = detect_from_base64(data.audio_base64)

        scam_result = detect_scam(audio_bytes)

        return {
            "ai_detection": ai_result,
            "scam_detection": scam_result
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")
    


@router.post("/detect/stream")
async def analyze_audio(request: Request):
    """
    Analyze audio data received as raw bytes directly from the client.
    """
    try:
        # استلام البيانات الصوتية كـ raw bytes
        audio_bytes = await request.body()

        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Empty audio data received")

        ai_result = detect_from_bytes(audio_bytes)
        scam_result = detect_scam(audio_bytes)

        return {
            "ai_detection": ai_result,
            "scam_detection": scam_result
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

@router.post("/")
async def analyze_call(file: UploadFile = File(...)):
    """
    Analyze an audio file for both AI/deepfake indicators and scam detection.
    Accepts WAV, MP3, M4A, or any supported audio format.
    """
    audio_bytes = await file.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Empty audio file")

    try:
        # ---- AI / Deepfake Detection ----
        #ai_result = detect_from_base64(audio_bytes)  # or your service function that takes bytes
        # If your detect_from_base64 only works with base64, you can convert bytes to base64 first:
        ai_result = detect_from_base64(base64.b64encode(audio_bytes).decode())

        # ---- Scam Detection ----
        scam_result = detect_scam(audio_bytes)

        return {
            "ai_detection": ai_result,
            "scam_detection": scam_result
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")


@router.get("/health")
async def health_check():
    """Health check for combined AI and scam detection endpoint."""
    return {
        "status": "healthy",
        "service": "call_analysis",
        "models": [
            "whisper-base",
            "distilbert-sentiment",
            "emotion-distilroberta",
            "scam_keyword_detector"
        ]
    }

