import requests
import base64

url = "http://127.0.0.1:8000/detect"

with open("chunk_000.wav", "rb") as f:
    audio_bytes = f.read()

audio_base64 = base64.b64encode(audio_bytes).decode("utf-8")

payload = {
    "audio_base64": audio_base64,
    "session_id": "test123"
}

response = requests.post(url, json=payload)

print(response.status_code)
print(response.json())
