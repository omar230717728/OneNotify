import requests

def test_pub_dev_connectivity():
    print("Testing connection to pub.dev to verify package registry API connectivity...")
    r = requests.get("https://pub.dev/api/packages/intl")
    assert r.status_code == 200
    json_data = r.json()
    assert json_data["name"] == "intl"
    print("pub.dev package registry connectivity verified successfully!")

# Invoke the test function
test_pub_dev_connectivity()
