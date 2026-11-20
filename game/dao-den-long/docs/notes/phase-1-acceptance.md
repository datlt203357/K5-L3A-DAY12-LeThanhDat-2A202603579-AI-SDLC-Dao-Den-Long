# Phase 1 — PRD-0 acceptance

## Implemented in the current project

- Godot project starts at `main.tscn`; gameplay uses a fixed 60 Hz simulation.
- Night 1 has five lanterns, 20 starting motes, three flames, pickup/deposit, shade spawning, pulse, hit/drop, HUD, pause/result flow, and replay.
- `game.contract.json` exposes the final v1.3 tuning plus headless, benchmark, and soak commands.
- The headless runner emits tick-zero snapshots, events, periodic snapshots, and a final `end` JSONL row.

## Evidence

- The original CP0 run was reported by the student as successful (`HEADLESS_OK`); see `docs/proof/phase-1/cp0.md`.
- Current simulation regression and final-contract headless smoke output are in `docs/proof/phase-4/`.

## Still required for a Phase 1 submission claim

- Run a full playable Night 1 in the GUI and save a real screenshot/video or timestamped log.
- Re-run the Phase 1 headless scenarios against the final code and retain output.
- Tag `phase-1` at the actual Phase 1 commit. The repository does not currently contain phase-specific commits/tags, so the final implementation must not be presented as historical Phase 1 evidence.
