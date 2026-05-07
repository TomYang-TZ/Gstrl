#!/usr/bin/env python3
"""
iGest Vision Server — gaze tracking (GazeTracking) + hand detection (MediaPipe).
Streams JSON over Unix socket: {"gaze": [x, y], "hand": "inactive"|"tracking"|"pinching"}
"""
import socket
import os
import sys
import signal
import time
import json

SOCKET_PATH = "/Users/tomyang/iGest/.igest_gaze.sock"

def cleanup(*args):
    try:
        os.unlink(SOCKET_PATH)
    except:
        pass
    sys.exit(0)

signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

def classify_hand(hand_landmarks):
    thumb_tip = hand_landmarks.landmark[4]
    index_tip = hand_landmarks.landmark[8]
    middle_tip = hand_landmarks.landmark[12]
    index_pip = hand_landmarks.landmark[6]
    middle_pip = hand_landmarks.landmark[10]

    pinch_dist = ((thumb_tip.x - index_tip.x)**2 + (thumb_tip.y - index_tip.y)**2)**0.5
    if pinch_dist < 0.06:
        return "pinching"

    if index_tip.y < index_pip.y and middle_tip.y < middle_pip.y:
        return "tracking"

    return "inactive"

def main():
    try:
        os.unlink(SOCKET_PATH)
    except FileNotFoundError:
        pass

    # Create socket
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(1)
    server.settimeout(0.5)
    print(f"Socket ready at {SOCKET_PATH}", flush=True)

    import cv2
    import mediapipe as mp
    from gaze_tracking import GazeTracking

    gaze = GazeTracking()

    mp_hands = mp.solutions.hands
    hands = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=1,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.4
    )

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("ERROR: Cannot open webcam", file=sys.stderr)
        server.close()
        cleanup()

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 30)

    print(f"Camera open. GazeTracking + MediaPipe Hands ready.", flush=True)

    client = None
    frame_count = 0

    try:
        while True:
            if client is None:
                try:
                    client, _ = server.accept()
                    client.setblocking(False)
                    print("Client connected", flush=True)
                except socket.timeout:
                    pass

            ret, frame = cap.read()
            if not ret:
                time.sleep(0.01)
                continue

            frame_count += 1
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            # --- Gaze tracking via GazeTracking (pupil-based) ---
            gaze_x, gaze_y = 0.5, 0.5
            try:
                gaze.refresh(frame)
                h = gaze.horizontal_ratio()
                v = gaze.vertical_ratio()
                if h is not None and v is not None:
                    # Filter out v=1.0 / v=0.0 (saturation artifacts)
                    if v >= 0.98 or v <= 0.02:
                        pass  # skip, keep previous gaze_x/gaze_y at 0.5
                    else:
                        gaze_x = h
                        gaze_y = v
            except Exception:
                pass

            # --- Hand tracking via MediaPipe ---
            hand_state = "inactive"
            try:
                hand_results = hands.process(frame_rgb)
                if hand_results.multi_hand_landmarks:
                    hand_state = classify_hand(hand_results.multi_hand_landmarks[0])
            except Exception:
                pass

            # --- Send to client ---
            if client is not None:
                try:
                    msg = json.dumps({"gaze": [gaze_x, gaze_y], "hand": hand_state}) + "\n"
                    client.sendall(msg.encode())
                except (BrokenPipeError, ConnectionResetError, BlockingIOError, OSError):
                    client = None

            if frame_count % 30 == 0:
                h_raw = gaze.horizontal_ratio()
                v_raw = gaze.vertical_ratio()
                pupils = gaze.pupils_located
                print(f"Frame {frame_count}: raw_h={h_raw} raw_v={v_raw} pupils={pupils} -> ({gaze_x:.3f},{gaze_y:.3f}) hand={hand_state}", flush=True)

    except KeyboardInterrupt:
        pass
    except Exception as e:
        print(f"FATAL: {e}", file=sys.stderr, flush=True)
    finally:
        cap.release()
        hands.close()
        if client:
            client.close()
        server.close()
        cleanup()

if __name__ == "__main__":
    main()
