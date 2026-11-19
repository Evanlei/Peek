# Peek — Agent Characters Spec (draft, exploratory)

Status: exploratory. User wants to see iterations before committing to a direction.

## Decided
- **Characters, not dots.** Each agent is a small, original orange pixel creature drawn in code
  (in the spirit of Claude Code's mascot, not a copy of it).
- **Hierarchy.** Each Claude Code session is a main character. Its Task subagents appear as
  smaller "sidekick" characters next to it while they run, then disappear when they finish.
- **Placement: both, scaled.**
  - Collapsed (32pt notch strip): tiny characters replace the status dots in the left wing.
    The live total cost stays on the right.
  - Expanded (hover): each session gets a card with a larger character, its sidekicks, and details.
- **Context window: character + bar.**
  - The card shows a precise bar, e.g. `142k / 200k`.
  - The character reacts at thresholds: tired above 80%, frazzled above 95%.
- **States carried by the character:**
  - working: bobs and "types"
  - needs me: bounces and waves, with an amber `!`
  - stuck: slumps, red, small storm cloud or `x x` eyes
  - done/idle: sits still, eyes closed

## Card contents (expanded)
Character, project name, current action, context bar, tokens, cost, runtime, and the sidekick row.

## Decided after iterations (2026-11-18)
- **Diorama is the direction.** The user found it cleaner than Stage + list or Lanes.
- **Name labels:** use the project name (from the session's working directory). When several
  sessions share a project, add the git branch (`peek · fix-hover`). If the branches are also the
  same or unknown, use a snippet of the session's first prompt, then `#n`.

## Approvals and usage (2026-11-18)
- **Approval card** replaces the Diorama footer whenever a permission request is pending. It shows
  the oldest request first (`1 of N`), with a tool icon, the agent's name, the tool, the
  command or path, and **Deny** / **Allow** buttons. The buttons only change fake data today;
  step 3 connects them to Claude Code hooks.
- **Footer priority:** a pending approval comes first, then a stuck agent, then "All clear".
- **Usage ring** in the expanded header shows the share of the 5-hour window used (`5h 41%`).
  The plan limits aren't in the JSONL logs, so with real data this is an estimate. An alternative
  is to show a raw token count. The collapsed notch shows only the cost.

## Performance budget
The app is always on, so idle CPU matters. Measured on a Release build:
- Collapsed: about 4.5% while an agent hops for attention (12fps). Expected lower otherwise (4fps), not yet measured.
- Expanded Diorama: about 11% at 30fps, mostly SpriteKit's GPU render thread.
How:
- The live scene renders with SpriteKit: one pooled sprite node per drawn image, updated in
  `PeekSKScene.update`. Ticks never invalidate the SwiftUI window.
- Every sprite, label and prop is rasterized once into `SpriteCache`, so each frame only places images.
- The same `render(into: Blitter)` code drives a SwiftUI Canvas for offscreen previews and GIFs.
- No rolling-number effect on the cost label. The shadow sits on a static shape.
- Debug builds: `PEEK_SNAPSHOT=/path.png` captures Peek's own window (no Screen Recording
  permission needed), and `PEEK_EXPANDED=1|0` pins the panel open or closed.

## Approval card, v2 (decluttered)
- One sentence and the command: "**landing-site** wants to fetch" / `registry.npmjs.org/left-pad`.
- No icon tile, amber border or tool tag; the character's "!" already says it's waiting.
- Deny is quiet text and Allow is the only filled control. Corners nest: card 14 = button 7 + inset 7.

## Real sessions (step 2, 2026-11-19)
`SessionScanner` reads `~/.claude/projects/*/*.jsonl` every 2s on a background queue.
It only looks at files modified in the last 30 minutes and parses each file incrementally
by byte offset. Real data is the default; `PEEK_FAKE=1` brings back the demo data.
| Field | Source |
|---|---|
| Name | `cwd`, seeing through worktrees (`cues/.claude/worktrees/x` → `cues`) |
| Branch | `gitBranch`, ignoring `HEAD`, shortened (`claude/fix-x-9e4260` → `fix-x`) |
| Fallback label | `ai-title` |
| Context | last assistant `usage` (input + cache write + cache read + output) ÷ model window (1M; 200K for Haiku 4.5 and older) |
| Cost | latest `cost-state.totalCostUSD`, plus a per-message estimate since then (deduplicated by message id, subagent files included) |
| Action | oldest pending `tool_use` (`Bash: <description>`, `Edit: file.swift`, …) |
| Sidekicks | `<session>/subagents/agent-*.jsonl` modified in the last 45s |
Status rules:
- **working:** a tool call is pending, or the turn is still in progress.
- **idle:** the last turn ended (`end_turn`), the user interrupted, or nothing happened for 10 minutes.
- **stuck:** a tool has been pending for more than 5 minutes, or 3+ tool errors in a row.
- **needs you:** can't be detected from logs, because pending permission prompts are never
  written. Step 3's hooks will supply it.
Checked against real data:
- The cost estimate alone ran 3–25% under Claude Code's own totals (it misses side calls),
  which is why the newest `cost-state` total is used as the anchor.
- A real subagent showed up as a sidekick, and its cost was added to the session.
- The 5-hour ring is hidden in live mode because plan limits aren't in the logs.
- CPU on live data (Release build): about 2.6% collapsed and 8% expanded.

## Approvals via hooks (step 3, 2026-11-19)
- **Hook:** `PermissionRequest`, matcher `*`, a command hook running `~/.peek/permission-hook.sh`
  (timeout 600s). It is installed in `~/.claude/settings.json` alongside the existing
  Superset/Paradev notify hook. Backup: `settings.json.bak-peek`.
- **Script:** curl POSTs the hook JSON to `127.0.0.1:47823/permission` with the token from
  `~/.peek/token` (permissions 0600). If Peek isn't running it prints nothing and exits 0,
  so the normal terminal prompt appears.
- **Peek:** a loopback-only `HookServer` (Network framework). A wrong token gets a 403. Each
  request is held until Allow or Deny, then answered with
  `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"|"deny"}}}`.
  - Deny includes the message "Denied from Peek."
  - No decision after 570s → empty reply, which falls back to the terminal prompt.
  - If the hook is cancelled first (the user answered in the terminal), the card is cleared.
- The request is shown on its session's character (`session_id` → the same stable ID the
  scanner uses). It waves, and the approval card appears.
- **Verified:**
  - Protocol round-trip and the token check.
  - Cancelled hook → card cleared.
  - Peek down → silent fallback.
  - A real `claude -p` run (Haiku, throwaway settings): Allow → the command ran;
    Deny → it was blocked and Claude reported "denied".
- **Not verified:** in an interactive terminal session, whether Claude Code shows its own
  prompt while the hook is waiting (the docs don't say).
- The scene was trimmed from 124 to 88pt, so the expanded notch is about 36pt shorter.

## Auto-peek (2026-11-19)
- When any permission request is pending, the notch opens on its own into an **alert** state:
  the collapsed strip plus the approval card (460pt wide, about 90pt tall, 24pt corners
  concentric with the card's 14pt). It closes when nothing is pending.
- It opens with a spring (0.38s, bounce 0.2) and closes with one (0.28s, no bounce).
  The card enters with the blur-rise transition, which becomes a plain fade with Reduce Motion on.
- While alerting, hover-expand is disabled so the Allow button never moves under the cursor.
  If the panel is already expanded, the card stays in the Diorama footer.
- Verified by self-snapshot: the alert appears with no hover, and the panel collapses after a decision.

## Open questions
- Whether sidekicks show in the collapsed strip or only when expanded.
- Behaviour with more than 5 sessions in the collapsed strip (overflow `+3`?).
- Whether the character in the collapsed strip shows context fullness, or only the expanded card does.

## Later steps (unchanged)
1. Real data from `~/.claude/projects/**/*.jsonl` (sessions, subagent sidechains, usage → context %).
2. Claude Code hooks → approve or deny permission requests from the notch.

## Iterations built (2026-11-18)
Switch between them by right-clicking the open notch → Style. `PEEK_STYLE=stage|diorama|lanes` also works.
Animated previews are in `.plans/previews/`.

- **Stage + list:** one shared floor with names under the characters, plus a dense list below
  (action, context %, cost). It shows the most information.
- **Diorama** (default): the whole panel is a room. Each agent has a desk whose monitor glows
  in its state color. Working characters type at their desk, then wander. A footer says the
  most urgent thing in words. It's the most "scene"-like.
- **Lanes:** one card per session, each with its own small room. It has the clearest per-agent
  detail (context `142k / 200k`, cost, runtime).

Motion decisions (animate skill):
- The collapsed strip stays nearly still because it sits in peripheral vision all day.
  "Needs me" hops and gets an amber halo.
- Wandering only happens in the expanded scene, which you choose to open.
- The panel opens with a spring (0.38s, bounce 0.2) and closes with one (0.28s, no bounce).
- With Reduce Motion on, nobody walks or hops; states are shown by expression and color only.
