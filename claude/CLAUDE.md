## General Rules
- **Always use CLI tools** (gh, jira, temporal, ddlogs, etc.) instead of WebFetch for authenticated services (GitHub, Temporal Cloud, Jira, Datadog). WebFetch can't authenticate.
- **Limit concurrent background agents to 2-3** — more can hit OS process limits (`fork failed: resource temporarily unavailable`), freezing all bash execution.

## Code Style
- **No docstrings** - method names should be self-documenting
- **No type hints** - avoid verbose signatures; prefer clear method names over return type annotations
- **Short names** - shortest names possible without ambiguity
- **Minimal comments** - only for unexpected behavior or hidden context
- **Single-responsibility methods** - refactor to keep interfaces clean
- Use `uv` or `dev/exec` to run test/python commands — never `pip`

## PR Reviews
- Check ALL unresolved comments using GraphQL `reviewThreads` (REST `/comments` doesn't show resolution status) — see `memory/feedback_pr_comments.md` for full query
- Cursor Bugbot adds new comments on each push - check for latest after each commit
- **CodeQL alerts block PRs** — must dismiss High alerts via API, not just reply to comments: `gh api repos/{owner}/{repo}/code-scanning/alerts/{id} --method PATCH -f state=dismissed -f "dismissed_reason=won't fix" -f "dismissed_comment=Reason here"`
- To find CodeQL alerts: `gh api repos/{owner}/{repo}/code-scanning/alerts --method GET -f per_page=100 | jq '[.[] | select(.state == "open")] | .[] | {number, rule_id: .rule.id, severity: .rule.security_severity_level, path: .most_recent_instance.location.path}'`
- For full CLI review: `gh pr view <n> --repo <org/repo> --json title,body,state,files,additions,deletions`, `gh pr diff <n> --repo <org/repo>`
- When reviewing code that duplicates existing methods (e.g. `_db_only` variants), always read the originals to diff behavior changes

## Development Workflow

### Starting New Work
1. **Create Jira ticket** - `jira issue create -p AN -t"Feature (API)" -s"Summary" ...`
2. **Assign to Rio** - `jira issue assign AN-XXXX rio@anatomy.com`
3. **Add to Kamino sprint** - `jira sprint add <sprint_id> AN-XXXX` (if can't find sprint ID, ask user)
4. **Find/create worktree** - look for dormant worktree in repo, or create new one
5. **Setup branch:**
   ```bash
   cd <worktree>
   git fetch origin && git checkout main && git pull origin main
   git checkout -b AN-XXXX-short-description
   ```
6. **Make changes**
7. **PR or local review:**
   - If plan already discussed → push and create PR, share link for GH review
   - If plan NOT discussed → let user review locally before pushing

### Git Worktrees
```bash
# List existing worktrees
git worktree list

# Create new worktree
git worktree add ../repo-wt-2 main

# Remove worktree when done
git worktree remove ../repo-wt-2
```

Worktree naming: `<repo>-wt-<n>` (e.g., `doc-service-wt-2`)

### Git Conventions
- **PR approvals:** Claude's git pushes can't be attributed to a GitHub user, so branch protection rules requiring "approval from someone other than the last pusher" will demand an extra approval. The user (PR author) cannot self-approve.
- Branch names: `AN-XXXX-short-description` (Jira ticket prefix)
- Commit messages: short and sweet, e.g. `Fix remit validation race condition` (pre-commit hook prepends ticket from branch name)
- Before pushing, run: `uv run black .`, `uv run flake8`, `uv run pytest <modified tests>` (existing projects use black+flake8; new projects use ruff)
- Before pushing a new branch, fetch and rebase onto main (`git fetch origin && git rebase origin/main`)
- ALWAYS ask for a Jira ticket number before creating branches/commits. Never use placeholder ticket numbers like AN-XXXX - they will cause CI to fail.
- **anatomy-core version bump**: Always bump `version` in `pyproject.toml` when making changes — dependent repos pin to specific versions via submodule

### Jira Commands
- `jira sprint list --state active --plain` - find current sprint ID
- `jira issue create -p AN -t"Feature (API)" -s"Summary" -b"Description" -l back_end -y Medium --no-input`
- **AN project issue types:** `Feature (API)` (default), `Bug (API)` — "Task" and "Story" are NOT valid
- `jira sprint add <sprint_id> AN-XXXX` - add ticket to sprint
- `jira issue edit AN-XXXX -P EPIC-KEY --no-input` - add ticket as child of epic
- `jira issue link AN-XXXX AN-YYYY "Blocks"` - link tickets (types: Blocks, Relates, Duplicate)
- `jira issue move AN-XXXX "In Progress"` - transition states vary by issue type (no `--no-input` flag)
- Jira transition names ≠ target status names. Use an invalid name to discover available transitions: `jira issue move AN-XXXX "x"` → error shows options
- Full transition chains for Bug/Feature/DROID: see `memory/jira.md`
- `jira issue comment add AN-XXXX --template /path/to/file.txt --no-input` — for multi-line comments (heredocs can hang the CLI)
- To delete a link: get link ID from `jira issue view AN-XXXX --raw` (parse `.fields.issuelinks[].id`), then `curl -X DELETE -u "rio@anatomy.com:${JIRA_API_TOKEN}" "https://anatomy.atlassian.net/rest/api/3/issueLink/{id}"`

### Hotfix Workflow (PR against prod)
1. Use the same Jira ticket as the main PR (no separate hotfix ticket needed)
2. `git fetch origin && git checkout -b AN-XXXX-hotfix origin/prod` (use `origin/prod` to avoid ambiguous ref)
3. `git cherry-pick <commit-hash>` (typically the merge commit from main: `git log origin/main --oneline`)
4. `git push -u origin AN-XXXX-hotfix`
5. `gh pr create --base prod --title "AN-XXXX: HOTFIX - ..." --body "..."`

## Dotfiles
- Dotfiles repo: `~/Dev/anatomy/dotfiles/` — configs are symlinked from here to their system paths
- Always edit files in the dotfiles repo, never the system path directly (symlinks mean they're the same file, but think in terms of the repo)
- Ghostty config: `dotfiles/ghostty/config` → `~/.config/ghostty/config`

## Scripts (~/.claude/scripts/)

Credentials in `~/.secrets/credentials` (chmod 600)

- `amplitude-flags`: read/write helper for Amplitude Experiment feature flags and deployments using `AMPLITUDE_MGMT_API_KEY_{DEV,STAGING,PROD}`. Read commands are safe by default; write commands require `--yes`.
  See `memory/amplitude-flags.md` for the operating notes and common workflows.

### LLM / AI APIs
- Microservices use **Vertex AI** for Google and Anthropic model calls, not direct API keys
- GCP project: `eob-ocr-and-extraction-dev`, region: `us-east5`
- Requires `gcloud auth application-default login` (may need periodic refresh)
- Use `AnthropicVertex` from `anthropic` SDK, not `Anthropic`

### Database Access
**READ-ONLY unless explicitly approved. SELECT queries only.**

**⚠️ ALWAYS use the Analytics DB for read queries. Never use docdb/edidb/rdsdb for reads - they require separate auth and we almost never need direct access to prod DBs.**

**Analytics DB** - contains all data from all databases, allows cross-db joins
```bash
# Requires SSH tunnel - run sshpkanalytics first
sshpkanalytics  # Start/restart tunnel (kills existing tunnels)
source ~/.secrets/credentials && psql "$ANALYTICS_DB_PROD_URL" -c "SELECT ..."

# For multi-line queries, use heredoc:
source ~/.secrets/credentials && psql "$ANALYTICS_DB_PROD_URL" <<'EOF'
SELECT * FROM dbt_prod.stg_payer_service__remits LIMIT 5;
EOF
```
One connection gives you access to doc, edi, payer, and user data via `dbt_prod.*` tables.

**Note:** Analytics DB has ~12hr ETL delay. For real-time data, query prod DBs directly (requires separate auth).

**Individual DBs (RARE - only for writes, which almost never happen)**

Doc DB / EDI DB (Cloud SQL) - requires `gcloud auth login`
```bash
docdb connect prod && docdb q "SELECT ..."    # or edidb
docdb close
```

Payer/User DB (RDS) - SSH tunnel via bastion
```bash
rdsdb connect payer && rdsdb q "SELECT ..."
rdsdb close
```

### Datadog Logs
- `~/.claude/scripts/ddlogs "query" [1h|6h|1d|7d] [limit]`

**IMPORTANT**: The ddlogs script's jq parsing can silently fail on complex log structures, returning empty output even when results exist. If ddlogs returns nothing, use raw curl instead:

```bash
/bin/bash -c 'source ~/.secrets/credentials
FROM_TS=$(($(date +%s) - 86400))000
TO_TS=$(date +%s)000
curl -s -X POST "https://api.${DD_SITE}/api/v2/logs/events/search" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"filter\": {
      \"query\": \"env:prod \\\"your search term\\\"\",
      \"from\": \"$FROM_TS\",
      \"to\": \"$TO_TS\"
    },
    \"sort\": \"-timestamp\",
    \"page\": {\"limit\": 50}
  }" | jq -r ".data[]? | .attributes.message"'
```

Common queries:
- `env:prod "Post 835"` - EOB file transfer workflow logs
- `env:prod "SFTP client" error` - SFTP upload errors
- `service:payer-service` - payer service logs

### Temporal

**CLI setup:** Use the `temporal` CLI (not `tcld`) for workflow operations. `tcld` is for cloud management (namespaces, accounts, users).

```bash
# Load credentials — TEMPORAL_API_KEY doesn't load via `source`, use eval:
eval "$(grep '^TEMPORAL_' ~/.secrets/credentials)"

# One-time env setup (persists to ~/.config/temporalio/temporal.yaml):
temporal env set -k address -v "$TEMPORAL_ADDRESS"
temporal env set -k namespace -v "$TEMPORAL_NAMESPACE"
temporal env set -k api-key -v "$TEMPORAL_API_KEY"
```

After env is configured, no auth flags needed:
```bash
temporal workflow describe -w <workflow-id> -r <run-id>
temporal workflow show -w <workflow-id> -r <run-id> -o json  # full event history
temporal workflow list  # list recent workflows
```

**Useful jq patterns for workflow history:**
```bash
# Event timeline
temporal workflow show -w <id> -o json | jq '[.events[] | {id: .eventId, type: .eventType}]'
# Failure details
temporal workflow show -w <id> -o json | jq '.events[] | select(.eventType == "EVENT_TYPE_WORKFLOW_TASK_FAILED") | .workflowTaskFailedEventAttributes'
# Activity types scheduled
temporal workflow show -w <id> -o json | jq '.events[] | select(.eventType == "EVENT_TYPE_ACTIVITY_TASK_SCHEDULED") | .activityTaskScheduledEventAttributes.activityType.name'
```

**Cloud management** (namespace config, auth method, etc.):
```bash
tcld namespace get -n anatomy-prod.c6dg9
```
`tcld` authenticates via browser login (auto-opens on first use).

Key task queues:
- `payer-eob-transfer` - EOB file transfer workflows
- `doc-pipeline` - document processing workflows
- Schedule: `ConvertAndTransferEOBsEvery2Hours` - runs Post 835 workflow

Note: Activity results are encrypted in prod, so you can't see return values directly. Check Datadog logs instead.

### Notion MCP
- Two Notion MCP servers available: `mcp__notion__*` and `mcp__claude_ai_Notion__*` - if one has token issues, try the other
- Notion `<unknown>` blocks (external_object_instance) = embedded Google Drive files, cannot be created via API - use markdown links instead
- Always fetch `notion://docs/enhanced-markdown-spec` MCP resource before creating/updating page content
