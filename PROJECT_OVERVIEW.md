# Deepfake & Scam Detection Call System

## Project Goal
A secure calling application designed to intercept real-time audio from phone calls to analyze and detect deepfakes or scam attempts using machine learning.

## Infrastructure
The system moved from a Peer-to-Peer (P2P) WebRTC architecture to a **Local Selective Forwarding Unit (SFU)** architecture to allow server-side access to audio streams.

### Components
1.  **Flutter App (Android/iOS)**:
    *   Handles user UI, authentication, and permissions.
    *   Uses standard WebRTC but **delegates call initiation** to the server.
    *   Listens for Offer/Answer via Firebase Firestore.

2.  **Firebase (Backend & Signaling)**:
    *   **Firestore**: Acts as the signaling channel. Stores call states (`calling`, `active`, `ended`) and SDP/ICE messages.
    *   **Cloud Functions**: Sends Push Notifications (FCM) to wake up devices for incoming calls.

3.  **Local SFU Server (Python)**:
    *   **Core**: Built with `aiortc` and `asyncio`.
    *   **Role**: Intercepts calls, bridges audio between two peers, and exposes the raw audio buffer for analysis.
    *   **Privacy**: Runs locally; no audio is stored or sent to 3rd party clouds.

## How It Works (The Flow)

1.  **Initiation**:
    *   **Caller App**: Creates a `calls` document in Firestore with `status: calling`. Does *not* create a WebRTC offer yet.
    *   **Caller App**: Waits for the server.

2.  **Interception**:
    *   **SFU Server**: Detects the new call document.
    *   **SFU Server**: Creates two WebRTC connections users: one for Caller, one for Callee.
    *   **SFU Server**: Sends an **Offer** to the **Caller** (addressed as `from: SFU_SERVER`).
    *   **SFU Server**: Sends an **Offer** to the **Callee**.

3.  **Connection**:
    *   **Caller App**: Accepts SFU's offer, answers back.
    *   **Callee App**: Accepts SFU's offer, answers back.
    *   **SFU Server**: Receives answers and bridges the audio tracks using `MediaRelay`.

4.  **Analysis**:
    *   Inside `server.py`, the `AudioAnalysisTrack` class hooks into the audio stream.
    *   Raw audio frames (PCM) are accessible in the `recv()` method for real-time ML processing.

## Tech Stack
*   **Mobile**: Flutter, `flutter_webrtc`, `cloud_firestore`.
*   **Server**: Python 3.14, `aiortc` (WebRTC implementation), `firebase-admin`.
*   **Signaling**: Firebase Firestore.

## Quick Start

### 1. SFU Server
```bash
cd sfu_server
# Ensure serviceAccountKey.json is present
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python server.py
```

### 2. Flutter App
```bash
flutter run
```
