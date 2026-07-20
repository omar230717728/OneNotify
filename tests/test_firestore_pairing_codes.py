import os
import requests
import json
import time

FIREBASE_API_KEY = os.getenv("FIREBASE_API_KEY", "AIzaSyAzTXacT1DtFyZadS8cPHGSe6aNRtWJUUc")
TARGET_URL = os.getenv("TARGET_URL", "https://firestore.googleapis.com/v1/projects/onenotify-7593c/databases/(default)/documents")
auth_headers = globals().get("__AUTH_HEADERS__", {})

def get_auth_headers():
    if auth_headers and any(k.lower() == "authorization" for k in auth_headers):
        return auth_headers
    # Dynamically sign in via Firebase Anonymous Auth REST API if no injected Bearer token exists
    auth_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={FIREBASE_API_KEY}"
    resp = requests.post(auth_url, json={"returnSecureToken": True})
    assert resp.status_code == 200, f"Failed to get anonymous auth token: {resp.status_code} - {resp.text}"
    id_token = resp.json().get("idToken")
    assert id_token, "Anonymous sign-up returned empty idToken"
    return {"Authorization": f"Bearer {id_token}"}

def test_create_and_read_pairing_code():
    headers = {"Content-Type": "application/json", **get_auth_headers()}
    
    # Generate a unique 6-digit test code
    test_code = f"99{int(time.time()) % 10000:04d}"
    doc_path = f"{TARGET_URL}/pairing_codes/{test_code}"
    
    # Payload matching the exact Firestore schema in main.dart
    payload = {
        "fields": {
            "web_uid": {"stringValue": "testsprite_bot_web_uid"},
            "status": {"stringValue": "pending"},
            "expireAt": {"timestampValue": "2030-01-01T00:00:00.000Z"}
        }
    }
    
    # 1. Create/Patch document via REST API
    create_resp = requests.patch(doc_path, json=payload, headers=headers)
    assert create_resp.status_code in (200, 201), f"Expected 200/201 on document create, got {create_resp.status_code}: {create_resp.text}"
    
    data = create_resp.json()
    assert "fields" in data, f"Response missing 'fields': {data}"
    assert data["fields"]["status"]["stringValue"] == "pending", f"Expected status 'pending', got {data['fields'].get('status')}"
    assert "expireAt" in data["fields"], "Expected 'expireAt' field in Firestore document"

    # 2. Read back document to verify persistence
    read_resp = requests.get(doc_path, headers=headers)
    assert read_resp.status_code == 200, f"Expected 200 on read back, got {read_resp.status_code}: {read_resp.text}"
    read_data = read_resp.json()
    assert read_data["fields"]["web_uid"]["stringValue"] == "testsprite_bot_web_uid"

    # 3. Clean up (delete test document)
    del_resp = requests.delete(doc_path, headers=headers)
    assert del_resp.status_code == 200, f"Expected 200 on delete, got {del_resp.status_code}"

if __name__ == "__main__":
    test_create_and_read_pairing_code()
