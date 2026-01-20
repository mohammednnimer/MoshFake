import asyncio
import json
import threading
import time
from datetime import datetime, timezone
import firebase_admin
from firebase_admin import credentials, firestore
from aiortc import RTCPeerConnection, RTCSessionDescription, RTCIceCandidate, MediaStreamTrack
from aiortc.contrib.media import MediaRelay
from aiortc.sdp import candidate_from_sdp
import requests
import io
import wave
import numpy as np

# ==========================================
# CONFIGURATION
# ==========================================
# Path to your Firebase Admin SDK Service Account JSON
# You must download this from the Firebase Console -> Project Settings -> Service Accounts
SERVICE_ACCOUNT_KEY_PATH = 'serviceAccountKey.json'

API_URL = "http://127.0.0.1:8000/call/analyze/"
SAMPLE_RATE = 16000 # Should match your AI model expectation

# ==========================================
# GLOBAL STATE
# ==========================================
active_sessions = {} # call_id -> CallSession
loop = None
db = None

class AudioAnalysisTrack(MediaStreamTrack):
    """
    A MediaStreamTrack that passes through audio (or video) but also allows
    hooking in for analysis.
    """
    kind = "audio"

    def __init__(self, track, call_id, label=""):
        super().__init__()
        self.track = track
        self.call_id = call_id
        self.label = label
        self.audio_buffer = []  # Buffer for accumulating frames
        self.buffer_duration = 3.0 # Analyze every 3 seconds
        self.last_analysis_time = time.time()
        print(f"[{self.label}] Analysis Track Initialized")

    async def recv(self):
        try:
            frame = await self.track.recv()
            
            # Convert frame to numpy and accumulate
            # aiortc audio frames are typically PCM16 or similar
            # frame.to_ndarray() returns a numpy array with shape (channels, samples)
            audio_data = frame.to_ndarray()
            self.audio_buffer.append(audio_data)

            current_time = time.time()
            if current_time - self.last_analysis_time >= self.buffer_duration:
                # Time to analyze!
                self.last_analysis_time = current_time
                asyncio.create_task(self.analyze_buffer())
            
            return frame
        except Exception as e:
            # print(f"[{self.label}] Track ended or error: {e}")
            self.stop()
            raise e

    async def analyze_buffer(self):
        if not self.audio_buffer:
            return

        try:
            # Concatenate all buffered frames
            # audio_buffer is a list of arrays. Each array is (channels, samples)
            # We assume mono for simplicity or take first channel
            concatenated = np.concatenate(self.audio_buffer, axis=1) # Axis 1 is time
            
            # Reset buffer immediately so new data starts accumulating
            self.audio_buffer = []

            # Prepare WAV in memory
            # We need to convert float/int to bytes for WAV
            # aiortc usually gives s16 format
            
            # We need to flatten to 1D array for simple mono wav
            if concatenated.shape[0] > 1:
                # Downmix to mono if stereo
                audio_mono = np.mean(concatenated, axis=0).astype(np.int16)
            else:
                audio_mono = concatenated[0].astype(np.int16)
                
            wav_io = io.BytesIO()
            with wave.open(wav_io, 'wb') as wav_file:
                wav_file.setnchannels(1)
                wav_file.setsampwidth(2) # 16-bit
                wav_file.setframerate(frame.sample_rate if 'frame' in locals() else 48000) # Default or actual
                # Note: 'frame' is not available here, strictly speaking. 
                # aiortc defaults usually 48000. Let's hardcode or capture from first frame.
                # Ideally, capture sample rate in __init__ or recv.
                wav_file.setframerate(48000) 
                wav_file.writeframes(audio_mono.tobytes())
            
            wav_io.seek(0)
            
            # Send to API
            # Run in executor to avoid blocking asyncio loop
            loop = asyncio.get_running_loop()
            await loop.run_in_executor(None, self.send_to_api, wav_io)

        except Exception as e:
            print(f"[{self.label}] Error preparing analysis: {e}")

    def send_to_api(self, wav_file):
        try:
            files = {'file': ('audio.wav', wav_file, 'audio/wav')}
            response = requests.post(API_URL, files=files)
            if response.status_code == 200:
                result = response.json()
                self.handle_analysis_result(result)
            else:
                print(f"[{self.label}] API Error {response.status_code}: {response.text}")
        except Exception as e:
            print(f"[{self.label}] API Request Failed: {e}")

    def handle_analysis_result(self, result):
        # Result structure based on both.py:
        # { "ai_detection": ..., "scam_detection": ... }
        
        is_ai = False
        is_scam = False
        
        ai_data = result.get("ai_detection", {})
        scam_data = result.get("scam_detection", {})

        # Logic to determine flag (adapt based on actual API response structure)
        if ai_data and (ai_data.get('decision') == 'spoof' or ai_data.get('is_deepfake') == True):
            is_ai = True
            
        if scam_data and (scam_data.get('is_scam') == True or scam_data.get('label') == 'scam'):
            is_scam = True
            
        if is_ai or is_scam:
            print(f"[{self.label}] THREAT DETECTED! AI: {is_ai}, SCAM: {is_scam}")
            self.notify_flutter(is_ai, is_scam)

    def notify_flutter(self, is_ai, is_scam):
        # Update Firestore 'calls' document with the threat status
        # Flutter listens to this document
        if db and self.call_id:
            try:
                db.collection('calls').document(self.call_id).update({
                    'security_alert': {
                        'is_ai': is_ai,
                        'is_scam': is_scam,
                        'timestamp': firestore.SERVER_TIMESTAMP
                    }
                })
            except Exception as e:
                print(f"[{self.label}] Failed to update Firestore: {e}")

class CallSession:
    def __init__(self, call_id, caller_id, callee_id, db_ref):
        self.call_id = call_id
        self.caller_id = caller_id
        self.callee_id = callee_id
        self.db = db_ref
        
        # PC_A communicates with the Caller (Alice)
        self.pc_caller = RTCPeerConnection()
        
        # PC_B communicates with the Callee (Bob)
        self.pc_callee = RTCPeerConnection()
        
        # Queues for signaling processing
        self.signaling_queue = asyncio.Queue()

        self.setup_pc(self.pc_caller, "Caller", self.pc_callee)
        self.setup_pc(self.pc_callee, "Callee", self.pc_caller)

    def setup_pc(self, pc, label, other_pc):
        # We add a transceiver to ensure the client knows we plan to send audio back
        # This prevents the need for renegotiation when the other person joins
        pc.addTransceiver("audio", direction="sendrecv")

        @pc.on("track")
        def on_track(track):
            print(f"[{label}] Track received: {track.kind}")
            if track.kind == "audio":
                # Create a wrapper for analysis
                # Pass call_id to allow Firestore updates
                analysis_track = AudioAnalysisTrack(track, self.call_id, label=f"{label}->Analysis")
                
                # Forward this track to the OTHER peer using replaceTrack on the existing transceiver
                # We assume the first transceiver is the audio one
                transceivers = other_pc.getTransceivers()
                if transceivers:
                    print(f"Forwarding {label} audio to {str(other_pc)} via replaceTrack")
                    transceivers[0].sender.replaceTrack(analysis_track)
                else:
                    print("No transceiver found to forward audio")
                    
        @pc.on("iceconnectionstatechange")
        async def on_ice_state():
            print(f"[{label}] ICE State: {pc.iceConnectionState}")

    async def process_signaling_event(self, event_type, data):
        """
        Handle signaling message.
        Direction is determined by 'fromUserId'.
        """
        from_user = data.get('fromUserId')
        target_user = data.get('targetUserId')

        # Determine which PC this is for
        # If message comes FROM Caller, it's for PC_caller
        if from_user == self.caller_id:
            pc = self.pc_caller
            label = "Caller"
        elif from_user == self.callee_id:
            pc = self.pc_callee
            label = "Callee"
        else:
            print(f"Unknown user {from_user} for call {self.call_id}")
            return

        if event_type == 'answer':
             print(f"[{label}] Received Answer SDP")
             answer = RTCSessionDescription(sdp=data['answer']['sdp'], type=data['answer']['type'])
             await pc.setRemoteDescription(answer)
        
        elif event_type == 'ice-candidate':
             print(f"[{label}] Received ICE Candidate")
             candidate_data = data['candidate']
             sdp_string = candidate_data['candidate']
             
             # Important: aiortc expects the candidate string to start with "candidate:"
             # Some clients might send it, some might not.
             if not sdp_string.startswith("candidate:"):
                 sdp_string = "candidate:" + sdp_string
                 
             try:
                 candidate = candidate_from_sdp(sdp_string)
                 candidate.sdpMid = candidate_data.get('sdpMid')
                 candidate.sdpMLineIndex = candidate_data.get('sdpMLineIndex')
                 await pc.addIceCandidate(candidate)
             except Exception as e:
                 print(f"[{label}] Error adding ICE candidate: {e}")

    async def start(self):
        print(f"Starting session for Call {self.call_id}")
        
        # 1. Initiate connection with Caller
        # Caller expects an Offer
        offer_for_caller = await self.pc_caller.createOffer()
        await self.pc_caller.setLocalDescription(offer_for_caller)
        
        await self.send_signaling(
            type='offer',
            from_user="SFU_SERVER", # Use a dedicated ID to avoid P2P crosstalk
            target_user=self.caller_id,
            data={'offer': {'sdp': self.pc_caller.localDescription.sdp, 'type': 'offer'}}
        )

        # 2. Initiate connection with Callee
        # We also send an Offer to Callee
        offer_for_callee = await self.pc_callee.createOffer()
        await self.pc_callee.setLocalDescription(offer_for_callee)
        
        await self.send_signaling(
            type='offer',
            from_user="SFU_SERVER", # Use a dedicated ID
            target_user=self.callee_id,
            data={'offer': {'sdp': self.pc_callee.localDescription.sdp, 'type': 'offer'}}
        )

    async def close(self):
        print(f"Closing session for Call {self.call_id}")
        await self.pc_caller.close()
        await self.pc_callee.close()
        
    async def send_signaling(self, type, from_user, target_user, data):
        """
        Write to Firestore 'signaling' collection
        """
        doc_data = {
            'type': type,
            'fromUserId': from_user,
            'targetUserId': target_user,
            'timestamp': firestore.SERVER_TIMESTAMP
        }
        doc_data.update(data)
        
        # We must run this in a thread executor if not async compatible, 
        # but firebase-admin is sync.
        # We wrap in sync call.
        def write():
            self.db.collection('signaling').add(doc_data)
            
        await loop.run_in_executor(None, write)

async def signaling_worker(queue, active_sessions):
    while True:
        item = await queue.get()
        # item is (change_type, document_dict)
        data = item
        
        # Check if this signal belongs to any active call
        # We filter based on participants
        target_id = data.get('targetUserId')
        from_id = data.get('fromUserId')
        
        # Find session involving these two
        session = None
        
        # We might have stale sessions if they weren't closed properly.
        # Iterate and find a valid open session.
        # We iterate a copy of items to allow modification if needed (though we won't modify here)
        sessions_to_check = list(active_sessions.values())
        
        # Sort by creation time (implicitly insertion order in dict usually, but let's be safe) 
        # Actually, just reverse iteration to find the NEWEST session
        for sess in reversed(sessions_to_check):
            # Check if this session is relevant
            is_match = False
            if (sess.caller_id == from_id and sess.callee_id == target_id) or \
               (sess.caller_id == target_id and sess.callee_id == from_id):
                is_match = True
            
            # SFU Identity Logic
            elif target_id == "SFU_SERVER":
                if sess.caller_id == from_id or sess.callee_id == from_id:
                    is_match = True
            
            if is_match:
                # Check if session is actually alive
                if sess.pc_caller.signalingState == 'closed' or sess.pc_callee.signalingState == 'closed':
                    print(f"Skipping closed session for call {sess.call_id}")
                    continue
                
                session = sess
                break
        
        if session:
            try:
                await session.process_signaling_event(data.get('type'), data)
            except Exception as e:
                print(f"Error processing signaling event: {e}")
        
        queue.task_done()

def on_signaling_snapshot(col_snapshot, changes, read_time):
    for change in changes:
        if change.type.name == 'ADDED':
            data = change.document.to_dict()
            # We only care about Answers and Candidates, offers we generate ourselves
            if data.get('type') in ['answer', 'ice-candidate']:
                # Push to global generic queue, or lookup?
                # Since we don't know the call ID in the signaling doc easily,
                # we push to a global queue and let the worker find the session
                asyncio.run_coroutine_threadsafe(signaling_queue.put(data), loop)

def on_calls_snapshot(col_snapshot, changes, read_time):
    for change in changes:
        data = change.document.to_dict()
        call_id = change.document.id
        
        if change.type.name == 'ADDED' and data.get('status') == 'calling':
            print(f"New Call Detected: {call_id}")
            asyncio.run_coroutine_threadsafe(handle_new_call(call_id, data), loop)
        elif change.type.name == 'MODIFIED' and data.get('status') == 'ended':
            print(f"Call Ended: {call_id}")
            asyncio.run_coroutine_threadsafe(handle_end_call(call_id), loop)

async def handle_end_call(call_id):
    if call_id in active_sessions:
        session = active_sessions.pop(call_id)
        await session.close()

async def handle_new_call(call_id, data):
    if call_id in active_sessions:
        return
        
    caller_id = data.get('fromUserId')
    callee_id = data.get('targetUserId')
    
    # Clean up any existing sessions with the same participants to prevent zombie sessions
    # capturing signaling events.
    stale_calls = []
    for cid, sess in active_sessions.items():
        if (sess.caller_id == caller_id and sess.callee_id == callee_id) or \
           (sess.caller_id == callee_id and sess.callee_id == caller_id):
            print(f"Propagating force close for stale session {cid}")
            stale_calls.append(cid)
            
    for cid in stale_calls:
        sess = active_sessions.pop(cid)
        await sess.close()
    
    session = CallSession(call_id, caller_id, callee_id, db)
    active_sessions[call_id] = session
    await session.start()

# Global signaling queue
signaling_queue = asyncio.Queue()

def main():
    global loop, db
    
    # Init Firebase
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("Firebase Initialized")
    except Exception as e:
        print(f"Error initializing Firebase: {e}")
        print(f"Make sure {SERVICE_ACCOUNT_KEY_PATH} exists.")
        return

    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    
    # Watch signaling
    # We use actual current time for the query, not the sentinel
    now = datetime.now(timezone.utc)
    # Using keyword arguments for filter as suggested by warning, and using concrete datetime
    signaling_query = db.collection('signaling').where(filter=firestore.FieldFilter('timestamp', '>', now))
    
    # Note: Querying by timestamp > NOW requires a proper setup or just listen to all new
    # For simplicity, we just listen to the collection and filter roughly. 
    # Real-world: use a 'processed' flag or better time queries.
    # We monitor the query results via snapshot
    signaling_query.on_snapshot(on_signaling_snapshot)
    
    # Watch calls
    db.collection('calls').where(filter=firestore.FieldFilter('status', '==', 'calling')).on_snapshot(on_calls_snapshot)
    
    print("SFU Server Running... Press Ctrl+C to stop")
    
    # Start signaling worker
    loop.create_task(signaling_worker(signaling_queue, active_sessions))
    
    try:
        loop.run_forever()
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
