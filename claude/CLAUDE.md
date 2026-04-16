## Debugging & Investigation
- **Gather evidence before stating root cause.** Separate evidence-gathering from conclusion-drawing. Don't jump to conclusions from incomplete data — verify timeline claims against logs and data before stating them. If the user pushes back, re-examine from scratch rather than defending the initial analysis.

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

## Code Discipline (from Bugbot analysis)
- **One config source per service.** Pick `load_config()` OR env vars OR `BaseSettings` — never mix. If startup validation reads config one way, runtime must use the same path. Grep for `os.environ.get` in any module that also calls `load_config()` — that's a bug.
- **Every class/function you create must be imported and called somewhere.** Before finishing a PR, grep for each new symbol name. If nothing imports it, delete it or wire it in. Dead code misleads reviewers and drifts.
- **Generate code, then integrate it.** After writing new code, verify the pieces actually connect: constructors receive the types callees expect, route handlers call the command classes (not parallel reimplementations), fallback paths get the same wiring as happy paths. Read the call sites — don't assume the interface matches.
- **Don't duplicate logic across layers.** Routes delegate to commands. If a command class exists, the route calls it — no parallel reimplementation. If logic exists in two places, delete one.
- **Async handlers must not call sync blocking code.** In FastAPI async routes, never call synchronous I/O (HTTP clients, Slack SDK, DB queries) directly. Use `await asyncio.to_thread(fn)` or async clients. If you define an async helper, actually use it — don't define `_async_post` then pass `_post_sync` everywhere.
- **Never create `asyncio.Lock()` or clients at module level.** Module-level async primitives bind to whatever event loop first touches them. Create them in an `async def` startup hook or use lazy initialization inside an async function.
- **Cache negative lookups too.** When caching a global (client, config, bot user ID), cache the "not available" result. Otherwise every call re-attempts the lookup and logs a warning. Use a `_checked` sentinel flag.

## Dotfiles
- Dotfiles repo: `~/Dev/anatomy/dotfiles/` — configs are symlinked from here to their system paths
- Always edit files in the dotfiles repo, never the system path directly (symlinks mean they're the same file, but think in terms of the repo)
- Ghostty config: `dotfiles/ghostty/config` → `~/.config/ghostty/config`

## Notion MCP
- Two Notion MCP servers available: `mcp__notion__*` and `mcp__claude_ai_Notion__*` - if one has token issues, try the other
- Notion `<unknown>` blocks (external_object_instance) = embedded Google Drive files, cannot be created via API - use markdown links instead
- Always fetch `notion://docs/enhanced-markdown-spec` MCP resource before creating/updating page content
