# /// script
# dependencies = ["google-api-python-client", "google-auth-oauthlib"]
# ///
"""Fetch recording + Gemini notes URLs from a Google Calendar meeting event."""

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

MEETING_NAME = "Bi-Weekly Engineering Meeting"
TOKEN_PATH = Path.home() / ".secrets" / "gcal-token.json"


def load_creds():
    if not TOKEN_PATH.exists():
        print(json.dumps({"error": f"No token file at {TOKEN_PATH}. Run: uv run ~/.claude/scripts/gcal-setup.py"}))
        sys.exit(1)

    data = json.loads(TOKEN_PATH.read_text())
    creds = Credentials(
        token=data["token"],
        refresh_token=data["refresh_token"],
        token_uri=data["token_uri"],
        client_id=data["client_id"],
        client_secret=data["client_secret"],
        scopes=data["scopes"],
    )

    if creds.expired:
        creds.refresh(Request())
        data["token"] = creds.token
        TOKEN_PATH.write_text(json.dumps(data))

    return creds.with_quota_project("rare-lattice-388916")


def find_meeting(date_str=None):
    creds = load_creds()
    service = build("calendar", "v3", credentials=creds)

    if date_str:
        day = datetime.strptime(date_str, "%Y-%m-%d")
    else:
        day = datetime.now()

    start = day.replace(hour=0, minute=0, second=0, tzinfo=timezone.utc)
    end = start + timedelta(days=1)

    events = (
        service.events()
        .list(
            calendarId="primary",
            timeMin=start.isoformat(),
            timeMax=end.isoformat(),
            q=MEETING_NAME,
            singleEvents=True,
            orderBy="startTime",
        )
        .execute()
        .get("items", [])
    )

    if not events:
        print(json.dumps({"error": f"No '{MEETING_NAME}' event found on {start.date()}"}))
        sys.exit(1)

    event = events[0]
    recording_url = None
    notes_url = None

    for att in event.get("attachments", []):
        mime = att.get("mimeType", "")
        title = att.get("title", "").lower()
        url = att.get("fileUrl", "")
        if "video" in mime or "recording" in title:
            recording_url = url
        elif "document" in mime or "note" in title:
            notes_url = url

    conf = event.get("conferenceData", {})
    for entry in conf.get("entryPoints", []):
        if entry.get("entryPointType") == "video" and not recording_url:
            recording_url = entry.get("uri")

    print(
        json.dumps(
            {
                "event_title": event.get("summary", ""),
                "recording_url": recording_url,
                "notes_url": notes_url,
            }
        )
    )


if __name__ == "__main__":
    find_meeting(sys.argv[1] if len(sys.argv) > 1 else None)
