#!/bin/bash
# Automates post-engineering-meeting Notion housekeeping:
# 1. Fetches recording + Gemini notes URLs from Google Calendar
# 2. Creates a new meeting page with today's date
# 3. Moves "Next" topics from the Bike Rack to the new page
# 4. Adds recording + notes links to the page
# 5. Cleans up the Bike Rack

LOG_FILE="$HOME/.claude/scripts/eng-meeting-notes.log"
exec >> "$LOG_FILE" 2>&1
echo "=== $(date) ==="

# Biweekly check: 2026-02-10 is a known meeting Tuesday
ANCHOR="2026-02-10"
ANCHOR_EPOCH=$(date -j -f "%Y-%m-%d" "$ANCHOR" +%s)
TODAY_EPOCH=$(date -j -f "%Y-%m-%d" "$(date +%Y-%m-%d)" +%s)
DIFF_DAYS=$(( (TODAY_EPOCH - ANCHOR_EPOCH) / 86400 ))

if [ $DIFF_DAYS -lt 0 ]; then
    DIFF_DAYS=$(( -DIFF_DAYS ))
fi

WEEKS=$(( DIFF_DAYS / 7 ))
if [ $(( WEEKS % 2 )) -ne 0 ]; then
    echo "Not a meeting week (week $WEEKS from anchor), skipping."
    exit 0
fi

echo "Meeting week detected. Running automation..."

TODAY_FORMATTED=$(date +%Y-%m-%d)
SCRIPTS_DIR="$HOME/.claude/scripts"

# Fetch recording + notes URLs from Google Calendar
echo "Fetching Google Calendar attachments..."
GCAL_OUTPUT=$(uv run "$SCRIPTS_DIR/gcal-meeting-attachments.py" "$TODAY_FORMATTED" 2>&1)
GCAL_EXIT=$?

RECORDING_URL=""
NOTES_URL=""
MEDIA_INSTRUCTIONS=""

if [ $GCAL_EXIT -eq 0 ]; then
    RECORDING_URL=$(echo "$GCAL_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('recording_url') or '')")
    NOTES_URL=$(echo "$GCAL_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('notes_url') or '')")
    echo "Recording URL: ${RECORDING_URL:-not found}"
    echo "Notes URL: ${NOTES_URL:-not found}"
else
    echo "Warning: Could not fetch calendar data: $GCAL_OUTPUT"
fi

if [ -n "$RECORDING_URL" ] || [ -n "$NOTES_URL" ]; then
    MEDIA_INSTRUCTIONS="

IMPORTANT - Add media links to the page:
"
    if [ -n "$RECORDING_URL" ]; then
        MEDIA_INSTRUCTIONS="${MEDIA_INSTRUCTIONS}- In the 'Recording' section, add a link: [Meeting Recording](${RECORDING_URL})
"
    fi
    if [ -n "$NOTES_URL" ]; then
        MEDIA_INSTRUCTIONS="${MEDIA_INSTRUCTIONS}- In the 'Notes' section, add a link: [Gemini Meeting Notes](${NOTES_URL})
"
    fi
fi

PROMPT="You are automating a post-engineering-meeting workflow in Notion. Do the following steps:

1. Fetch the Bike Rack page: https://www.notion.so/anatomyfinancial/Bike-Rack-Future-Topics-14350a2c0f95803193a0f3a61136db8f

2. Look at the 'Next' section. If there are no real topics under 'Next' (just empty bullets), say 'No topics to move' and stop.

3. If there ARE topics under 'Next', create a new page under the parent page ID 14350a2c0f95800f8b0dcfbc2a56303a (Biweekly Engineering Meeting) with:
   - Title: '${TODAY_FORMATTED} - Eng mtg'
   - Content: the topics from the 'Next' section as bullet points under a 'Topics' heading, followed by 'Recording' and 'Notes' sections
${MEDIA_INSTRUCTIONS}
4. Update the Bike Rack page to remove the topics from the 'Next' section (keep the 'Next' heading with an empty bullet, keep the 'Not ready' section untouched).

5. Print the URL of the new meeting page when done."

claude -p \
    --model haiku \
    --permission-mode bypassPermissions \
    --allowedTools "mcp__notion__notion-fetch,mcp__notion__notion-create-pages,mcp__notion__notion-update-page" \
    "$PROMPT"

echo "=== Done ==="
