from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from API.routes import detect, scam, both
from DeepFake.detect import preload_model as preload_deepfake
from ScamDetection.detect import preload_models as preload_scam

app = FastAPI(
    title="Security Detection API",
    description="DeepFake and Scam Detection System",
    version="2.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(detect.router)
app.include_router(scam.router)
app.include_router(both.router)

@app.on_event("startup")
async def startup_event():
    """Preload all models on startup."""
    print("=" * 60)
    print("LOADING MODELS...")
    print("=" * 60)
    
    print("\n[1/2] Loading DeepFake detection model...")
    preload_deepfake()
    
    print("\n[2/2] Loading Scam detection models (Whisper + NLP)...")
    preload_scam()
    
    print("\n" + "=" * 60)
    print("ALL MODELS LOADED SUCCESSFULLY!")
    print("=" * 60)

@app.get("/")
async def root():
    return {
        "message": "Security Detection API v2.0",
        "services": {
            "deepfake_detection": {
                "single": "POST /deepfake/detect",
                "streaming": "POST /deepfake/detect/stream"
            },
            "scam_detection": {
                "single": "POST /scam/analyze",
                "streaming": "POST /scam/analyze/stream"
            }
        },
        "health": "/scam/health"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
