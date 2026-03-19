# minimal-claude-code-statusline

A minimal, pace-aware status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Shows model, context window, and API quota usage in a few characters.

Designed to stay out of your way — everything is gray and quiet when things are fine. You'll only notice it when a bar turns yellow or red, which is exactly when you need to.

```
opus ▃ ▄▃
│    │ ││
│    │ │└─ 7-day quota (height = usage %, color = pace)
│    │ └── 5-hour quota (height = usage %, color = pace)
│    └──── context window (height + color = usage %)
│
└───────── model name
```

## Examples

<img src="examples.png" width="580">

## Colors

**Context window** — absolute thresholds (finite window, not a rate):

| Usage | Color | Meaning |
|-------|-------|---------|
| < 50% | gray | Plenty of room |
| 50-79% | yellow | Getting full |
| 80%+ | red | Almost out |

**5-hour and 7-day quotas** — pace-aware coloring on absolute height:

```
pace_delta = utilization% - elapsed% of current window
```

| Condition | Color | Meaning |
|-----------|-------|---------|
| stale (past reset) | red █ | Window reset, data is stale — assume the worst |
| ≥ 90% used | red | Too close to limit regardless of pace |
| > 30% ahead | red | Way ahead, slow down |
| 11-30% ahead | yellow | Ahead of pace, watch it |
| ≤ 10% ahead | gray | On pace, you'll fit |

Bar height always shows absolute utilization. A tall gray bar means "almost full but resetting soon". A tall red bar means "almost full AND burning too fast". At 90%+ usage, the bar always goes red — even if you're on pace, you're too close to the limit for comfort.

When the API can't be reached (e.g. rate limited during heavy use), the cache goes stale. If the quota window has reset since the last successful fetch, the bar shows full red — the data is from a previous window and can't be trusted.

## Requirements

- macOS (uses Keychain, `date -jf`, `stat -f%m`)
- `jq` and `curl`
- Claude Code with OAuth login

## Install

```bash
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

Restart Claude Code.

## How it works

1. Claude Code pipes JSON to the script on each render (contains `model.id` and `context_window.used_percentage`).
2. The script fetches quota data from `api.anthropic.com/api/oauth/usage`, cached for 2 minutes at `~/.cache/claude-usage.json`.
3. The OAuth token is read from macOS Keychain (`Claude Code-credentials`).
4. API calls have a 3-second timeout so a slow or unresponsive API can't hang your statusline.
5. On fetch failure (429, timeout, etc.), the cache mtime is touched to prevent retrying on every render.

The 2-minute cache means a burst of parallel agents can burn through quota before the statusline updates. The absolute bar height helps — if you see tall bars, tread carefully even if they're gray.

## License

MIT
