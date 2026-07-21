# Global instructions

Cross-project behavior. Anatomy-specific rules live in the workspace CLAUDE.md.

## Debugging
- Gather evidence before stating root cause. Separate evidence-gathering from conclusion-drawing. Don't jump to conclusions from incomplete data — verify timeline claims against logs and data before stating them. If the user pushes back, re-examine from scratch rather than defending the initial analysis.

## Code style
- No docstrings — method names are self-documenting
- Type hints required (repos converting to ty), deliberate and concise — an awkwardly wrapping signature still signals verbose types or too many args; fix the signature, don't reflow. Pydantic only at process boundaries
- Short, disambiguating names — distinct from siblings, not full-behavior descriptions
- NO code comments — ever. Before pushing, remove every comment; if the code stops making sense without one, rewrite the code, not add the comment back. No exceptions — not even external constraints, vendor quirks, or regulatory rules. Put that context in the commit message or PR description instead, never in the code (incl. YAML/config).
- Single-responsibility methods; classes model domain things with natural methods, not bags of static functions
- Don't add abstractions ahead of need; don't replace working low-code with homegrown unless there's concrete pain
- Use `uv` or `dev/exec` for test/python commands — never `pip`

## General rules
- Use CLI tools (gh, jira, temporal, ddlogs) over WebFetch for authenticated services — WebFetch can't authenticate
- When auth fails (gcloud, etc.), spawn the login interactively via `Bash(run_in_background=true)` instead of asking the user to retype the command

## Notion MCP
- Two servers: `mcp__notion__*` and `mcp__claude_ai_Notion__*` — if one has token issues, try the other
- `<unknown>` blocks (external_object_instance) = embedded Google Drive files; can't create via API — use markdown links instead
- Fetch `notion://docs/enhanced-markdown-spec` MCP resource before creating/updating page content

## Dotfiles
- Repo: `~/Dev/anatomy/dotfiles/` — configs are symlinked from here to their system paths
- Always edit in the repo, never the system path directly (think in terms of the repo even though the symlink makes them the same file)
- Ghostty config: `dotfiles/ghostty/config` → `~/.config/ghostty/config`
