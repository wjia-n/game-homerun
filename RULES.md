# Home Run Derby — RULES.md

The authoritative source of truth for gameplay. If the implementation
diverges from this document, fix the implementation.

## 1. Objective

Out-slug the opposition. Each batter faces exactly 10 pitches; the highest
total score wins the derby.

## 2. Setup

- Choose a mode: **Solo Derby** (1 human, beat your best), **Bot Battle**
  (human vs the bot — its display name is renameable in the menu),
  or **2-Player** (pass-and-play, 2 humans).
- Choose a pitch difficulty: Rookie (slow, gentle break), Pro (standard),
  All-Star (fast, wicked break — Pro unlock required).
- In Bot Battle, choose the bot's skill: Rookie / Pro / All-Star (All-Star
  requires Pro).
- Each human/bot slot has a renameable display name (persisted; the bot in
  Bot Battle uses the renameable second name slot).

## 3. Turn order

1. Batters take turns in seat order; each batter completes all 10 pitches
   before the next batter steps in.
2. In 2-Player mode the phone is passed between batters ("Pass the phone").
3. The first pitch of a batter's turn waits for a PLAY BALL tap (humans) or
   a short beat (bot). Later pitches auto-throw after the previous result.

## 4. Legal moves

- Tap (or swipe up) anywhere on the stadium, or the SWING! button, while the
  ball is in flight. Exactly one swing per pitch — a second tap is ignored.

## 5. Illegal moves

- Swinging before release or after resolution has no effect.
- There is no way to re-swing, pause-scam, or skip a pitch.

## 6. Pitches

| Pitch     | Flight time (Pro) | Break        |
|-----------|-------------------|--------------|
| Fastball  | 0.72s             | none         |
| Curveball | 0.95s             | big lateral  |
| Changeup  | 1.05s             | small        |
| Sinker    | 0.78s             | late drop    |

Rookie multiplies flight time ×1.25 and break ×0.6. All-Star multiplies
flight time ×0.82 and break ×1.35.

## 7. Special rules

- A pitch unswung at t ≥ 1.12 (plate = t 1.0) is a **called strike**.
- The ball is live from release (t 0) until resolution.

## 8. Scoring

Timing is measured against the ball crossing the plate (t = 1.0):

| Timing | Result | Points |
|--------|--------|--------|
| |dt| ≤ 0.05 | PERFECT — home run, 395–460 ft | 500 × streak + distance |
| |dt| ≤ 0.12 | Great contact: 45% home run (320–380 ft), else off the wall | 500 × streak + dist, or 150 |
| |dt| ≤ 0.22 | Foul tip | 40 |
| worse | Swinging strike | 0 |
| no swing | Called strike | 0 |

- **Streak:** consecutive home runs multiply the 500 base:
  1st HR ×1, 2nd ×1.5, 3rd ×2, … Any non-homer resets the streak to 0.
- Distance is flavor (longest HR tracked per batter).

## 9. Winning conditions

Highest score after all batters complete 10 pitches wins. Solo Derby:
beat your personal best (persisted).

## 10. Draw conditions

Equal scores: the tied batters share the crown (both shown as winners).

## 11. AI strategy

The bot swings once per pitch at t = 1.0 + error, where error is
gaussian with σ = 0.16 (Rookie), 0.08 (Pro), 0.045 (All-Star), clamped to
[0.55, 1.25]. No pitch reading, no perfect information — human-like timing.
The bot uses the renameable second name slot (menu: "Bot name").

## 12. Edge cases

- App backgrounded mid-pitch: the engine clock shifts on resume; the pitch
  continues from where it froze. Music pauses and resumes.
- Phase timer death: a 2s watchdog re-arms the current phase; idle is only
  ever a legitimate wait for human input.
- Pause menu: freezes the engine; resume re-arms via the watchdog.
- Quit mid-derby: scores are discarded; career stats only record completed
  games.

## 13. Test cases

1. Perfect swing (|dt| ≤ 0.05) → homer, streak increments, score ≥ 895.
2. Three straight homers → multipliers ×1, ×1.5, ×2 applied.
3. Foul tip → streak resets to 0.
4. No swing past t 1.12 → called strike, 0 points, pitch consumed.
5. Double swing on one pitch → exactly one resolution.
6. 10 pitches → batter changes (or game over); PLAY BALL gates the next
   human turn.
7. Bot completes 10 pitches without input and never stalls (watchdog).
8. Pause/resume mid-flight → ball continues, no jump, no stuck state.
9. Difficulty All-Star without Pro → stays Pro tier.
10. Names persist across restarts in order (single JSON string storage).
