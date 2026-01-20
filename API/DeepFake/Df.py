from transformers import pipeline

MODEL_ID = "Speech-Arena-2025/DF_Arena_1B_V_1"

_clf = None
def get_classifier():
    global _clf
    if _clf is None:
        try:
            _clf = pipeline(
                task="antispoofing",
                model=MODEL_ID,
                device=-1,
                trust_remote_code=True
            )
            print(f"Model loaded successfully from {MODEL_ID}")
        except Exception as e:
            print(f"Failed to load {MODEL_ID}: {e}")
            # Fallback to the secondary model
            _clf = pipeline(
                task="audio-classification",
                model="HyperMoon/wav2vec2-base-960h-finetuned-deepfake",
                device=-1,
                trust_remote_code=False
            )
            print(f"Fallback model loaded successfully")
    return _clf

# Call the function to load the model
get_classifier()
