import sqlite3
import time

def setup_test_db():
    conn = sqlite3.connect(":memory:")
    cursor = conn.cursor()
    # Create tables
    cursor.execute("""
        CREATE TABLE notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name TEXT NOT NULL,
            app_name TEXT,
            title TEXT,
            message TEXT,
            timestamp INTEGER NOT NULL
        )
    """)
    cursor.execute("""
        CREATE TABLE monitored_apps (
            package_name TEXT PRIMARY KEY,
            is_muted INTEGER DEFAULT 1
        )
    """)
    conn.commit()
    return conn

# 1. System Blacklist
SYSTEM_BLACKLIST = {
    "android",
    "com.android.systemui",
    "com.android.settings",
    "com.google.android.inputmethod.latin",
    "com.android.providers.downloads",
    "com.google.android.apps.messaging"
}

def should_intercept(package_name, conn):
    if package_name in SYSTEM_BLACKLIST:
        return False
    # Check if monitored
    cursor = conn.cursor()
    cursor.execute("SELECT 1 FROM monitored_apps WHERE package_name = ?", (package_name,))
    row = cursor.fetchone()
    return row is not None

# 2. Deduplication check
def is_duplicate(package_name, title, message, conn):
    cursor = conn.cursor()
    cursor.execute(
        "SELECT title, message FROM notifications WHERE package_name = ? ORDER BY timestamp DESC LIMIT 1",
        (package_name,)
    )
    row = cursor.fetchone()
    if row:
        return row[0] == title and row[1] == message
    return False

# 3. Prune on Write (keep only 20 newest)
def prune_notifications(package_name, conn):
    cursor = conn.cursor()
    cursor.execute("""
        DELETE FROM notifications 
        WHERE package_name = ? 
        AND id NOT IN (
            SELECT id FROM notifications 
            WHERE package_name = ? 
            ORDER BY timestamp DESC 
            LIMIT 20
        )
    """, (package_name, package_name))
    conn.commit()

# 4. Housekeeping (older than 14 days)
def purge_old_notifications(conn):
    cursor = conn.cursor()
    fourteen_days_ms = 14 * 24 * 60 * 60 * 1000
    now_ms = int(time.time() * 1000)
    cutoff = now_ms - fourteen_days_ms
    cursor.execute("DELETE FROM notifications WHERE timestamp < ?", (cutoff,))
    conn.commit()

def test_system_noise_blacklist():
    print("RUNNING TEST: System Noise Blacklist...")
    conn = setup_test_db()
    cursor = conn.cursor()
    # Add com.whatsapp to monitored list
    cursor.execute("INSERT INTO monitored_apps (package_name, is_muted) VALUES ('com.whatsapp', 1)")
    conn.commit()

    # Blacklisted should return False
    assert not should_intercept("android", conn)
    assert not should_intercept("com.android.systemui", conn)
    
    # Monitored should return True
    assert should_intercept("com.whatsapp", conn)
    # Unmonitored should return False
    assert not should_intercept("com.instagram.android", conn)
    print("✅ System Noise Blacklist passed.")

def test_deduplication():
    print("RUNNING TEST: Deduplication check...")
    conn = setup_test_db()
    cursor = conn.cursor()
    # Insert first notification
    cursor.execute(
        "INSERT INTO notifications (package_name, title, message, timestamp) VALUES (?, ?, ?, ?)",
        ("com.whatsapp", "John Doe", "Hello", int(time.time() * 1000))
    )
    conn.commit()

    # Duplicate should be detected
    assert is_duplicate("com.whatsapp", "John Doe", "Hello", conn)
    # Different title/message should not be duplicate
    assert not is_duplicate("com.whatsapp", "John Doe", "Hello World", conn)
    print("✅ Deduplication check passed.")

def test_prune_on_write():
    print("RUNNING TEST: Prune on Write (20 newest limit)...")
    conn = setup_test_db()
    cursor = conn.cursor()
    
    # Insert 25 notifications for same package
    base_time = int(time.time() * 1000)
    for i in range(25):
        cursor.execute(
            "INSERT INTO notifications (package_name, title, message, timestamp) VALUES (?, ?, ?, ?)",
            ("com.whatsapp", f"Sender {i}", f"Msg {i}", base_time + i)
        )
    conn.commit()

    prune_notifications("com.whatsapp", conn)
    
    # Should only have 20 newest notifications
    cursor.execute("SELECT COUNT(*) FROM notifications WHERE package_name = 'com.whatsapp'")
    count = cursor.fetchone()[0]
    assert count == 20

    # Ensure the older ones (0 to 4) were deleted
    cursor.execute("SELECT title FROM notifications WHERE package_name = 'com.whatsapp' ORDER BY timestamp ASC LIMIT 1")
    oldest_title = cursor.fetchone()[0]
    assert oldest_title == "Sender 5"
    print("✅ Prune on Write passed.")

def test_housekeeping_guard():
    print("RUNNING TEST: Housekeeping Guard (14 days auto-purge)...")
    conn = setup_test_db()
    cursor = conn.cursor()
    
    now_ms = int(time.time() * 1000)
    day_ms = 24 * 60 * 60 * 1000
    
    # Insert notification from 15 days ago
    cursor.execute(
        "INSERT INTO notifications (package_name, title, message, timestamp) VALUES (?, ?, ?, ?)",
        ("com.whatsapp", "Old Msg", "Hello from past", now_ms - (15 * day_ms))
    )
    # Insert notification from 5 days ago
    cursor.execute(
        "INSERT INTO notifications (package_name, title, message, timestamp) VALUES (?, ?, ?, ?)",
        ("com.whatsapp", "New Msg", "Hello from now", now_ms - (5 * day_ms))
    )
    conn.commit()

    purge_old_notifications(conn)
    
    # Only new one should remain
    cursor.execute("SELECT COUNT(*) FROM notifications")
    count = cursor.fetchone()[0]
    assert count == 1
    
    cursor.execute("SELECT title FROM notifications")
    remaining_title = cursor.fetchone()[0]
    assert remaining_title == "New Msg"
    print("✅ Housekeeping Guard passed.")

def test_app_monitoring_and_mutation():
    print("RUNNING TEST: App Monitoring and Mutation...")
    conn = setup_test_db()
    cursor = conn.cursor()

    # Initially, package is not monitored
    package = "com.whatsapp"
    assert not should_intercept(package, conn)

    # 1. Add app to monitored list (Muted by default)
    cursor.execute("INSERT INTO monitored_apps (package_name, is_muted) VALUES (?, 1)", (package,))
    conn.commit()
    assert should_intercept(package, conn)
    
    # Verify it is muted (Auto-Dismiss ON)
    cursor.execute("SELECT is_muted FROM monitored_apps WHERE package_name = ?", (package,))
    is_muted = cursor.fetchone()[0]
    assert is_muted == 1
    
    # 2. Mutate app status: Unmute the app (is_muted = 0)
    cursor.execute("UPDATE monitored_apps SET is_muted = 0 WHERE package_name = ?", (package,))
    conn.commit()
    
    cursor.execute("SELECT is_muted FROM monitored_apps WHERE package_name = ?", (package,))
    is_muted = cursor.fetchone()[0]
    assert is_muted == 0
    
    # 3. Delete app from monitored list
    cursor.execute("DELETE FROM monitored_apps WHERE package_name = ?", (package,))
    conn.commit()
    assert not should_intercept(package, conn)
    print("✅ App Monitoring, Deletion, and Mutation passed.")

# Execute all tests
test_system_noise_blacklist()
test_deduplication()
test_prune_on_write()
test_housekeeping_guard()
test_app_monitoring_and_mutation()
print("All business logic & SQLite data constraints verified successfully!")
