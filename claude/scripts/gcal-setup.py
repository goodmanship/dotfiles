# /// script
# dependencies = ["google-auth-oauthlib"]
# ///
"""One-time OAuth setup for Google Calendar API access."""

import json
from pathlib import Path

from google_auth_oauthlib.flow import InstalledAppFlow

TOKEN_PATH = Path.home() / ".secrets" / "gcal-token.json"
SCOPES = ["https://www.googleapis.com/auth/calendar.readonly"]

CLIENT_CONFIG = {
    "installed": {
        "client_id": "764086051850-6qr4p6gpi6hn506pt8ejuq83di341hur.apps.googleusercontent.com",
        "client_secret": "d-FL95Q19q7MQmFpd7hHD0Ty",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "redirect_uris": ["http://localhost"],
    }
}

flow = InstalledAppFlow.from_client_config(CLIENT_CONFIG, scopes=SCOPES)
creds = flow.run_local_server(port=0)

TOKEN_PATH.parent.mkdir(exist_ok=True)
TOKEN_PATH.write_text(
    json.dumps(
        {
            "token": creds.token,
            "refresh_token": creds.refresh_token,
            "token_uri": creds.token_uri,
            "client_id": creds.client_id,
            "client_secret": creds.client_secret,
            "scopes": list(creds.scopes),
        }
    )
)
TOKEN_PATH.chmod(0o600)
print(f"Saved credentials to {TOKEN_PATH}")
