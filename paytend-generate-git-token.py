import jwt
import time
import requests

APP_ID = '2372278'
INSTALLATION_ID = '101812727'

with open("/etc/Paytend-DBA/private-key.pem", "r") as f:
    private_key = f.read()

payload = {
    "iat": int(time.time()),
    "exp": int(time.time()) + 540,  # 9 minutes
    "iss": APP_ID
}

jwt_token = jwt.encode(payload, private_key, algorithm="RS256")

# Create installation access token
url = f"https://api.github.com/app/installations/{INSTALLATION_ID}/access_tokens"
headers = {
    "Authorization": f"Bearer {jwt_token}",
    "Accept": "application/vnd.github+json"
}
res = requests.post(url, headers=headers, json={})
print(res.json()["token"])
