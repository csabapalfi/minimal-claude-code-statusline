# claude-code-statusline

A pace-aware statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows model, context window usage, and API quota utilization — all in a few characters.

```
opus ▃ ▄▃
│    │ ││
│    │ │└─ 7-day quota (height = usage %, color = pace)
│    │ └── 5-hour quota (height = usage %, color = pace)
│    └──── context window (height + color = usage %)
│
└───────── model name
```

## What it looks like

| Statusline | Meaning |
|---|---|
| `opus ▃ ▁▁` | Context 30% used. Both quotas low and on pace. |
| `opus ▃ ▄▃` | Context 30%. Quotas ~40% used but on pace (gray = fine). |
| `opus ▆ ▅▃` | Context 70%. 5h at 50% and burning fast (yellow = ahead of pace). |
| `opus ▇ ▇▆` | Context 80%+. Both quotas high and way ahead of pace (red = slow down). |

## Colors

**Context window** — absolute thresholds (it's a finite window, not a rate):
- Gray: < 50%
- Yellow: 50-79%
- Red: 80%+

**5-hour and 7-day quotas** — pace-aware (are you burning faster than the window refills?):
- Gray: on pace or within 10% (you'll fit)
- Yellow: 11-30% ahead of pace (watch it)
- Red: >30% ahead of pace (slow down or you'll hit the limit)

Bar height always shows absolute utilization so you can see how full the bucket is regardless of pace.

## How pace works

Instead of coloring by raw utilization (which would always look alarming late in a window), the script computes:

```
elapsed_pct = time elapsed in current window / window duration
pace_delta  = utilization - elapsed_pct
```

60% used with 80% of the window elapsed? Delta is -20 — gray, you're fine.
60% used with 20% elapsed? Delta is +40 — red, you're burning too fast.

## Requirements

- macOS (uses `security` for keychain access, `date -jf` for timestamp parsing, `stat -f%m` for file age)
- `jq` and `curl`
- Claude Code with OAuth login (the script reads the token from macOS Keychain)

## Install

1. Copy the script somewhere:

```bash
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

2. Configure Claude Code (`~/.claude/settings.json`):

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

3. Restart Claude Code. The statusline appears at the bottom of the terminal.

## How it works

1. Claude Code pipes JSON to the script on each render (contains `model.id` and `context_window.used_percentage`).
2. The script fetches quota data from `api.anthropic.com/api/oauth/usage`, cached for 5 minutes at `~/.cache/claude-usage.json`.
3. The OAuth token is read from macOS Keychain (`Claude Code-credentials`).

## Cache staleness

Quota data is cached for 5 minutes to avoid hammering the API. This means a burst of parallel agents can burn through quota before the statusline updates. The absolute bar height helps here — if you see tall bars, tread carefully even if they're gray.

## License

MIT
