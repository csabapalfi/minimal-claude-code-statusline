# Claude Activity Streak Tracker

Tracks continuous Claude Code activity across all parallel sessions. Shows current streak in the statusline, red when ≥45m. Logs each break to a queryable file.

## Files

| File | Role |
|---|---|
| `~/.claude/hooks/streak.js` | Fires on `UserPromptSubmit`, `PostToolUse`, `Stop`. Updates state, logs breaks. |
| `~/.claude/streak.json` | Current state: `{start, last}` (ms epoch). |
| `~/.claude/breaks.jsonl` | Append-only log of breaks: `{start, end, durationMs}` per line. |
| `~/.claude/statusline.sh` | Reads streak.json, renders streak at end of statusline. |
| `~/.claude/active-streak.js` | Pre-warm / rebuild streak.json from JSONL. Also works as a standalone streak reader. |

## How it works

1. Every Claude event fires `streak.js` via hook.
2. Hook reads `streak.json`. If `now - last > 5min`, it logs a break to `breaks.jsonl` and resets `start = now`. Otherwise extends streak.
3. Always updates `last = now`, atomic-writes state.
4. Statusline reads `streak.json` inline via `jq`. If `now - last ≤ 5min`, prints `now - start` duration. Gray under 45m, bold red from 45m up.

All sessions write to the same state file — parallel sessions naturally merge into one wall-clock streak.

## Thresholds (in `hooks/streak.js`)

- `IDLE_MS = 5 * 60 * 1000` — gap that ends a streak / counts as a break.
- Red threshold in `statusline.sh` (`MINS -ge 45`).

## Queries

```bash
# How many breaks today?
jq -c --arg t "$(date -v4H -v0M -v0S -u +%s)000" \
  'select(.start > ($t|tonumber))' ~/.claude/breaks.jsonl | wc -l

# Total break minutes today
jq -s --arg t "$(date -v4H -v0M -v0S -u +%s)000" \
  'map(select(.start > ($t|tonumber)).durationMs) | add / 60000' \
  ~/.claude/breaks.jsonl

# List today's breaks with durations
jq -r --arg t "$(date -v4H -v0M -v0S -u +%s)000" \
  'select(.start > ($t|tonumber)) |
   "\(.start/1000|strftime("%H:%M")) → \(.end/1000|strftime("%H:%M")) (\(.durationMs/60000|floor)m)"' \
  ~/.claude/breaks.jsonl
```

## Rebuild / reset state

If streak.json gets wiped or drifts:

```bash
# Rebuild from today's JSONL (4am day boundary)
node -e '...'  # see active-streak.js for the prewarm logic
```

## Known limitations

- **Only tracks Claude turns.** Reading output, manual terminal work, thinking — all invisible. A 10min read = "break" by this metric.
- **Long single tool calls (>5min) falsely reset the streak.** No hook fires during the call, so the gap between PostToolUse events can exceed `IDLE_MS`. Rare in practice.
- **Statusline refreshes per turn, not on a timer.** Streak display freezes between your turns. Fine for nudging; not a live clock.
- **Day boundary for queries is 4am local.** Adjust the `date -v4H` in the query examples if you want different.

## Design notes

Early versions scanned JSONL files directly on every render — bounded by tail size, broke once sessions exceeded ~2h of events. Moved to hook-updated state file: O(1) reads, no scanning, merges all sessions automatically. Hooks run ~20ms, statusline streak reads ~8ms.

The hook-based approach means the state file IS the index over the JSONL write-ahead log. Cheap to read, authoritative, extensible (currently just `{start, last}`, easy to add session counts, project tags, etc.).
