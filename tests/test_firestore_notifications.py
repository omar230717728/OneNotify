import os
import requests
import time

FIREBASE_API_KEY = os.getenv("FIREBASE_API_KEY", "AIzaSyAzTXacT1DtFyZadS8cPHGSe6aNRtWJUUc")
TARGET_URL = os.getenv("TARGET_URL", "https://firestore.googleapis.com/v1/projects/onenotify-7593c/databases/(default)/documents")
auth_headers = globals().get("__AUTH_HEADERS__", {})

def get_auth_headers():
    if auth_headers and any(k.lower() == "authorization" for k in auth_headers):
        return auth_headers
    auth_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={FIREBASE_API_KEY}"
    resp = requests.post(auth_url, json={"returnSecureToken": True})
    assert resp.status_code == 200, f"Failed to get anonymous auth token: {resp.status_code} - {resp.text}"
    id_token = resp.json().get("idToken")
    return {"Authorization": f"Bearer {id_token}"}

def test_user_notifications_collection_schema():
    headers = {"Content-Type": "application/json", **get_auth_headers()}
    
    test_uid = f"testsprite_user_{int(time.time())}"
    doc_id = "test_notification_001"
    doc_path = f"{TARGET_URL}/users/{test_uid}/notifications/{doc_id}"
    
    # Payload matching the exact synced notification structure from mobile app
    payload = {
        "fields": {
            "packageName": {"stringValue": "com.whatsapp"},
            "title": {"stringValue": "TestSender"},
            "message": {"stringValue": "Hello from TestSprite backend verification!"},
            "timestamp": {"integerValue": str(int(time.time() * 1000))}
        }
    }
    
    # 1. Create notification document
    create_resp = requests.patch(doc_path, json=payload, headers=headers)
    assert create_resp.status_code in (200, 201), f"Expected 200/201 on notification insert, got {create_resp.status_code}: {create_resp.text}"
    
    # 2. Query list of notifications under user
    list_path = f"{TARGET_URL}/users/{test_uid}/notifications"
    list_resp = requests.get(list_path, headers=headers)
    assert list_resp.status_code == 200, f"Expected 200 on notifications list, got {list_resp.status_code}: {list_resp.text}"
    
    data = list_resp.json()
    assert "documents" in data, f"Expected 'documents' list in query result, got {data}"
    assert len(data["documents"]) >= 1, "Expected at least 1 notification document returned"
    assert data["documents"][0]["fields"]["packageName"]["stringValue"] == "com.whatsapp"

    # 3. Clean up
    requests.delete(doc_path, headers=headers)

if __name__ == "__main__":
    test_user_notifications_collection_schema()
